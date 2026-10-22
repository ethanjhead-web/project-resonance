class_name Player
extends CharacterBody2D

# A punch's active frames overlapped a body on the enemies layer. `hit` is
# 1 for the jab, 2 for the cross. Nothing listens yet; enemies will.
signal punch_landed(body: Node2D, hit: int)

# The player is split into one child node per system, each holding that
# system's tunables, state and code:
#   Dash       dash, dive, windup and glow, air ability limit, hard
#              landings, refill and bounce diamonds (player_dash.gd)
#   Crouch     crouch and the low body box, roll, slide, slide jump,
#              charged jump (player_crouch.gd)
#   Slope      slide slopes (player_slope.gd)
#   Climb      climb, handholds, attach, block pushing (player_climb.gd)
#   Ledge      ledge grab, hang and climb (player_ledge.gd)
#   Rope       rope swing (player_rope.gd)
#   Punch      punch combo and hitbox (player_punch.gd)
#   Animation  which animation plays, sprite tilts (player_animation.gd)
# This script is the shared body: running, jumping, gravity, wall slides,
# wall jumps and wall runs, the wall probes, and the order everything runs
# in each frame (_physics_process()). The components reach the body
# through `player`, and each other through its handles (player.dash, ...).
#
# Every @export shows up in the Inspector (on this node, or on the child
# it belongs to), so the feel can be tuned by dragging numbers, no code
# changes needed.
#
# Units are pixels at the game's 480x270 base resolution. The character
# is ~30px tall and tiles are 16px, so a jump of ~72px clears about
# four and a half tiles.

# Abilities. The GDD gates these behind staff upgrades, so they're flags
# rather than separate controllers: an upgrade system flips them on and
# the same movement code works before and after the player earns them.
# Sprint has its own button and doesn't go through this flag.
@export var can_dash: bool = true
@export var can_dive: bool = true
@export var can_wall_jump: bool = true
@export var can_ledge_grab: bool = true
@export var can_climb: bool = true
@export var can_wall_run: bool = true
@export var can_charge_jump: bool = true
# Air abilities: the charged jump, the air dash and the dive each work
# once per trip through the air, and this caps how many of them chain
# before touching the ground. A staff upgrade raises it: at 1 a charged
# jump spends the trip, at 2 it can go into a dash, at 3 a dash can then
# go into a dive. Only the ground resets it.
@export_range(1, 3) var max_air_abilities: int = 3

# Horizontal movement
@export var max_speed: float = 120.0
@export var acceleration: float = 1000.0
@export var friction: float = 900.0
@export var air_acceleration: float = 652.0
# Holding sprint runs at this multiple of max_speed, and only applies
# while a direction is held. Held through a dash, the dash exits straight
# into a sprint without a dip.
@export var sprint_multiplier: float = 1.5

# Vertical movement
@export var jump_velocity: float = -240.0
@export var gravity: float = 800.0
@export var fall_gravity_multiplier: float = 1.6
@export var max_fall_speed: float = 420.0
@export var jump_cut_multiplier: float = 0.45

# Forgiveness windows (in seconds)
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

# Wall slide and wall jump
@export var wall_slide_speed: float = 160.0
# A slide only starts if the wall carries on at least this far below
# the feet. A small block is barely taller than the player, so the
# whole body is against it for just a few frames - without this it
# flashes a slide pose and drops off again.
@export var wall_slide_min_length: float = 8.0
# x pushes away from the wall, y is the upward kick. The push is faster
# than max_speed so a wall jump visibly launches you off the wall.
@export var wall_jump_velocity: Vector2 = Vector2(120.0, -240.0)
# Each jump in a trip through the air is smaller than the last, so a shaft
# can be worked down but never bounced up. Rising (or clinging) jumps run a
# sequence: the first is full (a ground jump, or the jump straight off a
# climb or wall run, which gain height honestly), the next wall jump gets
# wall_jump_second_height of its height, the one after that
# wall_jump_third_height, and after that jump does nothing against a wall.
# A jump while moving down the wall (sliding, or falling past it) is always
# wall_jump_slide_height and doesn't use up the sequence, so a shaft can
# always be jumped down, but it's capped at where the last sliding jump
# took off, so a chain of them can only hold level or go down. The ground,
# a climb and a wall run reset it all.
@export_range(0.0, 1.0) var wall_jump_second_height: float = 1.0
@export_range(0.0, 1.0) var wall_jump_third_height: float = 1.0
@export_range(0.0, 1.0) var wall_jump_slide_height: float = 0.4
# Input is ignored this long after a wall jump. Without it, holding
# toward the wall cancels the push on the very next frame and the jump
# looks like it went straight up.
@export var wall_jump_lock_time: float = 0.14
# Same idea as coyote_time: a jump pressed just after drifting off a
# wall still counts as a wall jump.
@export var wall_coyote_time: float = 0.1
@export var wall_check_distance: float = 2.0

