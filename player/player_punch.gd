class_name PlayerPunch
extends Node

# Punch combo (Y), on the ground and in the air, and its hitbox (the
# player's PunchHitbox). A hit is reported through player.punch_landed.

# A press this early still counts, so the cross can be pressed on the
# beat during the jab instead of waiting for a window to open. Mashing
# plays jab, cross, jab, cross at the animations' own pace.
@export var attack_buffer_time: float = 0.2

# Frame numbers from the punch sheets (re-check them if the art changes).
# Active: the fist is out and the hitbox is live. Chain: the jab is far
# enough through that the cross can follow. Recovery: the punch has
# landed, and moving or jumping cancels the rest of the pose.
const JAB_ACTIVE_FRAMES: Array[int] = [1, 2]
const JAB_CHAIN_FRAME := 3
const JAB_RECOVERY_FRAME := 6
const CROSS_ACTIVE_FRAMES: Array[int] = [1, 2]
const CROSS_RECOVERY_FRAME := 5

enum Attack { NONE, JAB, CROSS }
var attack: Attack = Attack.NONE
var attack_buffer_timer: float = 0.0

@onready var player := get_parent() as Player
@onready var jab_shape: CollisionShape2D = player.get_node("PunchHitbox/Jab")
@onready var cross_shape: CollisionShape2D = player.get_node("PunchHitbox/Cross")
# The hitbox shapes are laid out for facing right and mirrored from these.
@onready var jab_shape_x: float = jab_shape.position.x
@onready var cross_shape_x: float = cross_shape.position.x


func _ready() -> void:
	(player.get_node("PunchHitbox") as Area2D).body_entered.connect(_on_punch_hitbox_body_entered)


func is_punching() -> bool:
	return attack != Attack.NONE


func update(direction: float, delta: float) -> void:
	# Not while climbing or attached: the hands are busy, and a buffered
	# press would fire a punch the moment the player let go.
	var climb := player.climb
	if Input.is_action_just_pressed("attack") and not climb.is_climbing and not climb.is_attached:
		attack_buffer_timer = attack_buffer_time
	else:
		attack_buffer_timer -= delta
	_update_attack(direction)


func _update_attack(direction: float) -> void:
	var dash := player.dash
	var crouch := player.crouch
	var climb := player.climb
	if attack == Attack.NONE:
		if (attack_buffer_timer > 0.0 and not climb.is_climbing and not climb.is_attached
				and not player.is_wall_running and dash.dash_timer <= 0.0
				and dash.windup_timer <= 0.0 and not dash.is_diving and dash.dive_land_timer <= 0.0
				and not crouch.is_crouching and crouch.roll_timer <= 0.0 and not crouch.is_sliding
				and not player.slope.is_slope_sliding):
			# In the air every press is a cross. There's no combo to build up
			# mid-jump, so it goes straight to the big swing.
			_start_attack(Attack.JAB if player.is_on_floor() else Attack.CROSS, direction)
		return
	# Anything that takes the body somewhere else ends the punch. Leaving
	# the ground or landing doesn't: an air punch carries on into a
	# grounded one (and plants the feet), and a punch thrown at a ledge's
	# edge keeps swinging as the player drops off it.
	if climb.is_climbing or climb.is_attached or player.is_wall_running or dash.dash_timer > 0.0:
		end_attack()
		return

	var sprite := player.sprite
	var frame := sprite.frame
	if attack == Attack.JAB and attack_buffer_timer > 0.0 and frame >= JAB_CHAIN_FRAME:
		_start_attack(Attack.CROSS, direction)
		return
	# Up to the recovery frame the punch is committed. After it, moving or
	# jumping hands straight back to movement, so the guard pose at the
	# end of each sheet never holds the player in place.
	var recovery := JAB_RECOVERY_FRAME if attack == Attack.JAB else CROSS_RECOVERY_FRAME
	if not sprite.is_playing() or (frame >= recovery and (direction != 0.0 or player.jump_buffer_timer > 0.0)):
		end_attack()
		return

	var active := JAB_ACTIVE_FRAMES if attack == Attack.JAB else CROSS_ACTIVE_FRAMES
	_set_punch_hitbox(attack if frame in active else Attack.NONE)


func _start_attack(kind: Attack, direction: float) -> void:
	attack = kind
	attack_buffer_timer = 0.0
	# Holding a direction turns before each punch, so the cross can be
	# thrown the other way at something behind.
	if direction != 0.0:
		player.facing = signf(direction)
	var sprite := player.sprite
	sprite.speed_scale = 1.0
	sprite.flip_h = player.facing < 0.0
	# Played directly rather than through anim.play(), which won't restart
	# an animation that's already showing (a jab straight after a jab).
	sprite.play(&"jab" if kind == Attack.JAB else &"cross")
	_set_punch_hitbox(Attack.NONE)


func end_attack() -> void:
	attack = Attack.NONE
	_set_punch_hitbox(Attack.NONE)


# In the air the punch doesn't stop the body: the jump arc carries on
# and the player can still steer, so a punch never hangs them in place
# the way a mid-air stop would. Facing is locked to the swing (it only
# turns between punches), and wall slides and wall jumps wait for the
# punch to end, so the swing reads as one committed action.
func apply_air_attack_movement(direction: float, delta: float) -> void:
	# A punch straight out of a wall jump still honours the push-off, or
	# held toward the wall would steer the player straight back onto it.
	if player.wall_jump_lock_timer > 0.0:
		player.wall_jump_lock_timer -= delta
	else:
		player.velocity.x = move_toward(player.velocity.x, direction * player.run_speed(),
				player.air_acceleration * delta)
	var gravity := player.gravity
	var fall := gravity if player.velocity.y < 0.0 else gravity * player.fall_gravity_multiplier
	player.velocity.y = minf(player.velocity.y + fall * delta, player.max_fall_speed)
	# A jump released early is still cut short, even if a punch started
	# partway up it.
	if Input.is_action_just_released("jump") and player.velocity.y < 0.0 and not player.is_launched:
		player.velocity.y *= player.jump_cut_multiplier


func _set_punch_hitbox(kind: Attack) -> void:
	jab_shape.disabled = kind != Attack.JAB
	cross_shape.disabled = kind != Attack.CROSS
	jab_shape.position.x = jab_shape_x * player.facing
	cross_shape.position.x = cross_shape_x * player.facing


func _on_punch_hitbox_body_entered(body: Node2D) -> void:
	player.punch_landed.emit(body, 1 if attack == Attack.JAB else 2)
