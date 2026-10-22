class_name PlayerSlope
extends Node

# Slide slopes (SlideSlope triangles): sliding down them, kicking off
# them, running up the gentle ones and being stopped by the steep ones.

# Slide slopes are too slippery to stand on: landing on one slides the
# player down it at this constant speed, along the slope, whatever is
# held. Steady rather than gathering speed, so every slide off a slope
# launches the same way and routes can be timed.
@export var slope_slide_speed: float = 180.0
# A jump off a slope kicks out at right angles to it, like a wall jump
# off a tilted wall. At 340 a 45° slope gives the upward speed of a full
# jump (240) and as much again sideways, away from the slope.
@export var slope_kick_speed: float = 340.0
# Air steering is ignored this long after the kick (via
# wall_jump_lock_timer), so the push-off carries before input takes over.
@export var slope_kick_lock_time: float = 0.15
# Slopes up to this steep (from flat) can be run up while the uphill
# direction is held; let go and it's slippery again, and the slide takes
# over. Anything steeper stops a run dead at its foot, like a wall. C2
# and C3 are 45°, C4 about 34°.
@export var slope_max_run_up_angle: float = 40.0
# Running up a slope eases to this fraction of whatever speed was held
# (a run or a sprint), so the climb reads as effort without stalling.
@export var slope_uphill_speed_multiplier: float = 0.8

# How hard a slope slide presses into the surface on top of sliding along
# it. move_and_slide() only reports surfaces it pushes against, so this
# keeps the slope showing up every frame and the slide never loses it.
const SLOPE_STICK_SPEED := 40.0

var is_slope_sliding: bool = false
# The slope being slid down, as its surface normal. Kept after leaving it
# so a jump just off the end still kicks off it (slope_coyote_timer).
var slope_normal: Vector2 = Vector2.UP
var slope_coyote_timer: float = 0.0

@onready var player := get_parent() as Player


# Read from this frame's contacts, so a landing on a slope slides
# straight away instead of touching down first. A dash or windup runs
# its course and then slides. Holding uphill on a slope gentle enough
# to run up is plain running instead (slowed in apply_movement()), but
# never once a slide has started: that's a committed ride down.
func update_after_move(direction: float) -> void:
	var slope := slide_slope_normal()
	if slope != Vector2.ZERO:
		slope_normal = slope
	var running_up := (slope != Vector2.ZERO and not is_slope_sliding and direction != 0.0
			and signf(direction) == -signf(slope.x) and slope_angle(slope) <= slope_max_run_up_angle)
	if (slope != Vector2.ZERO and not running_up and player.dash.dash_timer <= 0.0
			and player.dash.windup_timer <= 0.0):
		if not is_slope_sliding:
			start_slope_slide()
	elif is_slope_sliding and slope == Vector2.ZERO:
		end_slope_slide()


# The SlideSlope pushed against this frame, as its surface normal, or ZERO.
# Only its slope counts: the upright side and the base are plain wall and
# floor (their normals are straight across or straight down).
func slide_slope_normal() -> Vector2:
	for i in player.get_slide_collision_count():
		var hit := player.get_slide_collision(i)
		var normal := hit.get_normal()
		if hit.get_collider() is SlideSlope and normal.y < -0.1 and absf(normal.x) > 0.1:
			return normal
	return Vector2.ZERO


# Whatever the body was doing gives way to the slide: a dive or a hard
# fall lands into it with no recovery, since the slope takes the impact.
func start_slope_slide() -> void:
	is_slope_sliding = true
	player.dash.is_diving = false
	player.dash.dive_land_timer = 0.0
	player.crouch.roll_timer = 0.0
	player.crouch.is_sliding = false
	player.crouch.is_charging_jump = false
	player.anim.is_air_spinning = false
	player.is_wall_running = false
	player.punch.end_attack()


# Off the end of a slope: into the air it keeps the slide's velocity and
# allows a kick for coyote_time; onto flat ground it carries straight
# into the ground slide, which bleeds the speed off, rather than
# stopping dead under running friction.
func end_slope_slide() -> void:
	is_slope_sliding = false
	if player.is_on_floor():
		player.crouch.is_sliding = true
		player.velocity.x = player.facing * slope_slide_speed
	else:
		slope_coyote_timer = player.coyote_time


# Constant speed straight down the slope. Nothing held steers it.
func apply_slope_slide() -> void:
	if player.jump_buffer_timer > 0.0:
		slope_kick()
		return
	var downhill := Vector2(-slope_normal.y, slope_normal.x)
	if downhill.y < 0.0:
		downhill = -downhill
	player.facing = signf(downhill.x)
	player.velocity = downhill * slope_slide_speed - slope_normal * SLOPE_STICK_SPEED


# The slope's angle from flat, in degrees.
func slope_angle(normal: Vector2) -> float:
	return rad_to_deg(acos(clampf(-normal.y, -1.0, 1.0)))


# The collision if moving `motion` px sideways would run into a SlideSlope
# too steep to run up (rising the way the body is going), else null.
func steep_slope_ahead(motion: float) -> KinematicCollision2D:
	var hit := KinematicCollision2D.new()
	if not player.test_move(player.global_transform, Vector2(motion, 0.0), hit):
		return null
	var normal := hit.get_normal()
	if (hit.get_collider() is SlideSlope and normal.y < -0.1 and signf(normal.x) == -signf(motion)
			and slope_angle(normal) > slope_max_run_up_angle):
		return hit
	return null


# Out at right angles to the slope, with the rope jump's somersault. It
# can be cut short by releasing jump, like any other jump. The slide's
# own speed isn't added: the kick is the same push every time.
func slope_kick() -> void:
	player.velocity = slope_normal * slope_kick_speed
	player.facing = signf(slope_normal.x)
	player.wall_jump_lock_timer = slope_kick_lock_time
	is_slope_sliding = false
	slope_coyote_timer = 0.0
	player.consume_jump()
	player.anim.start_air_spin()


func reset() -> void:
	is_slope_sliding = false
	slope_coyote_timer = 0.0