# Wall run. Sprinting into a wall carries the run up it, starting at
# wall_run_speed and slowing evenly to a stop at wall_run_height pixels.
# The slowdown is solved from the two, so they stay independent: height
# sets how far, speed sets how punchy the start is. 72 would match a
# full jump; 40 (2.5 tiles) for now.
@export var wall_run_height: float = 40.0
# 180 is the sprint speed (max_speed x sprint_multiplier), so the run
# turns the corner without a jump in speed.
@export var wall_run_speed: float = 180.0
# How fast the player has to be going when they hit the wall. Above
# max_speed so a plain run into a wall still just pushes against it.
@export var wall_run_min_speed: float = 152.0

# Below this horizontal speed the run animation hands back to idle, so
# the last few pixels of deceleration don't play a stuttery run cycle.
@export var run_anim_threshold: float = 12.0

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var spawn_position: Vector2
var facing: float = 1.0

# Highest point (lowest y) of the current fall. Anything that holds the
# player up resets it, so a fall is measured from where they let go.
var fall_peak_y: float = 0.0

var wall_coyote_timer: float = 0.0
var last_wall_side: int = 0
var wall_jump_lock_timer: float = 0.0
var is_wall_sliding: bool = false

var is_wall_running: bool = false
# Whether this trip through the air counts as a sprint. Holding the
# button mid-air only keeps sprint speed if the player left the ground
# sprinting; it can't be picked up in the air.
var air_sprint: bool = false
var wall_run_side: int = 0
# Counts down from wall_coyote_time once a wall run ends. A jump inside it
# is still the full jump off the run: the run ends the moment it stops
# rising, so without this a press a frame after the top was a sliding one.
var wall_run_coyote_timer: float = 0.0

# Set by a slide jump: the jump keeps its sideways speed
# until landing instead of being eased back to run speed (see
# apply_movement()). Any other jump, a dash, a grab or landing clears it.
var is_carrying_momentum: bool = false
# Rising from a bounce diamond or a charged jump. Letting go of jump
# doesn't cut it short: the launch isn't a jump the player is holding.
var is_launched: bool = false
# Jumps used from the sequence since the ground, a climb or a wall run,
# the jump that left them included (see wall_jump_second_height).
var wall_jumps_used: int = 0
# Where the last sliding wall jump took off (global y), the cap on the next
# one's peak. -INF when there hasn't been one this trip.
var last_slide_jump_y: float = -INF

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
# Where the sprite sits when upright. The rope tilt and the slope lean move
# it off this.
@onready var sprite_base_position: Vector2 = sprite.position
@onready var body_shape: CollisionShape2D = $CollisionShape2D
# Crouch, roll and slide swap the body box for a lower one. The ledge
# probe and the standing-room check always use standing_shape.
@onready var standing_shape := body_shape.shape as RectangleShape2D

@onready var dash: PlayerDash = $Dash
@onready var crouch: PlayerCrouch = $Crouch
@onready var slope: PlayerSlope = $Slope
@onready var climb: PlayerClimb = $Climb
@onready var ledge: PlayerLedge = $Ledge
@onready var rope: PlayerRope = $Rope
@onready var punch: PlayerPunch = $Punch
@onready var anim: PlayerAnimation = $Animation


