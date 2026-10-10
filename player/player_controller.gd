extends CharacterBody2D

# A punch's active frames overlapped a body on the enemies layer. `hit` is
# 1 for the jab, 2 for the cross. Nothing listens yet; enemies will.
signal punch_landed(body: Node2D, hit: int)

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
# Sprint has its own button and doesn't go through this flag.
@export var can_dash: bool = true
@export var can_dive: bool = true
@export var can_wall_jump: bool = true
@export var can_ledge_grab: bool = true
@export var can_climb: bool = true
@export var can_wall_run: bool = true

# Horizontal movement
@export var max_speed: float = 120.0
@export var acceleration: float = 1000.0
@export var friction: float = 900.0
@export var air_acceleration: float = 650.0

# Vertical movement
@export var jump_velocity: float = -240.0
@export var gravity: float = 800.0
@export var fall_gravity_multiplier: float = 1.6
@export var max_fall_speed: float = 420.0
@export var jump_cut_multiplier: float = 0.45

# Forgiveness windows (in seconds)
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

# Dash (A in the air). Left or right only, from the held direction; on
# the ground A slides instead. Speed x duration is the distance (~45px, just under 3 tiles).
# Gravity is suspended for the whole dash so it reads as a committed,
# straight line rather than a hop.
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.15
# A dash out of a sprinting takeoff runs longer (~60px, nearly 4 tiles),
# so carrying momentum into it pays off. Same speed, so it reads as the same move.
@export var sprint_dash_duration: float = 0.2
@export var dash_cooldown: float = 0.25
# Holding sprint runs at this multiple of max_speed, and only applies
# while a direction is held. Held through a dash, the dash exits straight
# into a sprint without a dip.
@export var sprint_multiplier: float = 1.5

# Dive (Hollow Knight's Desolate Dive): dash with straight Down held in
# the air drops straight to the ground and doesn't stop until it lands.
# Faster than max_fall_speed, so it reads as a slam, not a fall.
@export var dive_speed: float = 480.0
# Feet planted this long after the dive lands. A beat of recovery sells
# the impact and keeps the dive a commitment rather than a free fast-fall.
@export var dive_land_time: float = 0.8
# A fall from at least this high lands as hard as a dive, with the same
# recovery (but no glow, since nothing magic happened). The test room's
# climbable column is 224px from its top to the floor at its foot; this
# sits a little under that so stepping straight off it always counts,
# whatever fraction of a pixel the floor snap leaves.
@export var hard_land_height: float = 220.0

# Wind-up before a dash or dive: the body hangs still, the sprite holds
# its frame and brightens toward ability_windup_glow, then the move
# fires. A stand-in for a proper power-up animation, so the abilities
# read as magic being gathered rather than a plain burst of speed.
# 0.1s is 6 frames at 60fps.
@export var ability_windup_time: float = 0.2
# Above 1.0 brightens the sprite (modulate multiplies).
@export var ability_windup_glow: Color = Color(2.0, 3.0, 4.0)
# The glow holds through the dash or dive, then fades back over this
# long once it ends, rather than snapping off in a single frame.
@export var ability_glow_fade_time: float = 0.4

# Wall slide and wall jump
@export var wall_slide_speed: float = 80.0
# A slide only starts if the wall carries on at least this far below
# the feet. A small block is barely taller than the player, so the
# whole body is against it for just a few frames - without this it
# flashes a slide pose and drops off again.
@export var wall_slide_min_length: float = 8.0
# x pushes away from the wall, y is the upward kick. The push is faster
# than max_speed so a wall jump visibly launches you off the wall.
@export var wall_jump_velocity: Vector2 = Vector2(120.0, -240.0)
# Input is ignored this long after a wall jump. Without it, holding
# toward the wall cancels the push on the very next frame and the jump
# looks like it went straight up.
@export var wall_jump_lock_time: float = 0.14
# Same idea as coyote_time: a jump pressed just after drifting off a
# wall still counts as a wall jump.
@export var wall_coyote_time: float = 0.1
@export var wall_check_distance: float = 2.0
# Physics layers holding GripSurface areas. Only walls marked with one
# can be climbed; slides, wall jumps and ledge grabs work on any wall.
@export_flags_2d_physics var grip_mask: int = 4
# Push and pull speed from an attach on a MovableBlock. Slow and even, so
# moving a block reads as effort rather than carrying it.
@export var push_speed: float = 45.0

# Wall climb (Celeste-style: hold grab against a wall). Speeds are
# Celeste's, scaled by our run speed so the climb keeps the same
# relationship to running that it has there.
@export var climb_up_speed: float = 60.0
@export var climb_down_speed: float = 120.0
# Stamina is measured in seconds of climbing upward. It only refills on
# the ground, which is what turns a wall into a route you plan rather
# than a place you can rest.
@export var climb_stamina: float = 3.0
# Drain per second while holding still, relative to climbing up. 0.22
# is Celeste's ratio: clinging buys time, climbing spends it.
@export var climb_hold_drain: float = 0.22
# Below this the player pulses red, so running low is visible, not
# just felt. Celeste warns at about a fifth of the bar.
@export var climb_tired_threshold: float = 0.6

# Ledge grab and climb
# Where the fingertips sit relative to the feet in the hang frame. The
# hang snaps so this point lands exactly on the ledge corner, which is
# what makes it read as holding on rather than floating near the wall.
@export var ledge_hand_offset: Vector2 = Vector2(6.0, -28.0)
# How far the ledge top can be above or below the hands and still be
# caught. Bigger is more forgiving, but a big snap looks like a teleport.
@export var ledge_snap_range: float = 8.0
# How far past the body edge to look for the wall.
@export var ledge_reach: float = 4.0
# Brief hold before a climb can start, so Up held through the catch
# still shows the hang for a beat instead of skipping straight past it.
@export var ledge_catch_time: float = 0.08
@export var ledge_climb_time: float = 0.33
# How far onto the ledge the climb finishes, so the whole body clears
# the corner instead of teetering on it.
@export var ledge_stand_inset: float = 10.0
# Ledges are ignored this long after letting go, otherwise dropping
# while still facing the wall re-grabs the same ledge next frame.
@export var ledge_regrab_delay: float = 0.25

# Rope swing. Hold grab to catch a SwingRope anywhere along it; the hands
# go where the catch box (centred on them) met the rope. The swing is a
# pendulum from the anchor to the hands, using the player's gravity.
@export_flags_2d_physics var rope_mask: int = 8
@export var rope_catch_size: Vector2 = Vector2(16.0, 16.0)
# Up and Down move the hands along the rope. They stop this far below the
# anchor, so the head stays clear of the ceiling.
@export var rope_climb_speed: float = 60.0
@export var rope_min_hold: float = 16.0
# Holding the way the swing is already going pushes it along, like
# pumping a playground swing, until it reaches rope_max_angle (degrees).
@export var rope_pump_accel: float = 220.0
@export var rope_max_angle: float = 70.0
# A little friction, so a swing nobody pumps slowly dies down.
@export var rope_damping: float = 0.15
# A jump off the rope keeps the swing's speed and adds this much lift.
@export var rope_jump_boost: float = -180.0
# Air steering is ignored this long after a jump off the rope, the same
# as after a wall jump, so a held direction doesn't cancel the launch.
@export var rope_release_lock_time: float = 0.2
# Ropes are ignored this long after letting go. Grab is usually still
# held, so otherwise the rope would be caught again straight away.
@export var rope_regrab_delay: float = 0.3

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
@export var wall_run_min_speed: float = 150.0

