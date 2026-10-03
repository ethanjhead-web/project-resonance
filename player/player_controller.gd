extends CharacterBody2D

# Attach this to a CharacterBody2D with a CollisionShape2D child.
# Every value below shows up in the Inspector when this script is
# attached, so you can tune the feel by dragging numbers, no code
# changes needed.
#
# Units are pixels at the game's 480x270 base resolution. The character
# is ~30px tall and tiles are 16px, so a jump of ~72px clears about
# four and a half tiles.

# Abilities. The GDD gates these behind staff upgrades, so they're flags
# rather than separate controllers: an upgrade system flips them on and
# the same movement code works before and after the player earns them.
@export var can_dash: bool = true
@export var can_wall_jump: bool = true

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

# Dash. Speed x duration is the distance (~45px, just under 3 tiles).
# Gravity is suspended for the whole dash so it reads as a committed,
# straight line - the Hollow Knight shade-cloak feel rather than a hop.
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.25

# Wall slide and wall jump
@export var wall_slide_speed: float = 60.0
# x pushes away from the wall, y is the upward kick. The push is faster
# than max_speed so a wall jump visibly launches you off the wall.
@export var wall_jump_velocity: Vector2 = Vector2(160.0, -330.0)
# Input is ignored this long after a wall jump. Without it, holding
# toward the wall cancels the push on the very next frame and the jump
# looks like it went straight up.
@export var wall_jump_lock_time: float = 0.14
# Same idea as coyote_time: a jump pressed just after drifting off a
# wall still counts as a wall jump.
@export var wall_coyote_time: float = 0.1
@export var wall_check_distance: float = 2.0

# Below this horizontal speed the run animation hands back to idle, so
# the last few pixels of deceleration don't play a stuttery run cycle.
@export var run_anim_threshold: float = 10.0

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var spawn_position: Vector2
var facing: float = 1.0

var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 1.0
# One dash per trip through the air, refilled on the ground or a wall.
var has_air_dash: bool = true

var wall_coyote_timer: float = 0.0
var last_wall_side: int = 0
var wall_jump_lock_timer: float = 0.0
var is_wall_sliding: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	spawn_position = global_position


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")

	# Jump buffering: a press slightly before landing still counts,
	# instead of getting silently dropped.
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	# Coyote time: a short grace window after walking off a ledge
	# where a jump still counts, so near-misses feel fair.
	if is_on_floor():
		coyote_timer = coyote_time
		has_air_dash = true
	else:
		coyote_timer -= delta

	var wall_side := 0
	if can_wall_jump and not is_on_floor():
		wall_side = _wall_side()
	if wall_side != 0:
		last_wall_side = wall_side
		wall_coyote_timer = wall_coyote_time
	else:
		wall_coyote_timer -= delta

	dash_cooldown_timer -= delta
	if (can_dash and Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0
			and (is_on_floor() or has_air_dash)):
		_start_dash(direction)

	# A jump during a dash cancels it rather than waiting it out. The
	# dash is longer than the jump buffer, so otherwise an early press
	# would expire mid-dash and feel eaten.
	if dash_timer > 0.0 and jump_buffer_timer > 0.0 and (coyote_timer > 0.0 or wall_coyote_timer > 0.0):
		_end_dash()

	if dash_timer > 0.0:
		dash_timer -= delta
		velocity = Vector2(dash_direction * dash_speed, 0.0)
		if dash_timer <= 0.0:
			_end_dash()
	else:
		_apply_movement(direction, wall_side, delta)

	# Floor state has to be read before move_and_slide() updates it,
	# otherwise there's no way to tell that we only just touched down.
	var was_on_floor := is_on_floor()
	move_and_slide()

	# Dashing into a wall ends the dash there, instead of grinding
	# against it for the rest of its duration.
	if dash_timer > 0.0 and is_on_wall():
		_end_dash()

	_update_animation(wall_side, was_on_floor)