func _ready() -> void:
	spawn_position = global_position
	fall_peak_y = global_position.y
	crouch.setup()


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	dash.update_tint(delta)
	if velocity.y >= 0.0:
		is_launched = false
	anim.straighten(delta)

	# Ahead of the ledge states' early returns, so a hang resets it too.
	# A wall slide or climb breaks the fall, so sliding down a tall wall
	# isn't a hard landing.
	if (is_on_floor() or ledge.is_on_ledge() or is_wall_sliding or climb.is_climbing
			or is_wall_running or rope.swing_rope != null or dash.diamond_freeze_timer > 0.0):
		fall_peak_y = global_position.y
	else:
		fall_peak_y = minf(fall_peak_y, global_position.y)
	if is_on_floor() or climb.is_climbing or is_wall_running:
		last_slide_jump_y = -INF
		wall_jumps_used = 0
	if is_wall_running:
		wall_run_coyote_timer = wall_coyote_time
	else:
		wall_run_coyote_timer -= delta

	if dash.diamond_freeze_timer > 0.0:
		dash.process_diamond_freeze(delta)
		return

	# Jump buffering: a press slightly before landing still counts,
	# instead of getting silently dropped.
	# Under a ceiling too low to stand (a crawl tunnel), jump does nothing
	# at all: no hop into the ceiling, no charge, and no cutting a roll or
	# slide short. A press buffered on the way in is dropped too, so it
	# can't fire the moment the player comes out the other side.
	if crouch.is_low() and not crouch.can_stand():
		jump_buffer_timer = 0.0
	elif Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	# A ledge hang or climb, or a rope swing, owns the body while it lasts.
	if ledge.update(direction, delta) or rope.update(direction, delta):
		return

	# Coyote time: a short grace window after walking off a ledge
	# where a jump still counts, so near-misses feel fair.
	if is_on_floor():
		# Not while wall running: is_on_floor() is still true on the frame
		# after the run starts, and refilling coyote then would let a jump
		# up to coyote_time later fire as a ground jump from up the wall.
		if not is_wall_running:
			coyote_timer = coyote_time
		dash.has_air_dash = true
		dash.has_air_dive = true
		dash.air_abilities_used = 0
		slope.slope_coyote_timer = 0.0
		crouch.slide_coyote_timer = 0.0
		is_carrying_momentum = false
		# Updated every grounded frame, so it's frozen at whatever it was
		# on takeoff. Needs actual sprint pace, not just the button: a
		# standing jump with it held shouldn't steer like a sprint.
		air_sprint = Input.is_action_pressed("sprint") and absf(velocity.x) > max_speed
	else:
		coyote_timer -= delta
		slope.slope_coyote_timer -= delta
		crouch.slide_coyote_timer -= delta
	# Refreshed by a real sprint on the ground, not a dash or the slide's
	# own speed, so the window only opens coming out of a sprint. Pressing
	# Down to slide crouches and starts slowing the body straight away, so
	# without the window the press would have to land on the exact frame.
	if is_on_floor() and air_sprint and dash.dash_timer <= 0.0 and not crouch.is_sliding:
		crouch.slide_window_timer = crouch.slide_sprint_window
	else:
		crouch.slide_window_timer -= delta

	var wall_side := 0
	if can_wall_jump and not is_on_floor():
		wall_side = touching_wall_side()
	if wall_side != 0:
		last_wall_side = wall_side
		wall_coyote_timer = wall_coyote_time
	else:
		wall_coyote_timer -= delta

	dash.handle_press(direction, delta)

	# A jump during a dash cancels it rather than waiting it out. The
	# dash is longer than the jump buffer, so otherwise an early press
	# would expire mid-dash and feel eaten.
	if dash.dash_timer > 0.0 and jump_buffer_timer > 0.0 and (coyote_timer > 0.0 or wall_coyote_timer > 0.0):
		dash.end_dash()

	if (not climb.is_climbing and dash.dash_timer <= 0.0 and dash.windup_timer <= 0.0 and not dash.is_diving
			and not crouch.is_charging_jump and not slope.is_slope_sliding and climb.can_start_climb(direction)):
		climb.start_climb()
	climb.try_start_attach(direction)

	punch.update(direction, delta)
	crouch.update_crouch()
	crouch.try_start_charge()

	# Whichever state owns the body moves it. The windup, dash, dive and
	# the dive's landing recovery come first (dash.apply() returns true
	# when one of them ran).
	if dash.apply(delta):
		pass
	elif crouch.is_charging_jump:
		crouch.apply_jump_charge(delta)
	elif slope.is_slope_sliding:
		slope.apply_slope_slide()
	elif crouch.roll_timer > 0.0:
		crouch.apply_roll(direction, delta)
	elif crouch.is_sliding:
		crouch.apply_slide(direction, delta)
	elif climb.is_climbing:
		climb.apply_climb(direction, delta)
	elif climb.is_attached:
		climb.apply_attach(direction, delta)
	elif punch.is_punching() and is_on_floor():
		apply_attack_movement(delta)
	elif punch.is_punching():
		punch.apply_air_attack_movement(direction, delta)
	else:
		apply_movement(direction, wall_side, delta)

	# Floor state has to be read before move_and_slide() updates it,
	# otherwise there's no way to tell that we only just touched down.
	var was_on_floor := is_on_floor()
	# move_and_slide() zeroes velocity.x on the frame the body meets a
	# wall, so the speed it hit the wall at has to be read beforehand.
	var approach_speed := absf(velocity.x)
	move_and_slide()

	slope.update_after_move(direction)
	dash.update_landing(was_on_floor)

	if _update_wall_run(direction, approach_speed):
		return

	# A dash ends early when it hits a wall, rather than pinning the
	# player against it for the rest of its duration.
	if dash.dash_timer > 0.0 and get_real_velocity().length() < dash.dash_speed * 0.1:
		dash.end_dash()

	# Like the ledge grab, a rope is only caught with grab held. Unlike it,
	# rising doesn't matter: jumping up to a rope is the usual way on.
	if (not is_on_floor() and not dash.is_diving and dash.windup_timer <= 0.0
			and Input.is_action_pressed("grab") and rope.try_catch_rope()):
		return

	# Checked after moving so the ledge test uses this frame's position.
	# Only on the way down (or flat, mid-dash): grabbing while rising
	# would interrupt jumps that were already going to clear the ledge.
	# Climbing up is the exception - reaching the top of a wall hands off
	# to the ledge hang, and holding Up then mounts it. Catching needs
	# grab held, like the climb, so ledges only stop the player when
	# they ask to be stopped.
	# Never mid-dive or mid-windup, which commit the body until they end.
	if (can_ledge_grab and ledge.ledge_regrab_timer <= 0.0 and not is_on_floor() and not dash.is_diving
			and dash.windup_timer <= 0.0
			and Input.is_action_pressed("grab")
			and (velocity.y >= 0.0 or climb.is_climbing or is_wall_running)
			and ledge.try_grab_ledge(int(facing))):
		return

	anim.update_animation(direction, wall_side, was_on_floor)


