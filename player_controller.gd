extends CharacterBody2D

# Attach this to a CharacterBody2D with a CollisionShape2D child.
# Every value below shows up in the Inspector when this script is
# attached, so you can tune the feel by dragging numbers, no code
# changes needed.

# Horizontal movement
@export var max_speed: float = 220.0
@export var acceleration: float = 1800.0
@export var friction: float = 1400.0
@export var air_acceleration: float = 900.0

# Vertical movement
@export var jump_velocity: float = -420.0
@export var gravity: float = 1400.0
@export var fall_gravity_multiplier: float = 1.6
@export var max_fall_speed: float = 700.0
@export var jump_cut_multiplier: float = 0.45

# Forgiveness windows (in seconds)
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0


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

	move_and_slide()