# Punch combo (Y). Works on the ground and in the air.
# A press this early still counts, so the cross can be pressed on the
# beat during the jab instead of waiting for a window to open. Mashing
# plays jab, cross, jab, cross at the animations' own pace.
@export var attack_buffer_time: float = 0.2

# Crouch, roll and slide all drop the body to crouch_height, which is
# under a tile, so a one-tile (16px) gap can be crawled, rolled or slid
# through. The crouch art is taller than that, so the head overlaps a
# low ceiling a little; the box is what has to fit, not the drawing.
# Standing up waits until there's room overhead.
@export var crouch_height: float = 14.0
# Down plus a direction crawls. Slow enough that a tunnel reads as a
# squeeze, not a shortcut.
@export var crawl_speed: float = 45.0
# Roll (A while crouched): a fixed burst in the held direction (facing if
# none). Speed x duration is the distance (~49px, about 3 tiles). The
# animation is stretched to last exactly roll_duration.
@export var roll_speed: float = 140.0
@export var roll_duration: float = 0.35
# Slide (A on the ground while moving): starts at slide_speed, or
# sprint_slide_speed at sprint pace, and bleeds off at slide_friction
# until slide_end_speed. 150px/s covers ~45px (about 3 tiles) and 180px/s
# ~67px (about 4), so a sprint carries the slide further.
@export var slide_speed: float = 150.0
@export var sprint_slide_speed: float = 180.0
@export var slide_friction: float = 240.0
@export var slide_end_speed: float = 30.0

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
# Settled on the press, like the direction: a sprint dash stays long even
# though the windup stops the body dead.
var dash_is_sprint: bool = false
# One ability per trip through the air, shared by the dash and the dive,
# so a dash can't chain into a dive or the other way round. Refilled on
# the ground or a wall (slide, climb or ledge hang).
var has_air_dash: bool = true

var windup_timer: float = 0.0
var windup_is_dive: bool = false
var glow_fade_timer: float = 0.0

var is_diving: bool = false
var dive_land_timer: float = 0.0
# Set on the one frame the recovery runs out, so the held crouch frame
# can be released into the rest of the land animation.
var dive_land_timer_just_ended: bool = false
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

var is_climbing: bool = false
var climb_side: int = 0
# Attached: holding onto a wall from the ground. Visual only for now;
# the planned push/pull ability (movable blocks) builds on this state.
var is_attached: bool = false
var attach_side: int = 0
var stamina: float = 0.0
# Whether the surface being climbed costs stamina. Off on a ladder, which
# also hides the low-stamina pulse there.
var climb_drains_stamina: bool = true

var is_crouching: bool = false
var roll_timer: float = 0.0
var roll_direction: float = 1.0
var is_sliding: bool = false

enum LedgeState { NONE, HANGING, CLIMBING }
var ledge_state: LedgeState = LedgeState.NONE
var ledge_side: int = 0
var ledge_corner: Vector2
var ledge_timer: float = 0.0
var ledge_regrab_timer: float = 0.0

# The rope being held, or null. swing_distance is how far down it the
# hands are, which is the length of the pendulum.
var swing_rope: SwingRope = null
var swing_distance: float = 0.0
# Off from the catch until the first left or right press, so grabbing a
# rope just hangs there; the swing is something the player starts.
var swing_started: bool = false
# A jump off a rope somersaults (air_spin, once through) before handing
# back to the usual jump and fall poses.
var is_air_spinning: bool = false
var rope_regrab_timer: float = 0.0

enum Attack { NONE, JAB, CROSS }
var attack: Attack = Attack.NONE
var attack_buffer_timer: float = 0.0

# Frame numbers from the punch sheets (re-check them if the art changes).
# Active: the fist is out and the hitbox is live. Chain: the jab is far
# enough through that the cross can follow. Recovery: the punch has
# landed, and moving or jumping cancels the rest of the pose.
const JAB_ACTIVE_FRAMES: Array[int] = [1, 2]
const JAB_CHAIN_FRAME := 3
const JAB_RECOVERY_FRAME := 6
const CROSS_ACTIVE_FRAMES: Array[int] = [1, 2]
const CROSS_RECOVERY_FRAME := 5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var jab_shape: CollisionShape2D = $PunchHitbox/Jab
@onready var cross_shape: CollisionShape2D = $PunchHitbox/Cross
# The hitbox shapes are laid out for facing right and mirrored from these.
@onready var jab_shape_x: float = jab_shape.position.x
@onready var cross_shape_x: float = cross_shape.position.x
# Crouch, roll and slide swap the body box for crouch_shape. The ledge
# probe and the standing-room check always use standing_shape.
@onready var standing_shape := body_shape.shape as RectangleShape2D
@onready var crouch_shape := RectangleShape2D.new()
# One pixel narrower than the body, so a wall the player is touching
# doesn't count as something in the way of standing up.
@onready var stand_probe_shape := RectangleShape2D.new()