func apply_movement(direction: float, wall_side: int, delta: float) -> void:
	# Horizontal movement. Air acceleration is separate from ground
	# acceleration so you can give the player less control mid-air
	# if you want that heavier, committed-to-the-jump feeling.
	if wall_jump_lock_timer > 0.0:
		wall_jump_lock_timer -= delta
	elif is_wall_running:
		# Pinned to the wall for the whole run, whatever is held. Lining
		# up the jump away from it before pressing jump is the natural way
		# to play a wall jump, and steering away here would peel the
		# player off the wall and end the run before the jump lands.
		velocity.x = wall_run_side * 10.0
	else:
		var target_speed := direction * run_speed()
		# Running up a slide slope (it's only floor while uphill is held)
		# eases off a little, whatever the pace.
		var slope_normal := slope.slide_slope_normal()
		if is_on_floor() and slope_normal != Vector2.ZERO and signf(direction) == -signf(slope_normal.x):
			target_speed *= slope.slope_uphill_speed_multiplier
		var accel := acceleration if is_on_floor() else air_acceleration
		# A slide jump keeps the slide's speed: holding forward doesn't
		# ease it back to run speed and letting go doesn't brake it. Only
		# steering against it slows it, so the long jump stays a choice.
		var carrying := is_carrying_momentum and not is_on_floor()
		if direction != 0.0:
			var ahead := signf(direction) == signf(velocity.x) and absf(velocity.x) > absf(target_speed)
			if not (carrying and ahead):
				velocity.x = move_toward(velocity.x, target_speed, accel * delta)
			facing = signf(direction)
		elif not carrying:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# A slope too steep to run up stops the run dead at its foot, like a
	# wall, rather than climbing it. Moved up to the contact first, so the
	# feet end flush with it the way they do against a wall.
	if is_on_floor() and velocity.x != 0.0:
		var hit := slope.steep_slope_ahead(velocity.x * delta)
		if hit:
			velocity.x = hit.get_travel().x / delta

	# Walking into a MovableBlock shoves it. Not with sprint held: then it
	# acts as a wall, so a sprint into it wall runs up and mounts the top.
	if is_on_floor() and direction != 0.0 and not Input.is_action_pressed("sprint"):
		climb.push_block_ahead(int(signf(direction)), delta)

	# Asymmetric gravity: falling pulls harder than rising. This is
	# most of what separates "weighty" from "floaty" - it stops the
	# character hanging at the top of a jump arc.
	# A wall run brakes at its own even rate instead of gravity, so it
	# eases to a stop at exactly wall_run_height (v^2 = 2 * a * h).
	if is_wall_running:
		velocity.y += wall_run_speed * wall_run_speed / (2.0 * wall_run_height) * delta
	elif velocity.y < 0.0:
		velocity.y += gravity * delta
	else:
		velocity.y += gravity * fall_gravity_multiplier * delta

	# Sliding only happens while holding toward the wall, so the player
	# can always choose to drop past a wall at full speed instead.
	# Starting a slide needs some wall left below the feet; keeping one
	# going only needs the feet still on it. See _is_wall_full_height().
	var below := 0.0 if is_wall_sliding else wall_slide_min_length
	is_wall_sliding = (wall_side != 0 and signf(direction) == wall_side and velocity.y > 0.0
			and _is_wall_full_height(wall_side, below))
	if is_wall_sliding:
		# No air dash refill here, or on a climb: a wall shouldn't hand
		# the dash back, so routes up a shaft can't chain dash after dash
		# off its walls. Only the ground refills it (not a ledge hang either).
		velocity.y = min(velocity.y, wall_slide_speed)
	else:
		velocity.y = min(velocity.y, max_fall_speed)

	# Ground jump takes priority so standing next to a wall never
	# turns a normal jump into a wall jump.
	# A wall run is the exception: any jump during one pushes off the wall,
	# even before the wall probe has caught up and set wall coyote.
	if jump_buffer_timer > 0.0:
		if is_wall_running:
			wall_jump(wall_run_side, true)
		elif coyote_timer > 0.0 and slope.slope_coyote_timer > 0.0:
			slope.slope_kick()
		elif coyote_timer > 0.0 and crouch.slide_coyote_timer > 0.0:
			crouch.slide_jump()
		elif coyote_timer > 0.0:
			velocity.y = jump_velocity
			consume_jump()
		elif wall_run_coyote_timer > 0.0:
			wall_jump(wall_run_side, true)
		elif wall_coyote_timer > 0.0 and not wall_jump(last_wall_side):
			# Out of wall jumps: the press is dropped, not held to fire
			# later, and the player just keeps sliding or falling.
			jump_buffer_timer = 0.0

	# Variable jump height: releasing the button early cuts the
	# jump short, so tapping gives a hop and holding gives full height.
	if Input.is_action_just_released("jump") and velocity.y < 0.0 and not is_launched:
		velocity.y *= jump_cut_multiplier