func _apply_movement(direction: float, wall_side: int, delta: float) -> void:
	# Horizontal movement. Air acceleration is separate from ground
	# acceleration so you can give the player less control mid-air
	# if you want that heavier, committed-to-the-jump feeling.
	if wall_jump_lock_timer > 0.0:
		wall_jump_lock_timer -= delta
	else:
		var target_speed := direction * max_speed
		var accel := acceleration if is_on_floor() else air_acceleration
		if direction != 0.0:
			velocity.x = move_toward(velocity.x, target_speed, accel * delta)
			facing = signf(direction)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# Asymmetric gravity: falling pulls harder than rising. This is
	# most of what separates "weighty" from "floaty" - it stops the
	# character hanging at the top of a jump arc.
	if velocity.y < 0.0:
		velocity.y += gravity * delta
	else:
		velocity.y += gravity * fall_gravity_multiplier * delta

	# Sliding only happens while holding toward the wall, so the player
	# can always choose to drop past a wall at full speed instead.
	is_wall_sliding = wall_side != 0 and signf(direction) == wall_side and velocity.y > 0.0
	if is_wall_sliding:
		velocity.y = min(velocity.y, wall_slide_speed)
		has_air_dash = true
	else:
		velocity.y = min(velocity.y, max_fall_speed)

	# Ground jump takes priority so standing next to a wall never
	# turns a normal jump into a wall jump.
	if jump_buffer_timer > 0.0:
		if coyote_timer > 0.0:
			velocity.y = jump_velocity
			_consume_jump()
		elif wall_coyote_timer > 0.0:
			velocity = Vector2(-last_wall_side * wall_jump_velocity.x, wall_jump_velocity.y)
			facing = -last_wall_side
			wall_jump_lock_timer = wall_jump_lock_time
			is_wall_sliding = false
			_consume_jump()

	# Variable jump height: releasing the button early cuts the
	# jump short, so tapping gives a hop and holding gives full height.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _consume_jump() -> void:
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	wall_coyote_timer = 0.0


func _start_dash(direction: float) -> void:
	dash_direction = signf(direction) if direction != 0.0 else facing
	# Off a wall the held direction points into it, which would end the
	# dash on its first frame. Dash away from the wall instead.
	if is_wall_sliding:
		dash_direction = -last_wall_side
	facing = dash_direction
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	has_air_dash = false
	wall_jump_lock_timer = 0.0
	is_wall_sliding = false


func _end_dash() -> void:
	dash_timer = 0.0
	# Hand back at run speed rather than dash speed, so the player
	# doesn't skate on after the dash visibly ends.
	velocity.x = dash_direction * max_speed


# Which side a wall is on (-1 left, 1 right, 0 none). test_move probes
# without moving, so it finds walls the player is near but not pushing
# into - needed for wall jumps while drifting away from the wall. The
# normal check stops a ceiling or floor corner counting as a wall.
func _wall_side() -> int:
	for side: int in [1, -1]:
		var collision := KinematicCollision2D.new()
		if test_move(global_transform, Vector2(side * wall_check_distance, 0.0), collision):
			if absf(collision.get_normal().x) > 0.7:
				return side
	return 0


func _update_animation(wall_side: int, was_on_floor: bool) -> void:
	if dash_timer > 0.0:
		sprite.flip_h = dash_direction < 0.0
		_play("dash")
		return

	if is_wall_sliding:
		# The wall sheets are drawn against a wall on the right.
		sprite.flip_h = wall_side < 0
		if sprite.animation != "wall_land" and sprite.animation != "wall_slide":
			_play("wall_land")
		elif sprite.animation == "wall_land" and not sprite.is_playing():
			_play("wall_slide")
		return

	# Facing only changes on input, not velocity, so skidding to a stop
	# after reversing doesn't flicker the sprite back and forth.
	sprite.flip_h = facing < 0.0

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
	dash_timer = 0.0
	wall_jump_lock_timer = 0.0
	is_wall_sliding = false
	has_air_dash = true
