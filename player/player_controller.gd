extends CharacterBody2D

# Attach this to a CharacterBody2D with a CollisionShape2D child.
# Every value below shows up in the Inspector when this script is
# attached, so you can tune the feel by dragging numbers, no code
# changes needed.
#
# Units are pixels at the game's 480x270 base resolution. The character
# is ~30px tall and tiles are 16px, so a jump of ~72px clears about
# four and a half tiles.

# Horizontal movement
@export var max_speed: float = 120.0
@export var acceleration: float = 1000.0
@export var friction: float = 900.0
@export var air_acceleration: float = 650.0

# Vertical movement
@export var jump_velocity: float = -360.0
@export var gravity: float = 900.0
@export var fall_gravity_multiplier: float = 1.6
@export var max_fall_speed: float = 420.0
@export var jump_cut_multiplier: float = 0.45

# Forgiveness windows (in seconds)
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

# Below this horizontal speed the run animation hands back to idle, so
# the last few pixels of deceleration don't play a stuttery run cycle.
@export var run_anim_threshold: float = 10.0

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var spawn_position: Vector2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	spawn_position = global_position


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")

	# Horizontal movement. Air acceleration is separate from ground
	# acceleration so you can give the player less control mid-air
	# if you want that heavier, committed-to-the-jump feeling.
	var target_speed := direction * max_speed
	var accel := acceleration if is_on_floor() else air_acceleration
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# Asymmetric gravity: falling pulls harder than rising. This is
	# most of what separates "weighty" from "floaty" - it stops the
	# character hanging at the top of a jump arc.
	if velocity.y < 0.0:
		velocity.y += gravity * delta
	else:
		velocity.y += gravity * fall_gravity_multiplier * delta
	velocity.y = min(velocity.y, max_fall_speed)

	# Coyote time: a short grace window after walking off a ledge
	# where a jump still counts, so near-misses feel fair.
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	# Jump buffering: a press slightly before landing still counts,
	# instead of getting silently dropped.
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	# Variable jump height: releasing the button early cuts the
	# jump short, so tapping gives a hop and holding gives full height.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	# Floor state has to be read before move_and_slide() updates it,
	# otherwise there's no way to tell that we only just touched down.
	var was_on_floor := is_on_floor()
	move_and_slide()
	_update_animation(direction, was_on_floor)


func _update_animation(direction: float, was_on_floor: bool) -> void:
	# Only turn on input, not velocity, so skidding to a stop after
	# reversing doesn't flicker the facing back and forth.
	if direction != 0.0:
		sprite.flip_h = direction < 0.0

	if not is_on_floor():
		_play("jump" if velocity.y < 0.0 else "fall")
		return

	var moving := absf(velocity.x) > run_anim_threshold

	# Landing recovery only plays when standing still. Any input cancels
	# it, because locking the player into an animation on touchdown
	# makes movement feel sluggish.
	if not was_on_floor and not moving:
		_play("land")
		return
	if sprite.animation == "land" and sprite.is_playing() and not moving:
		return

	_play("run" if moving else "idle")


# play() restarts a non-looping animation if called again with the same
# name, which would freeze jump/fall on their first frame. Guard it.
func _play(anim: StringName) -> void:
	if sprite.animation != anim:
		sprite.play(anim)


func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