func _ready() -> void:
	spawn_position = global_position
	fall_peak_y = global_position.y
	stamina = climb_stamina
	crouch_shape.size = Vector2(standing_shape.size.x, crouch_height)
	stand_probe_shape.size = standing_shape.size - Vector2(2.0, 0.0)
	$PunchHitbox.body_entered.connect(_on_punch_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	_update_tint(delta)

	# Ahead of the ledge states' early returns, so a hang resets it too.
	# A wall slide or climb breaks the fall, so sliding down a tall wall
	# isn't a hard landing.
	if (is_on_floor() or ledge_state != LedgeState.NONE or is_wall_sliding or is_climbing
			or is_wall_running or swing_rope != null):
		fall_peak_y = global_position.y
	else:
		fall_peak_y = minf(fall_peak_y, global_position.y)

	# Jump buffering: a press slightly before landing still counts,
	# instead of getting silently dropped.
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	ledge_regrab_timer -= delta
	if ledge_state == LedgeState.HANGING:
		_process_ledge_hang(direction, delta)
		return
	if ledge_state == LedgeState.CLIMBING:
		_process_ledge_climb(delta)
		return
	rope_regrab_timer -= delta
	if swing_rope != null:
		_process_swing(direction, delta)
		return

	# Coyote time: a short grace window after walking off a ledge
	# where a jump still counts, so near-misses feel fair.
	if is_on_floor():
		# Not while wall running: is_on_floor() is still true on the frame
		# after the run starts, and refilling coyote then would let a jump
		# up to coyote_time later fire as a ground jump from up the wall.
		if not is_wall_running:
			coyote_timer = coyote_time
		has_air_dash = true
		stamina = climb_stamina
		# Updated every grounded frame, so it's frozen at whatever it was
		# on takeoff. Needs actual sprint pace, not just the button: a
		# standing jump with it held shouldn't steer like a sprint.
		air_sprint = Input.is_action_pressed("sprint") and absf(velocity.x) > max_speed
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

	# One button for the whole family: a slide (or a roll from a crouch)
	# on the ground, a dash or dive in the air.
	dash_cooldown_timer -= delta
	if (Input.is_action_just_pressed("dash") and windup_timer <= 0.0 and not is_diving
			and dive_land_timer <= 0.0):
		var vertical := Input.get_axis("move_up", "crouch")
		if is_on_floor():
			_try_start_ground_move(direction, vertical > 0.0 or is_crouching)
		# Straight down is the dive. Down with a side held is still a dash.
		elif vertical > 0.0 and direction == 0.0:
			if can_dive and has_air_dash:
				_start_windup(true, direction)
		# The dash needs left or right held. Neutral or Up does nothing, so
		# the air dash is always an aimed choice and never spends itself in
		# whatever way the sprite happens to face.
		elif can_dash and dash_cooldown_timer <= 0.0 and has_air_dash and direction != 0.0:
			_start_windup(false, direction)

	# A jump during a dash cancels it rather than waiting it out. The
	# dash is longer than the jump buffer, so otherwise an early press
	# would expire mid-dash and feel eaten.
	if dash_timer > 0.0 and jump_buffer_timer > 0.0 and (coyote_timer > 0.0 or wall_coyote_timer > 0.0):
		_end_dash()

	if (not is_climbing and dash_timer <= 0.0 and windup_timer <= 0.0 and not is_diving
			and _can_start_climb(direction)):
		_start_climb()

	# Attach: a fresh grab press on the ground, facing a wall at the hands.
	# A fresh press only, so grab held while walking along a wall doesn't
	# stick the player to it. Any wall works, not just grip ones.
	if (not is_attached and not is_climbing and not is_crouching and roll_timer <= 0.0 and not is_sliding
			and is_on_floor() and Input.is_action_just_pressed("grab")
			and dash_timer <= 0.0 and windup_timer <= 0.0
			and dive_land_timer <= 0.0 and not (direction != 0.0 and signf(direction) != facing)
			and _is_wall_at_hands(int(facing))):
		_start_attach(int(facing))

	# Not while climbing or attached: the hands are busy, and a buffered
	# press would fire a punch the moment the player let go.
	if Input.is_action_just_pressed("attack") and not is_climbing and not is_attached:
		attack_buffer_timer = attack_buffer_time
	else:
		attack_buffer_timer -= delta
	_update_attack(direction)
	_update_crouch()

	if windup_timer > 0.0:
		windup_timer -= delta
		velocity = Vector2.ZERO
		if windup_timer <= 0.0:
			if windup_is_dive:
				_start_dive()
			else:
				_start_dash()
	elif dash_timer > 0.0:
		dash_timer -= delta
		velocity = Vector2(dash_direction * dash_speed, 0.0)
		if dash_timer <= 0.0:
			_end_dash()
	elif is_diving:
		velocity = Vector2(0.0, dive_speed)
	elif dive_land_timer > 0.0:
		dive_land_timer -= delta
		dive_land_timer_just_ended = dive_land_timer <= 0.0
		_apply_attack_movement(delta)
	elif roll_timer > 0.0:
		_apply_roll(direction, delta)
	elif is_sliding:
		_apply_slide(direction, delta)
	elif is_climbing:
		_apply_climb(direction, delta)
	elif is_attached:
		_apply_attach(direction, delta)
	elif attack != Attack.NONE and is_on_floor():
		_apply_attack_movement(delta)
	elif attack != Attack.NONE:
		_apply_air_attack_movement(direction, delta)
	else:
		_apply_movement(direction, wall_side, delta)

	# Floor state has to be read before move_and_slide() updates it,
	# otherwise there's no way to tell that we only just touched down.
	var was_on_floor := is_on_floor()
	# move_and_slide() zeroes velocity.x on the frame the body meets a
	# wall, so the speed it hit the wall at has to be read beforehand.
	var approach_speed := absf(velocity.x)
	move_and_slide()

	if is_diving and is_on_floor():
		is_diving = false
		dive_land_timer = dive_land_time
	elif (not was_on_floor and is_on_floor()
			and global_position.y - fall_peak_y >= hard_land_height):
		# An air punch would otherwise carry on as a grounded one under
		# the recovery pose.
		_end_attack()
		dive_land_timer = dive_land_time

	if _update_wall_run(direction, approach_speed):
		return

	# A dash ends early when it hits a wall, rather than pinning the
	# player against it for the rest of its duration.
	if dash_timer > 0.0 and get_real_velocity().length() < dash_speed * 0.1:
		_end_dash()

	# Like the ledge grab, a rope is only caught with grab held. Unlike it,
	# rising doesn't matter: jumping up to a rope is the usual way on.
	if (rope_regrab_timer <= 0.0 and not is_on_floor() and not is_diving and windup_timer <= 0.0
			and Input.is_action_pressed("grab") and _try_catch_rope()):
		return

	# Checked after moving so the ledge test uses this frame's position.
	# Only on the way down (or flat, mid-dash): grabbing while rising
	# would interrupt jumps that were already going to clear the ledge.
	# Climbing up is the exception - reaching the top of a wall hands off
	# to the ledge hang, and holding Up then mounts it. Catching needs
	# grab held, like the climb, so ledges only stop the player when
	# they ask to be stopped.
	# Never mid-dive or mid-windup, which commit the body until they end.
	if (can_ledge_grab and ledge_regrab_timer <= 0.0 and not is_on_floor() and not is_diving
			and windup_timer <= 0.0
			and Input.is_action_pressed("grab")
			and (velocity.y >= 0.0 or is_climbing or is_wall_running)
			and _try_grab_ledge(int(facing))):
		return

	_update_animation(direction, wall_side, was_on_floor)


func _apply_movement(direction: float, wall_side: int, delta: float) -> void:
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
		var target_speed := direction * _run_speed()
		var accel := acceleration if is_on_floor() else air_acceleration
		if direction != 0.0:
			velocity.x = move_toward(velocity.x, target_speed, accel * delta)
			facing = signf(direction)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# Walking into a MovableBlock shoves it. Not with sprint held: then it
	# acts as a wall, so a sprint into it wall runs up and mounts the top.
	if is_on_floor() and direction != 0.0 and not Input.is_action_pressed("sprint"):
		_push_block_ahead(int(signf(direction)), delta)

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
			_wall_jump(wall_run_side)
		elif coyote_timer > 0.0:
			velocity.y = jump_velocity
			_consume_jump()
		elif wall_coyote_timer > 0.0:
			_wall_jump(last_wall_side)

	# Variable jump height: releasing the button early cuts the
	# jump short, so tapping gives a hop and holding gives full height.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _wall_jump(side: int) -> void:
	# Every wall jump is a plain one, even out of a wall run with sprint
	# held. The jump off a wall run is for gaining height, not for
	# carrying the sprint into a long horizontal leap.
	air_sprint = false
	velocity = Vector2(-side * wall_jump_velocity.x, wall_jump_velocity.y)
	facing = -side
	wall_jump_lock_timer = wall_jump_lock_time
	is_wall_sliding = false
	is_wall_running = false
	_consume_jump()


# Celeste's grab rules: hold grab, face a wall, and not be rising - so a
# jump past a wall isn't snagged on the way up, but you catch at the
# apex. On the ground it also needs Up (pressed from an attach), otherwise
# holding grab while walking along a wall would stick you to it. The wall has to be level
# with the hands: with only the feet against it, the hands would be
# gripping empty air above the top (near the top, holding grab catches
# the ledge instead). Feet don't need to touch, so the lower half of a
# small floating block can be grabbed with the legs hanging below.
func _can_start_climb(direction: float) -> bool:
	if not can_climb or not Input.is_action_pressed("grab") or velocity.y < 0.0:
		return false
	var grip := _grip_at_hands(int(facing))
	# A free surface (a ladder) can be climbed even when worn out.
	if grip == null or (grip.drains_stamina and stamina <= 0.0):
		return false
	# Moving away from the wall means the player is leaving it.
	if direction != 0.0 and signf(direction) != facing:
		return false
	return not is_on_floor() or Input.is_action_pressed("move_up")


func _start_climb() -> void:
	is_climbing = true
	is_attached = false
	climb_side = int(facing)
	is_wall_sliding = false
	wall_jump_lock_timer = 0.0
	velocity = Vector2.ZERO


func _apply_climb(direction: float, delta: float) -> void:
	# The hands are all that has to stay on the wall, so the player can
	# climb down until hanging from the bottom edge by their arms.
	var grip := _grip_at_hands(climb_side)
	if not Input.is_action_pressed("grab") or grip == null:
		# Let go, or the hands left the grip: climbed down past its
		# bottom (of the wall or of the GripSurface), or up past a top
		# with no room to stand (where there is room, the ledge grab
		# takes over first).
		is_climbing = false
		_apply_movement(direction, 0, delta)
		return
	# Standing on the ground with no Up held: back to walking, or to an
	# attach if grab is still held and the wall is still at the hands.
	if is_on_floor() and not Input.is_action_pressed("move_up"):
		is_climbing = false
		if Input.is_action_pressed("grab") and _is_wall_at_hands(climb_side):
			_start_attach(climb_side)
			_apply_attach(direction, delta)
		else:
			_apply_movement(direction, 0, delta)
		return

	if jump_buffer_timer > 0.0:
		# Every jump off a climb is a wall jump. Celeste's straight-up
		# climb jump is left out on purpose: spamming it up a wall is a
		# rhythm-breaker, and climbing should be a steady, deliberate pace.
		is_climbing = false
		_wall_jump(climb_side)
		return

	# Read every frame, so a climb that crosses from a free surface onto
	# a draining one (or back) switches over as the hands do.
	climb_drains_stamina = grip.drains_stamina
	var drain := 1.0 if climb_drains_stamina else 0.0
	var vertical := Input.get_axis("move_up", "crouch")
	if vertical < 0.0:
		velocity.y = -climb_up_speed
		stamina -= drain * delta
	elif vertical > 0.0:
		# Sliding down is free, so a tired player can still back off.
		velocity.y = climb_down_speed
	else:
		velocity.y = 0.0
		stamina -= drain * climb_hold_drain * delta
	# A small push into the wall keeps move_and_slide() in contact with it.
	velocity.x = climb_side * 10.0

	if climb_drains_stamina and stamina <= 0.0:
		stamina = 0.0
		is_climbing = false


func _start_attach(side: int) -> void:
	is_attached = true
	attach_side = side
	facing = side


# Facing locked to the wall, whatever the d-pad says. Against a plain
# wall toward and away only change the pose (push and pull) and the feet
# stay planted; against a MovableBlock they move the block and the player
# together. Letting go, a jump, or the wall or floor disappearing ends it.
func _apply_attach(direction: float, delta: float) -> void:
	var held := _wall_at(attach_side, _hands_y())
	if (not Input.is_action_pressed("grab") or not is_on_floor() or jump_buffer_timer > 0.0
			or held == null):
		is_attached = false
		_apply_movement(direction, 0, delta)
		return
	_apply_attack_movement(delta)
	var block := held as MovableBlock
	if block == null or direction == 0.0:
		return
	var dx := signf(direction) * push_speed * delta
	# A pull walks the player backwards, so it stops at whatever is
	# behind them rather than dragging the block into their body.
	if signf(direction) == -attach_side and test_move(global_transform, Vector2(dx, 0.0)):
		return
	# The block moves first and the player follows exactly as far as it
	# went, so the hands stay on it even when it jams against a wall.
	velocity.x = block.slide(dx, self) / delta


# Walking into a MovableBlock pushes it at push_speed, the same as an
# attach push. Velocity is set outright rather than accelerated, because
# move_and_slide() zeroes it against the block every frame, and building
# up from zero each time left the push crawling. Any gap left from the
# approach (the probe reaches a little ahead) closes on the first frame.
func _push_block_ahead(side: int, delta: float) -> void:
	var hit := _wall_hit(side, _hands_y())
	var block := hit.get("collider") as MovableBlock
	if block == null:
		return
	var half_width: float = (body_shape.shape as RectangleShape2D).size.x * 0.5
	var gap := maxf(absf(hit.position.x - global_position.x) - half_width, 0.0)
	velocity.x = (side * gap + block.slide(side * push_speed * delta, self)) / delta


# A on the ground. Crouched (or pressing Down) it rolls; otherwise it
# slides, but only on the move, so A from a standstill does nothing
# rather than sliding nowhere. Sprint pace (not just the button) starts
# the slide faster, so it carries further. The caller has already checked
# the press.
func _try_start_ground_move(direction: float, crouched: bool) -> void:
	if (roll_timer > 0.0 or is_sliding or is_climbing or is_attached or attack != Attack.NONE
			or dash_timer > 0.0):
		return
	var sprinting := Input.is_action_pressed("sprint") and absf(velocity.x) > max_speed
	if not crouched:
		# A direction pressed on the same frame as A counts as moving: the
		# body hasn't picked up speed yet, but the intent is clear.
		var moving := direction != 0.0 or absf(velocity.x) > run_anim_threshold
		if not moving:
			return
		is_sliding = true
		facing = signf(direction) if direction != 0.0 else signf(velocity.x)
		velocity.x = facing * (sprint_slide_speed if sprinting else slide_speed)
		return
	roll_direction = signf(direction) if direction != 0.0 else facing
	facing = roll_direction
	roll_timer = roll_duration
	# Started here rather than in _update_animation(), so a roll straight
	# after a roll restarts the sheet instead of holding its last frame.
	var frames := sprite.sprite_frames
	var anim_length := frames.get_frame_count(&"roll") / frames.get_animation_speed(&"roll")
	sprite.flip_h = roll_direction < 0.0
	sprite.play(&"roll", anim_length / roll_duration)


# Committed for its length: no steering, but a jump cancels it (a press
# shouldn't be eaten mid-roll), and running off an edge ends it so the
# body falls rather than rolling on through the air.
func _apply_roll(direction: float, delta: float) -> void:
	roll_timer -= delta
	if not is_on_floor() or (jump_buffer_timer > 0.0 and coyote_timer > 0.0):
		roll_timer = 0.0
		_apply_movement(direction, 0, delta)
		return
	velocity.x = roll_direction * roll_speed
	velocity.y = minf(velocity.y + gravity * fall_gravity_multiplier * delta, max_fall_speed)


# Bleeds the sprint off under its own friction, then hands back to a
# crouch (or standing, if Down isn't held and there's room). A jump
# cancels it into a jump that keeps the speed; leaving the ground or
# hitting a wall ends it.
func _apply_slide(direction: float, delta: float) -> void:
	if (not is_on_floor() or absf(velocity.x) < slide_end_speed
			or (jump_buffer_timer > 0.0 and coyote_timer > 0.0)):
		is_sliding = false
		_apply_movement(direction, 0, delta)
		return
	velocity.x = move_toward(velocity.x, 0.0, slide_friction * delta)
	velocity.y = minf(velocity.y + gravity * fall_gravity_multiplier * delta, max_fall_speed)


# Crouching is plain movement with Down held on the ground. Anything
# else that owns the body (a punch, climb, attach, dash) leaves it alone.
# Wherever there's no room to stand, the body stays low whatever the
# state, and on the ground that means crouching: let go of Down in a
# tunnel and the player keeps crawling until they're out.
func _update_crouch() -> void:
	var free := (not is_climbing and not is_attached and attack == Attack.NONE and dash_timer <= 0.0
			and windup_timer <= 0.0 and not is_diving and dive_land_timer <= 0.0
			and roll_timer <= 0.0 and not is_sliding)
	var trapped := _is_low() and not _can_stand()
	is_crouching = free and is_on_floor() and (Input.is_action_pressed("crouch") or trapped)
	_set_low(is_crouching or roll_timer > 0.0 or is_sliding or trapped)


func _is_low() -> bool:
	return body_shape.shape == crouch_shape


# The box keeps its bottom edge at the feet (the origin) whichever
# height it is, so changing height never lifts or sinks the player.
func _set_low(low: bool) -> void:
	var shape := crouch_shape if low else standing_shape
	if body_shape.shape == shape:
		return
	body_shape.shape = shape
	body_shape.position.y = -shape.size.y * 0.5


# Whether the standing box fits here. Lifted 1px so the floor under the
# feet doesn't count.
func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = stand_probe_shape
	query.transform = Transform2D(0.0, global_position + Vector2(0.0, -standing_shape.size.y * 0.5 - 1.0))
	query.collision_mask = collision_mask
	var exclude: Array[RID] = [get_rid()]
	query.exclude = exclude
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


# The ability windup brightens in one smooth ramp. The soft red pulse
# while climbing on low stamina is a tint fade rather than a hard flash,
# slower than 3 per second. Both stay well clear of photosensitivity
# limits.
func _update_tint(delta: float) -> void:
	if windup_timer > 0.0:
		var charge := 1.0 - windup_timer / ability_windup_time
		sprite.modulate = Color.WHITE.lerp(ability_windup_glow, charge)
	elif dash_timer > 0.0 or is_diving:
		# Holds at full glow for the move itself, so the whole ability
		# reads as one burst of magic rather than a charge then a plain dash.
		sprite.modulate = ability_windup_glow
		glow_fade_timer = ability_glow_fade_time
	elif is_climbing and climb_drains_stamina and stamina < climb_tired_threshold:
		# Ahead of the spent-dash glow below: running out of stamina drops
		# the player, so that warning matters more than the dash state.
		var pulse := (sin(Time.get_ticks_msec() / 1000.0 * TAU * 2.0) + 1.0) * 0.5
		sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.35, 0.35), pulse)
	elif not has_air_dash and not is_on_floor():
		# The glow stays on after an air dash until it's refilled, so the
		# player can see at a glance that it's spent. Walls and ledges
		# don't refill it, which makes that worth showing. It fades on landing.
		sprite.modulate = ability_windup_glow
		glow_fade_timer = ability_glow_fade_time
	elif glow_fade_timer > 0.0:
		glow_fade_timer -= delta
		var fade := maxf(glow_fade_timer, 0.0) / ability_glow_fade_time
		sprite.modulate = Color.WHITE.lerp(ability_windup_glow, fade)
	else:
		sprite.modulate = Color.WHITE


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
		if side != -wall_run_side and _try_mount_ledge(wall_run_side):
			return true
		# Toward only has to be held to start the run. After that it's
		# the sprint button that keeps it going, so the d-pad is free to
		# line up the jump off. Ends at the top of the run, or early on
		# letting go of sprint, grabbing, bumping a ceiling, or the hands
		# passing the top of a wall with no room to stand on it.
		if (velocity.y >= 0.0 or is_climbing or not Input.is_action_pressed("sprint")
				or not _is_wall_at_hands(wall_run_side)):
			is_wall_running = false
		return false
	# Only from standing height: a slide into a wall would otherwise read
	# the hand probe from the crouch box's top.
	if (can_wall_run and is_on_floor() and side != 0 and Input.is_action_pressed("sprint")
			and not _is_low() and approach_speed >= wall_run_min_speed and _is_wall_at_hands(side)):
		is_wall_running = true
		wall_run_side = side
		velocity.y = -wall_run_speed
		# Without this the ground coyote window would turn a jump in the
		# first few frames into a plain jump. Off a wall it should push
		# away, like any other jump off a wall.
		coyote_timer = 0.0
	return false