# Returns false, doing nothing, once the sequence is used up. fresh is a
# jump straight off a climb or a wall run: a full jump with no cap.
func wall_jump(side: int, fresh: bool = false) -> bool:
	var height := 1.0
	var cap_y := -INF
	if fresh:
		wall_jumps_used = 1
	elif velocity.y > 0.0:
		height = wall_jump_slide_height
		# Without the cap, a jump caught at the top of its arc on the far
		# wall counts as sliding and nets a little height every crossing,
		# enough to climb a shaft. It's only against the last sliding jump,
		# not any wall jump: a full jump off a wall run usually meets the far
		# wall falling but still above its own takeoff, and capping against
		# that left this one no lift at all.
		cap_y = last_slide_jump_y
		last_slide_jump_y = global_position.y
	else:
		if wall_jumps_used >= 3:
			return false
		wall_jumps_used += 1
		if wall_jumps_used == 2:
			height = wall_jump_second_height
		elif wall_jumps_used == 3:
			height = wall_jump_third_height
	# Height goes with the square of the launch speed (v² = 2gh), and the
	# cap is the speed that peaks exactly at cap_y (none if already above).
	var lift := -wall_jump_velocity.y * sqrt(height)
	if cap_y > -INF:
		lift = minf(lift, sqrt(2.0 * gravity * maxf(global_position.y - cap_y, 0.0)))
	# Every wall jump is a plain one, even out of a wall run with sprint
	# held. The jump off a wall run is for gaining height, not for
	# carrying the sprint into a long horizontal leap.
	air_sprint = false
	velocity = Vector2(-side * wall_jump_velocity.x, -lift)
	facing = -side
	wall_jump_lock_timer = wall_jump_lock_time
	is_wall_sliding = false
	is_wall_running = false
	wall_run_coyote_timer = 0.0
	consume_jump()
	return true


# Starts on the ground only: the sprint has to be carried into the wall,
# not picked up mid-air. It slows to a stop at wall_run_height and
# hands off to whatever the wall normally does - slide if holding
# toward it, climb if holding grab. A wall short enough for the hands
# to reach its top gets mounted. Returns true when it starts a mount,
# since the ledge climb then owns the body and its animation.
func _update_wall_run(direction: float, approach_speed: float) -> bool:
	var side := int(signf(direction))
	if is_wall_running:
		# Reaching the top of a short wall mounts it straight away, with
		# no hang and no grab needed: the run's momentum carries the body
		# up and over. The run is all but spent by the time the hands
		# clear the top, so without this the player would stall there
		# with their feet still a body-height below the lip.
		# Holding away skips the mount, since that's the player lining up
		# a wall jump.
		if side != -wall_run_side and ledge.try_mount_ledge(wall_run_side):
			return true
		# Toward only has to be held to start the run. After that it's
		# the sprint button that keeps it going, so the d-pad is free to
		# line up the jump off. Ends at the top of the run, or early on
		# letting go of sprint, grabbing, bumping a ceiling, or the hands
		# passing the top of a wall with no room to stand on it.
		if (velocity.y >= 0.0 or climb.is_climbing or not Input.is_action_pressed("sprint")
				or not is_wall_at_hands(wall_run_side)):
			is_wall_running = false
		return false
	# Only from standing height: a roll or slide into a wall would otherwise read
	# the hand probe from the crouch box's top.
	if (can_wall_run and is_on_floor() and side != 0 and Input.is_action_pressed("sprint")
			and not crouch.is_low() and approach_speed >= wall_run_min_speed and is_wall_at_hands(side)):
		is_wall_running = true
		wall_run_side = side
		velocity.y = -wall_run_speed
		# Without this the ground coyote window would turn a jump in the
		# first few frames into a plain jump. Off a wall it should push
		# away, like any other jump off a wall.
		coyote_timer = 0.0
	return false