func _update_attack(direction: float) -> void:
	if attack == Attack.NONE:
		if (attack_buffer_timer > 0.0 and not is_climbing and not is_attached and not is_wall_running and dash_timer <= 0.0
				and windup_timer <= 0.0 and not is_diving and dive_land_timer <= 0.0
				and not is_crouching and roll_timer <= 0.0 and not is_sliding):
			# In the air every press is a cross. There's no combo to build up
			# mid-jump, so it goes straight to the big swing.
			_start_attack(Attack.JAB if is_on_floor() else Attack.CROSS, direction)
		return
	# Anything that takes the body somewhere else ends the punch. Leaving
	# the ground or landing doesn't: an air punch carries on into a
	# grounded one (and plants the feet), and a punch thrown at a ledge's
	# edge keeps swinging as the player drops off it.
	if is_climbing or is_attached or is_wall_running or dash_timer > 0.0:
		_end_attack()
		return

	var frame := sprite.frame
	if attack == Attack.JAB and attack_buffer_timer > 0.0 and frame >= JAB_CHAIN_FRAME:
		_start_attack(Attack.CROSS, direction)
		return
	# Up to the recovery frame the punch is committed. After it, moving or
	# jumping hands straight back to movement, so the guard pose at the
	# end of each sheet never holds the player in place.
	var recovery := JAB_RECOVERY_FRAME if attack == Attack.JAB else CROSS_RECOVERY_FRAME
	if not sprite.is_playing() or (frame >= recovery and (direction != 0.0 or jump_buffer_timer > 0.0)):
		_end_attack()
		return

	var active := JAB_ACTIVE_FRAMES if attack == Attack.JAB else CROSS_ACTIVE_FRAMES
	_set_punch_hitbox(attack if frame in active else Attack.NONE)