# Feet planted: the run skids to a stop under friction rather than halting
# dead, and gravity keeps the body on slopes and steps. Used by a grounded
# punch, the dive's landing recovery, a jump charge and an attach.
func apply_attack_movement(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	velocity.y = minf(velocity.y + gravity * fall_gravity_multiplier * delta, max_fall_speed)


func run_speed() -> float:
	if crouch.is_crouching:
		return crouch.crawl_speed
	var sprinting := Input.is_action_pressed("sprint") and (is_on_floor() or air_sprint)
	return max_speed * (sprint_multiplier if sprinting else 1.0)


func consume_jump() -> void:
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	wall_coyote_timer = 0.0
	# A jump out of a launch (off a wall, say) is a normal, cuttable one.
	is_launched = false
	# The slide jump and slope kick set it again straight after.
	is_carrying_momentum = false
	# Any jump off the ground (or a rope) is the first of the trip's
	# sequence, so the first wall jump after it is already the smaller one.
	# A wall jump sets its own count before getting here.
	wall_jumps_used = maxi(wall_jumps_used, 1)


# Called by a RefillDiamond the player is touching. Returns whether it
# was taken, so the diamond only vanishes when it did something.
func touch_diamond(launch: bool) -> bool:
	return dash.touch_diamond(launch)


# The wall the player is holding on to by sliding, climbing or running up
# it (-1 left, 1 right), or 0.
func held_wall_side() -> int:
	if is_wall_sliding:
		return last_wall_side
	if climb.is_climbing:
		return climb.climb_side
	if is_wall_running:
		return wall_run_side
	return 0


# Which side a wall is on (-1 left, 1 right, 0 none). test_move probes
# without moving, so it finds walls the player is near but not pushing
# into - needed for wall jumps while drifting away from the wall. The
# normal check stops a ceiling or floor corner counting as a wall.
func touching_wall_side() -> int:
	for side: int in [1, -1]:
		if _is_wall(side):
			return side
	return 0


# True only when wall covers both head and feet (and, with `below`, runs
# on past the feet that far). _is_wall() counts any contact, so feet
# clipping the top corner of a block would start a slide while the body
# is still in the air above it.
func _is_wall_full_height(side: int, below: float = 0.0) -> bool:
	return is_wall_at_hands(side) and _is_wall_at(side, global_position.y - 1.0 + below)


# True when the wall is level with the hands (the top of the body).
func is_wall_at_hands(side: int) -> bool:
	return _is_wall_at(side, hands_y())


func hands_y() -> float:
	var size: Vector2 = (body_shape.shape as RectangleShape2D).size
	var top := global_position.y + body_shape.position.y - size.y * 0.5
	# Inset 1px from the top edge (and the feet ray from the bottom edge)
	# so a ray lying exactly on a tile seam doesn't count.
	return top + 1.0


func _is_wall_at(side: int, y: float) -> bool:
	return wall_at(side, y) != null


# Whatever solid body is within reach on `side` at height `y`, or null.
func wall_at(side: int, y: float) -> Object:
	return wall_hit(side, y).get("collider")


# The ray hit behind wall_at(), for when the contact point matters too.
# Empty if nothing is in reach.
func wall_hit(side: int, y: float) -> Dictionary:
	var size: Vector2 = (body_shape.shape as RectangleShape2D).size
	var ray := PhysicsRayQueryParameters2D.create(
			Vector2(global_position.x, y),
			Vector2(global_position.x + side * (size.x * 0.5 + wall_check_distance), y),
			collision_mask, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(ray)


func _is_wall(side: int) -> bool:
	var collision := KinematicCollision2D.new()
	if test_move(global_transform, Vector2(side * wall_check_distance, 0.0), collision):
		# A steep slide slope's face reads as a wall on the ground, so a run
		# into its foot plays the push. In the air it's a slope to land and
		# slide on, never a wall to slide down or jump off.
		if collision.get_collider() is SlideSlope and collision.get_normal().y < -0.1 and not is_on_floor():
			return false
		return absf(collision.get_normal().x) > 0.7
	return false


func respawn() -> void:
	global_position = spawn_position
	fall_peak_y = spawn_position.y
	velocity = Vector2.ZERO
	is_launched = false
	wall_jump_lock_timer = 0.0
	is_wall_sliding = false
	is_wall_running = false
	is_carrying_momentum = false
	wall_jumps_used = 0
	last_slide_jump_y = -INF
	wall_run_coyote_timer = 0.0
	dash.reset()
	crouch.reset()
	slope.reset()
	climb.reset()
	ledge.reset()
	rope.reset()
	anim.reset()
	punch.end_attack()