func _start_attack(kind: Attack, direction: float) -> void:
	attack = kind
	attack_buffer_timer = 0.0
	# Holding a direction turns before each punch, so the cross can be
	# thrown the other way at something behind.
	if direction != 0.0:
		facing = signf(direction)
	sprite.speed_scale = 1.0
	sprite.flip_h = facing < 0.0
	# Played directly rather than through _play(), which won't restart an
	# animation that's already showing (a jab straight after a jab).
	sprite.play(&"jab" if kind == Attack.JAB else &"cross")
	_set_punch_hitbox(Attack.NONE)


func _end_attack() -> void:
	attack = Attack.NONE
	_set_punch_hitbox(Attack.NONE)


# Feet planted while punching: the run skids to a stop under friction
# rather than halting dead, and gravity keeps the body on slopes and steps.
func _apply_attack_movement(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	velocity.y = minf(velocity.y + gravity * fall_gravity_multiplier * delta, max_fall_speed)


# In the air the punch doesn't stop the body: the jump arc carries on
# and the player can still steer, so a punch never hangs them in place
# the way a mid-air stop would. Facing is locked to the swing (it only
# turns between punches), and wall slides and wall jumps wait for the
# punch to end, so the swing reads as one committed action.
func _apply_air_attack_movement(direction: float, delta: float) -> void:
	# A punch straight out of a wall jump still honours the push-off, or
	# held toward the wall would steer the player straight back onto it.
	if wall_jump_lock_timer > 0.0:
		wall_jump_lock_timer -= delta
	else:
		velocity.x = move_toward(velocity.x, direction * _run_speed(), air_acceleration * delta)
	var fall := gravity if velocity.y < 0.0 else gravity * fall_gravity_multiplier
	velocity.y = minf(velocity.y + fall * delta, max_fall_speed)
	# A jump released early is still cut short, even if a punch started
	# partway up it.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _set_punch_hitbox(kind: Attack) -> void:
	jab_shape.disabled = kind != Attack.JAB
	cross_shape.disabled = kind != Attack.CROSS
	jab_shape.position.x = jab_shape_x * facing
	cross_shape.position.x = cross_shape_x * facing


func _on_punch_hitbox_body_entered(body: Node2D) -> void:
	punch_landed.emit(body, 1 if attack == Attack.JAB else 2)


func _run_speed() -> float:
	if is_crouching:
		return crawl_speed
	var sprinting := Input.is_action_pressed("sprint") and (is_on_floor() or air_sprint)
	return max_speed * (sprint_multiplier if sprinting else 1.0)


func _consume_jump() -> void:
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	wall_coyote_timer = 0.0


# The direction, cooldown and air dash are all settled on the press, not
# when the windup ends: the windup clears the wall states the direction
# depends on, and a second press mid-windup shouldn't queue another.
func _start_windup(dive: bool, direction: float) -> void:
	windup_is_dive = dive
	windup_timer = ability_windup_time
	if not dive:
		dash_direction = _dash_direction(direction)
		facing = dash_direction
		dash_cooldown_timer = dash_cooldown
		# The dash is air-only, so a sprint dash needs a sprinting takeoff
		# (air_sprint) with the button still held.
		dash_is_sprint = Input.is_action_pressed("sprint") and air_sprint
	has_air_dash = false
	# Hangs in place, cutting off whatever the body was doing. A dive
	# pressed mid-dash cancels the dash here.
	dash_timer = 0.0
	is_climbing = false
	is_wall_sliding = false
	is_wall_running = false
	wall_jump_lock_timer = 0.0
	roll_timer = 0.0
	is_sliding = false
	_end_attack()
	velocity = Vector2.ZERO


func _dash_direction(direction: float) -> float:
	var dir := signf(direction)
	if dir == 0.0:
		dir = facing
	# Off a wall the held direction points into it, which would end the
	# dash on its first frame. Flip it away from the wall instead.
	var wall := 0
	if is_wall_sliding:
		wall = last_wall_side
	elif is_climbing:
		wall = climb_side
	elif is_wall_running:
		wall = wall_run_side
	if wall != 0 and dir == wall:
		dir = -wall
	return dir


func _start_dash() -> void:
	dash_timer = sprint_dash_duration if dash_is_sprint else dash_duration
	velocity = Vector2(dash_direction * dash_speed, 0.0)


# A commitment straight down, with no steering until it lands.
func _start_dive() -> void:
	is_diving = true
	air_sprint = false
	velocity = Vector2(0.0, dive_speed)


func _end_dash() -> void:
	dash_timer = 0.0
	# Hand back at run speed rather than dash speed, so the player
	# doesn't skate on after the dash visibly ends. Still holding sprint
	# hands back at sprint speed, so there's no dip before the sprint.
	velocity = Vector2(dash_direction * _run_speed(), 0.0)


func _try_grab_ledge(side: int) -> bool:
	var corner: Variant = _find_ledge(side)
	if corner == null:
		return false
	_snap_to_ledge(side, corner)
	_play("ledge_hang")
	return true


# Straight from wherever the body is into the ledge climb, no hang.
func _try_mount_ledge(side: int) -> bool:
	var corner: Variant = _find_ledge(side)
	if corner == null:
		return false
	_snap_to_ledge(side, corner)
	_start_ledge_climb()
	return true


# Looks for a ledge on `side` near hand height with three physics probes
# rather than reading tiles, so it works on any collision shape - tiles,
# moving platforms, whatever comes later. Returns the ledge corner, or
# null if there's no ledge there that the player could stand on.
func _find_ledge(side: int) -> Variant:
	var space := get_world_2d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	var hands_y := global_position.y + ledge_hand_offset.y
	# Just below the lowest ledge top we'd accept, so it hits wall face.
	var probe_y := hands_y + ledge_snap_range + 1.0

	# 1. A wall face in front of the body.
	var wall_ray := PhysicsRayQueryParameters2D.create(
			Vector2(global_position.x, probe_y),
			Vector2(global_position.x + side * (ledge_hand_offset.x + ledge_reach), probe_y),
			collision_mask, exclude)
	var wall_hit := space.intersect_ray(wall_ray)
	if wall_hit.is_empty() or absf(wall_hit.normal.x) < 0.7:
		return null
	var wall_x: float = wall_hit.position.x

	# 2. A top surface near hand height, just inside the wall. If this
	# ray starts inside solid, the wall continues upward - not a ledge -
	# and the ray reports nothing.
	var probe_x := wall_x + side * 2.0
	var top_ray := PhysicsRayQueryParameters2D.create(
			Vector2(probe_x, hands_y - ledge_snap_range),
			Vector2(probe_x, probe_y),
			collision_mask, exclude)
	var top_hit := space.intersect_ray(top_ray)
	if top_hit.is_empty() or top_hit.normal.y > -0.7:
		return null
	var corner := Vector2(wall_x, top_hit.position.y)

	# 3. Room to stand on top, so the climb can't end inside a ceiling.
	# Lifted 1px so resting on the ledge's own surface doesn't count.
	var stand_query := PhysicsShapeQueryParameters2D.new()
	stand_query.shape = standing_shape
	stand_query.transform = Transform2D(0.0,
			corner + Vector2(side * ledge_stand_inset, -1.0 - standing_shape.size.y * 0.5))
	stand_query.collision_mask = collision_mask
	stand_query.exclude = exclude
	if not space.intersect_shape(stand_query, 1).is_empty():
		return null
	return corner


# Puts the body in the hang pose on the ledge at `corner`.
func _snap_to_ledge(side: int, corner: Vector2) -> void:
	ledge_state = LedgeState.HANGING
	ledge_side = side
	ledge_corner = corner
	ledge_timer = 0.0
	global_position = corner - Vector2(side * ledge_hand_offset.x, ledge_hand_offset.y)
	velocity = Vector2.ZERO
	dash_timer = 0.0
	is_wall_sliding = false
	is_wall_running = false
	is_climbing = false
	# The hang skips the rest of _physics_process, so a punch thrown
	# into the ledge would otherwise never get cleaned up.
	_end_attack()
	# The ledge sheet is drawn holding a ledge on the right.
	sprite.flip_h = side < 0


func _process_ledge_hang(direction: float, delta: float) -> void:
	ledge_timer += delta
	velocity = Vector2.ZERO
	var away := direction != 0.0 and signf(direction) != ledge_side

	# Releasing grab lets go, the same as on a climb.
	if away or Input.is_action_pressed("crouch") or not Input.is_action_pressed("grab"):
		# A jump pressed while hanging is discarded on the way down,
		# otherwise it would fire as a wall jump the moment we let go.
		jump_buffer_timer = 0.0
		_release_ledge()
		_play("fall")
	# Up or a fresh jump press mounts, never toward the wall. Toward is
	# usually already held when the grab happens, so it would mount
	# instantly. Jump uses the buffer (a press, not a hold) so a jump
	# held from before the catch doesn't mount on its own; a press
	# during the catch window is kept until the window ends.
	elif ledge_timer >= ledge_catch_time and (Input.is_action_pressed("move_up") or jump_buffer_timer > 0.0):
		jump_buffer_timer = 0.0
		_start_ledge_climb()


func _release_ledge() -> void:
	ledge_state = LedgeState.NONE
	ledge_regrab_timer = ledge_regrab_delay


func _start_ledge_climb() -> void:
	ledge_state = LedgeState.CLIMBING
	ledge_timer = 0.0
	# The climb art is drawn in place and the body is moved in code, so
	# the animation is stretched to last exactly as long as the movement.
	var frames := sprite.sprite_frames
	var anim_length := frames.get_frame_count(&"ledge_climb") / frames.get_animation_speed(&"ledge_climb")
	# speed_scale multiplies on top of that stretch, and nothing else resets
	# it here: _update_animation() doesn't run during a ledge climb. Left at
	# the wall run's sped-up value, the poses would finish early and freeze
	# on the last frame while the body was still mid-climb.
	sprite.speed_scale = 1.0
	sprite.play(&"ledge_climb", anim_length / ledge_climb_time)


# Where the feet are, relative to the ledge corner, at the start of each
# climb frame (for a ledge on the right). Measured from the climb sheet:
# the climb art is drawn in place, so the body has to follow the poses
# or the character floats beside the ledge mid-climb. The pull frame
# rises until the knee-up foot is planted on the ledge top, the step
# frame pushes up onto it, and the crouch walks in to the stand point.
# Re-measure these if the climb art changes.
const CLIMB_KEYS: Array[Vector2] = [
	Vector2(-6.0, 28.0), # hang (matches ledge_hand_offset)
	Vector2(-6.0, 8.0), # knee up: foot on the ledge top
	Vector2(-6.0, 8.0), # step: weight on that foot
	Vector2(-2.0, 0.0), # crouch: up on top, still at the edge
]


func _process_ledge_climb(delta: float) -> void:
	ledge_timer += delta
	var t := minf(ledge_timer / ledge_climb_time, 1.0)
	# One segment per climb frame, so position and pose stay in step.
	var keys := CLIMB_KEYS.duplicate()
	keys.append(Vector2(ledge_stand_inset, 0.0))
	var segments := keys.size() - 1
	var i := mini(int(t * segments), segments - 1)
	var local: Vector2 = keys[i].lerp(keys[i + 1], t * segments - i)
	# The body is placed directly rather than moved with move_and_slide:
	# the path hugs the wall and corner, where collision would snag it.
	global_position = ledge_corner + Vector2(local.x * ledge_side, local.y)
	if t >= 1.0:
		ledge_state = LedgeState.NONE
		velocity = Vector2.ZERO


# Which side a wall is on (-1 left, 1 right, 0 none). test_move probes
# without moving, so it finds walls the player is near but not pushing
# into - needed for wall jumps while drifting away from the wall. The
# normal check stops a ceiling or floor corner counting as a wall.
# Where the hands are relative to the feet: the hang pose's, since the
# swing borrows the ledge hang art (drawn holding on to the right).
func _rope_hand_offset() -> Vector2:
	return Vector2(facing * ledge_hand_offset.x, ledge_hand_offset.y)


func _try_catch_rope() -> bool:
	var hands := global_position + _rope_hand_offset()
	var box := RectangleShape2D.new()
	box.size = rope_catch_size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = box
	query.transform = Transform2D(0.0, hands)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = rope_mask
	var hits := get_world_2d().direct_space_state.intersect_shape(query, 1)
	if hits.is_empty():
		return false
	var rope := hits[0].collider as SwingRope
	if rope == null:
		return false

	swing_rope = rope
	rope.held = true
	swing_distance = clampf((hands - rope.global_position).dot(rope.direction()), rope_min_hold, rope.length)
	# The catch stops the rope where it is, even if it was still swinging
	# or the player arrived with speed. Swinging starts on a press.
	rope.set_swing(rope.angle, 0.0)
	swing_started = false
	# Catching a rope hands the air dash back, so routes can chain dash,
	# rope, dash.
	has_air_dash = true
	# The jump that reached the rope is still in the buffer, and would
	# otherwise fire as a jump off it on the first swing frame.
	jump_buffer_timer = 0.0
	velocity = Vector2.ZERO
	dash_timer = 0.0
	wall_jump_lock_timer = 0.0
	is_wall_sliding = false
	is_wall_running = false
	is_climbing = false
	# The swing skips the rest of _physics_process, so a punch thrown into
	# the rope would otherwise never get cleaned up.
	_end_attack()
	_follow_rope()
	_update_swing_animation(0.0, 0.0)
	return true


# The direction the hands move as the swing angle grows (to the right at
# the bottom of the arc).
func _rope_tangent() -> Vector2:
	var along := swing_rope.direction()
	return Vector2(along.y, -along.x)


func _process_swing(direction: float, delta: float) -> void:
	var rope := swing_rope
	if not Input.is_action_pressed("grab"):
		_release_rope(false)
		return
	if jump_buffer_timer > 0.0:
		_release_rope(true)
		return

	# Moving the hands keeps the angular momentum, so climbing up mid-swing
	# speeds it up and sliding down slows it, the way a real swing does.
	var w := rope.angular_velocity
	var vertical := Input.get_axis("move_up", "crouch")
	var new_distance := clampf(swing_distance + vertical * rope_climb_speed * delta, rope_min_hold, rope.length)
	var climbed := new_distance - swing_distance
	w *= pow(swing_distance / new_distance, 2.0)
	swing_distance = new_distance
	_update_swing_animation(direction, climbed)

	var a := rope.angle
	if direction != 0.0:
		swing_started = true
	if not swing_started:
		# Held still, gravity and all, until the player starts the swing.
		_follow_rope()
		return
	w += -gravity / swing_distance * sin(a) * delta
	# Pumping only works with the swing, never against it (from rest any
	# direction starts it), and stops adding once the swing is at full
	# height. Height comes from the swing's energy rather than its current
	# angle, so a pump at the bottom knows how high the swing will go.
	var pumping := direction != 0.0 and (signf(direction) == signf(w) or absf(w) < 0.05)
	var reach := clampf(cos(a) - w * w * swing_distance / (2.0 * gravity), -1.0, 1.0)
	if pumping and acos(reach) < deg_to_rad(rope_max_angle):
		w += signf(direction) * rope_pump_accel / swing_distance * delta
	w *= maxf(1.0 - rope_damping * delta, 0.0)
	rope.set_swing(a + w * delta, w)

	# Hitting a wall or ceiling stops the swing dead, still holding on.
	if not _follow_rope():
		rope.set_swing(a, 0.0)


# The climb sheet while just holding on (cycling as the hands move along
# the rope, frozen otherwise, as on a wall), and the hang pose while left
# or right is held, so pumping reads as a reach into the swing. Both are
# drawn holding on to the right. `climbed` is how far down the rope the
# hands moved this frame.
func _update_swing_animation(direction: float, climbed: float) -> void:
	sprite.speed_scale = 1.0
	sprite.flip_h = facing < 0.0
	if direction != 0.0:
		_play("ledge_hang")
		return
	if sprite.animation != "climb":
		sprite.play("climb")
	if climbed < 0.0:
		sprite.play("climb")
	elif climbed > 0.0:
		sprite.play_backwards("climb")
	else:
		sprite.pause()


# Moves the body so the hands sit on the rope. False if something solid
# got in the way first.
func _follow_rope() -> bool:
	var hands := swing_rope.global_position + swing_rope.direction() * swing_distance
	return move_and_collide(hands - _rope_hand_offset() - global_position) == null


# Lets go with the swing's speed. A jump adds lift and briefly locks air
# steering so the launch carries; a plain release just drops.
func _release_rope(jump: bool) -> void:
	velocity = _rope_tangent() * swing_rope.angular_velocity * swing_distance
	if jump:
		# At least the boost upward, so a jump on the downswing still rises.
		velocity.y = minf(velocity.y, 0.0) + rope_jump_boost
		wall_jump_lock_timer = rope_release_lock_time
		if velocity.x != 0.0:
			facing = signf(velocity.x)
		_consume_jump()
		is_air_spinning = true
		sprite.speed_scale = 1.0
		sprite.flip_h = facing < 0.0
		sprite.play(&"air_spin")
	swing_rope.held = false
	swing_rope = null
	rope_regrab_timer = rope_regrab_delay
	air_sprint = false


func _wall_side() -> int:
	for side: int in [1, -1]:
		if _is_wall(side):
			return side
	return 0


# True only when wall covers both head and feet (and, with `below`, runs
# on past the feet that far). _is_wall() counts any contact, so feet
# clipping the top corner of a block would start a slide while the body
# is still in the air above it.
func _is_wall_full_height(side: int, below: float = 0.0) -> bool:
	return _is_wall_at_hands(side) and _is_wall_at(side, global_position.y - 1.0 + below)


# True when the wall is level with the hands (the top of the body).
func _is_wall_at_hands(side: int) -> bool:
	return _is_wall_at(side, _hands_y())


func _hands_y() -> float:
	var size: Vector2 = (body_shape.shape as RectangleShape2D).size
	var top := global_position.y + body_shape.position.y - size.y * 0.5
	# Inset 1px from the top edge (and the feet ray from the bottom edge)
	# so a ray lying exactly on a tile seam doesn't count.
	return top + 1.0


func _is_grip_at_hands(side: int) -> bool:
	return _grip_at_hands(side) != null


# The GripSurface on a wall at the hands, or null if there isn't one.
# The point sits where the hand ray ends, just inside the wall face.
func _grip_at_hands(side: int) -> GripSurface:
	if not _is_wall_at_hands(side):
		return null
	var size: Vector2 = (body_shape.shape as RectangleShape2D).size
	var query := PhysicsPointQueryParameters2D.new()
	query.position = Vector2(global_position.x + side * (size.x * 0.5 + wall_check_distance),
			global_position.y + body_shape.position.y - size.y * 0.5 + 1.0)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = grip_mask
	var hits := get_world_2d().direct_space_state.intersect_point(query, 1)
	return null if hits.is_empty() else hits[0].collider as GripSurface


func _is_wall_at(side: int, y: float) -> bool:
	return _wall_at(side, y) != null


# Whatever solid body is within reach on `side` at height `y`, or null.
func _wall_at(side: int, y: float) -> Object:
	return _wall_hit(side, y).get("collider")


# The ray hit behind _wall_at(), for when the contact point matters too.
# Empty if nothing is in reach.
func _wall_hit(side: int, y: float) -> Dictionary:
	var size: Vector2 = (body_shape.shape as RectangleShape2D).size
	var ray := PhysicsRayQueryParameters2D.create(
			Vector2(global_position.x, y),
			Vector2(global_position.x + side * (size.x * 0.5 + wall_check_distance), y),
			collision_mask, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(ray)


func _is_wall(side: int) -> bool:
	var collision := KinematicCollision2D.new()
	if test_move(global_transform, Vector2(side * wall_check_distance, 0.0), collision):
		return absf(collision.get_normal().x) > 0.7
	return false


func _update_animation(direction: float, wall_side: int, was_on_floor: bool) -> void:
	# Only the run cycle speeds up with a sprint; everything else plays
	# at its authored rate.
	sprite.speed_scale = 1.0
	# Frozen on whatever frame was showing. speed_scale rather than
	# pause(), so the move's own animation still starts cleanly after.
	if windup_timer > 0.0:
		sprite.flip_h = facing < 0.0
		sprite.speed_scale = 0.0
		return
	if dash_timer > 0.0:
		sprite.flip_h = dash_direction < 0.0
		_play("dash")
		return

	# No dive art in the pack yet, so it borrows the fall pose. The
	# landing recovery holds land's deepest crouch (frame 0) for the whole
	# of dive_land_time to sell the impact, then stands up through the
	# rest of the sheet like a normal landing.
	if is_diving:
		sprite.flip_h = facing < 0.0
		_play("fall")
		return
	if dive_land_timer > 0.0:
		sprite.flip_h = facing < 0.0
		_play("land")
		sprite.frame = 0
		sprite.pause()
		return
	if dive_land_timer_just_ended:
		dive_land_timer_just_ended = false
		# play() resumes a paused animation where it stopped, so this
		# carries on from the crouch frame. The usual landing rule below
		# then lets any movement cancel the stand-up.
		sprite.play("land")

	# The punch plays itself out from _start_attack(); just hold it here.
	if attack != Attack.NONE:
		return
	# Likewise the roll, from _try_start_ground_move().
	if roll_timer > 0.0:
		return
	if is_sliding:
		sprite.flip_h = velocity.x < 0.0
		_play("slide")
		return

	if is_climbing:
		# The climb sheet is drawn against a wall on the right. The cycle
		# runs forward going up, backward sliding down, and holds its
		# frame while clinging, so the limbs only move when the body does.
		sprite.flip_h = climb_side < 0
		if sprite.animation != "climb":
			sprite.play("climb")
		if velocity.y < 0.0:
			sprite.play("climb")
		elif velocity.y > 0.0:
			sprite.play_backwards("climb")
		else:
			sprite.pause()
		return

	if is_wall_running:
		# Borrows the climb cycle, sped up so the limbs keep pace with
		# the body the way the sprint does with the run cycle.
		sprite.flip_h = wall_run_side < 0
		sprite.play("climb")
		sprite.speed_scale = maxf(1.0, -velocity.y / climb_up_speed)
		return

	if is_attached:
		# All three sheets are drawn holding on to the right, and their
		# AtlasTexture margins put the hands on the wall face.
		sprite.flip_h = attach_side < 0
		var pose := int(signf(direction))
		_play("push" if pose == attach_side else "pull" if pose == -attach_side else "push_idle")
		return

	if is_wall_sliding:
		# The wall sheets are drawn against a wall on the right. Straight
		# into the slide, with no wall_land lead-in: the impact pose
		# delayed the slide reading and made the wall feel sticky.
		sprite.flip_h = wall_side < 0
		_play("wall_slide")
		return

	# The rope jump's somersault plays through once in the air. Anything
	# above here that takes over the sprite (a wall slide, a dash, a
	# punch) cuts it off, and so does landing.
	if is_air_spinning:
		if not is_on_floor() and sprite.animation == &"air_spin" and sprite.is_playing():
			return
		is_air_spinning = false

	# Facing only changes on input, not velocity, so skidding to a stop
	# after reversing doesn't flicker the sprite back and forth.
	sprite.flip_h = facing < 0.0

	if not is_on_floor():
		_play("jump" if velocity.y < 0.0 else "fall")
		return

	# Ahead of the push and landing checks, so crawling into a wall or
	# landing with Down held goes straight into the crouch poses.
	if is_crouching:
		_play("crouch_walk" if absf(velocity.x) > run_anim_threshold else "crouch_idle")
		return

	# Running into a wall pushes against it instead. Without this the run
	# cycle stutters: move_and_slide() zeroes velocity on frames where it
	# registers the wall and not on others, so the speed check flickers.
	# The wall probe is used instead of is_on_wall(), which flickers too.
	if direction != 0.0 and _wall_side() == int(signf(direction)):
		_play("push")
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

	# Legs keep pace with the sprint so the feet don't skate.
	if moving:
		sprite.speed_scale = maxf(1.0, absf(velocity.x) / max_speed)
	_play("run" if moving else "idle")


# play() restarts a non-looping animation if called again with the same
# name, which would freeze jump/fall on their first frame. Guard it.
func _play(anim: StringName) -> void:
	if sprite.animation != anim:
		sprite.play(anim)


func respawn() -> void:
	global_position = spawn_position
	fall_peak_y = spawn_position.y
	velocity = Vector2.ZERO
	dash_timer = 0.0
	windup_timer = 0.0
	glow_fade_timer = 0.0
	is_diving = false
	dive_land_timer = 0.0
	dive_land_timer_just_ended = false
	wall_jump_lock_timer = 0.0
	is_wall_sliding = false
	is_wall_running = false
	is_attached = false
	is_crouching = false
	roll_timer = 0.0
	is_sliding = false
	_set_low(false)
	has_air_dash = true
	ledge_state = LedgeState.NONE
	is_climbing = false
	if swing_rope != null:
		swing_rope.held = false
		swing_rope = null
	is_air_spinning = false
	stamina = climb_stamina
	_end_attack()
