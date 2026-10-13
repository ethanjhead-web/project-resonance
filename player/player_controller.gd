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

# Vertical movement
@export var jump_velocity: float = -240.0
@export var gravity: float = 800.0
@export var fall_gravity_multiplier: float = 1.6
@export var max_fall_speed: float = 420.0
@export var jump_cut_multiplier: float = 0.45

# Forgiveness windows (in seconds)
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

# Charged jump: Down+jump on the ground crouches and gathers the jump for
# as long as jump is held, then fires it on release. Down only has to be
# held for the press. A tap is a normal full jump; the height then grows
# evenly with the hold, up to charged_jump_max_height times a normal jump
# at charged_jump_time. Firing on release means it can't be cut short.
@export var charged_jump_time: float = 1.6
# A release before this is a plain jump: normal height, and it doesn't
# spend an air ability, so a quick crouch-jump never costs the dash. The
# charge counts from here, still reaching full at charged_jump_time.
@export var charged_jump_min_time: float = 0.15
@export var charged_jump_max_height: float = 2.8
# Once the charge is full the glow keeps pulsing down toward this and
# back, so there's no need to count the hold. Dipping toward normal
# colour rather than up past the glow: the glow already saturates most
# of the sprite, so anything brighter barely shows. Each pulse is a
# smooth swell, and one every 0.5s keeps it to 2 a second, under the
# 3-flashes-a-second photosensitivity limit.
@export var charged_jump_flash_color: Color = Color.WHITE
@export var charged_jump_flash_period: float = 0.5

# Dash (A, in the air or on the move on the ground).
# Left or right only, from the held direction. Speed x duration is the distance (~45px, just under 3 tiles).
# Gravity is suspended for the whole dash so it reads as a committed,
# straight line rather than a hop.
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.15
# A dash out of a sprinting takeoff runs longer (~60px, nearly 4 tiles),
# so carrying momentum into it pays off. Same speed, so it reads as the same move.
@export var sprint_dash_duration: float = 0.2
# Counted from the end of the dash, not the press: the windup and dash
# outlast it, so counting from the press left no gap at all and ground
# dashes chained back to back. A real wait after each one makes the dash
# something to commit to rather than spam. The dash glow drains over
# exactly this long, so it doubles as the readiness indicator.
@export var dash_cooldown: float = 0.8
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
@export var dive_land_time: float = 1.6
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

# Slide slopes (SlideSlope triangles) are too slippery to stand on:
# landing on one slides the player down it at this constant speed, along
# the slope, whatever is held. Steady rather than gathering speed, so
# every slide off a slope launches the same way and routes can be timed.
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
@export var push_speed: float = 44.0

# Wall climb (Celeste-style: hold grab against a wall). The climb up is
# Celeste's speed, scaled by our run speed so the climb keeps the same
# relationship to running that it has there. Down is a slide, not a
# climb: wall_slide_speed with the frame frozen, the same on climbable
# walls, ladders and ropes, so every way down a surface feels alike.
@export var climb_up_speed: float = 60.0

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
# Up climbs the hands along the rope; Down slides them at wall_slide_speed,
# like the climb down a wall. They stop this far below the anchor, so the
# head stays clear of the ceiling.
@export var rope_climb_speed: float = 60.0
@export var rope_min_hold: float = 16.0
# Holding the way the swing is already going pushes it along, like
# pumping a playground swing, until it reaches the height cap (degrees):
# rope_max_angle holding the rope's end, shrinking evenly to
# rope_top_max_angle at the top (rope_min_hold). Higher up is a tighter,
# quicker swing that can't throw as wide.
# The pump and brake are for a rope rope_pump_reference_length long and
# scale inversely with length (_rope_length_scale()), so a longer rope
# takes proportionally more passes to pump up: the reference rope (the
# test room's long one) reaches full height after three back-and-forth
# swings of well-timed pumping. Each well-timed pass adds about the same
# angle whatever the hold, so length is what sets the count.
@export var rope_pump_accel: float = 88.0
@export var rope_pump_reference_length: float = 168.0
@export var rope_max_angle: float = 60.0
@export var rope_top_max_angle: float = 20.0
# The hang pose marks the release window: the outer third of a full swing
# (from a third of rope_max_angle out to all of it) on the side the
# player faces, going out and coming back, so it holds long enough to
# read. Angles, not distances, so it's the same on every rope. Only on a
# swing at least rope_release_min_swing high, which the height cap only
# allows low on the rope, so holding high never shows it.
@export var rope_release_min_swing: float = 40.0
# A jump off inside the window also gets this much sideways speed toward
# the side the player faces, so letting go there is worth learning. It
# matters most near the peak, where the swing itself has little speed.
@export var rope_window_jump_boost: float = 64.0
# Holding against the swing slows it. Twice the pump, so steadying the
# rope (to climb it or line up a jump) takes half as long as swinging it
# up: rocking against a full swing stops it in about three sweeps.
@export var rope_brake_accel: float = 120.0
# A little friction, so a swing nobody pumps slowly dies down.
@export var rope_damping: float = 0.16
# A jump off the rope keeps the swing's speed and adds this much lift.
@export var rope_jump_boost: float = -180.0
# And carries this much more of the swing's sideways speed, for a little
# extra distance.
@export var rope_jump_carry: float = 1.2
# Air steering is ignored this long after a jump off the rope, the same
# as after a wall jump, so a held direction doesn't cancel the launch.
@export var rope_release_lock_time: float = 0.2
# The rope just let go of is ignored this long. Grab is usually still
# held, so otherwise it would be caught again straight away. Other ropes
# can be caught at once, so routes can chain from rope to rope.
@export var rope_regrab_delay: float = 0.3
# The body leans with the rope while swinging, turning about the hands so
# they stay on it. After a plain release it straightens at this speed
# (radians per second) rather than snapping upright mid-fall.
@export var rope_tilt_return_speed: float = 12.0

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
@export var crouch_height: float = 12.0
# Down plus a direction crawls. Slow enough that a tunnel reads as a
# squeeze, not a shortcut.
@export var crawl_speed: float = 44.0
# Roll (A while crouched): a fixed burst in the held direction (facing if
# none). Speed x duration is the distance (~49px, about 3 tiles). The
# animation is stretched to last exactly roll_duration.
@export var roll_speed: float = 140.0
@export var roll_duration: float = 0.35
# Slide (Down + A straight out of a sprint): only within
# slide_sprint_window of last being at sprint pace on the ground, so it's
# something a sprint flows into, never a move from a crawl or a walk.
# Starts at slide_speed and bleeds off at slide_friction until
# slide_end_speed. 180px/s (the sprint speed) covers ~65px, about 4 tiles.
@export var slide_speed: float = 212.0
@export var slide_sprint_window: float = 0.2
@export var slide_friction: float = 240.0
@export var slide_end_speed: float = 32.0
# A jump out of the slide is a long jump: this fraction of a normal
# jump's height (same v^2 = 2gh scaling as the charged jump), with
# slide_jump_boost added to the slide's speed, kept until landing. At
# 0.6 and 120, a jump at full slide speed (212) covers about 138px on
# the flat, against 114 for a normal-height jump at that speed.
@export var slide_jump_height: float = 0.6
@export var slide_jump_boost: float = 80.0

# Below this horizontal speed the run animation hands back to idle, so
# the last few pixels of deceleration don't play a stuttery run cycle.
@export var run_anim_threshold: float = 12.0

# A bounce diamond, or dashing into a refill one, hangs the player still
# for this long (a beat to register it) before throwing them on. Touching
# a refill any other way doesn't pause.
@export var diamond_freeze_time: float = 0.8
# A bounce diamond's launch, as a multiple of a full jump's height.
@export var diamond_launch_height: float = 2.0
# The shot out of a refill diamond that was dashed into, as a multiple of
# a plain dash's distance. It moves at dash_speed, so this is its length.
@export var diamond_shot_length: float = 1.6

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
# Each air ability once per trip through the air, and no more than
# max_air_abilities of them in all (air_abilities_used). Only the ground
# refills them, not a wall, ledge or rope; a refill diamond gives back
# the dash and one use.
var has_air_dash: bool = true
var has_air_dive: bool = true
var air_abilities_used: int = 0

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

var is_crouching: bool = false
var is_charging_jump: bool = false
var is_slope_sliding: bool = false
# The slope being slid down, as its surface normal. Kept after leaving it
# so a jump just off the end still kicks off it (slope_coyote_timer).
var slope_normal: Vector2 = Vector2.UP
var slope_coyote_timer: float = 0.0
# Like slope_coyote_timer, for running off a ledge mid-slide: a jump
# just after is still a slide jump.
var slide_coyote_timer: float = 0.0
# Set by a slide jump: the jump keeps its sideways speed
# until landing instead of being eased back to run speed (see
# _apply_movement()). Any other jump, a dash, a grab or landing clears it.
var is_carrying_momentum: bool = false
var jump_charge_timer: float = 0.0
var roll_timer: float = 0.0
var roll_direction: float = 1.0
var is_sliding: bool = false
# Counts down from slide_sprint_window once the body drops off sprint pace.
var slide_window_timer: float = 0.0

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
# The pump has to follow the swing: after a pass spent pushing toward a
# side, that side won't pump again until the other way has been pressed.
# Otherwise holding one direction would pump every pass toward it, out-
# pump the gentle brake on the way back, and keep the swing at full
# height without any rhythm. `swing_pass_side` is the way the current
# pass is going, `pump_this_pass` the side pushed with during it, and
# `pump_spent_side` the side that needs re-arming (0 when none does).
var swing_pass_side: float = 0.0
var pump_this_pass: float = 0.0
var pump_spent_side: float = 0.0
# A jump off a rope somersaults (air_spin, once through) before handing
# back to the usual jump and fall poses.
var is_air_spinning: bool = false
var rope_regrab_timer: float = 0.0
var rope_regrab_rope: SwingRope = null

var diamond_freeze_timer: float = 0.0
var diamond_launch_pending: bool = false
# Dashed into a refill diamond: after the freeze, shoots on in dash_direction.
var diamond_shot_pending: bool = false
# Rising from a bounce diamond. Letting go of jump doesn't cut it short:
# the launch isn't a jump the player is holding.
var is_launched: bool = false

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
# The pull frame held on a rope while pressing away from facing: the more
# upright of the leans, legs together and bent.
const ROPE_PULL_FRAME := 2
# The crouch frame held while a jump charges: the crouch idle is a
# breathing loop, and this is where the head sits lowest, so the body
# reads as coiled rather than resting.
const CHARGE_CROUCH_FRAME := 3
# How hard a slope slide presses into the surface on top of sliding along
# it. move_and_slide() only reports surfaces it pushes against, so this
# keeps the slope showing up every frame and the slide never loses it.
const SLOPE_STICK_SPEED := 40.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
# Where the sprite sits when upright. The rope tilt moves it off this to
# turn it about the hands.
@onready var sprite_base_position: Vector2 = sprite.position
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
	crouch_shape.size = Vector2(standing_shape.size.x, crouch_height)
	stand_probe_shape.size = standing_shape.size - Vector2(2.0, 0.0)
	$PunchHitbox.body_entered.connect(_on_punch_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	_update_tint(delta)
	if velocity.y >= 0.0:
		is_launched = false
	# Also catches the slope run-up, which drops the sprite onto the slope
	# without tilting it: at zero tilt this just puts it back in place.
	if swing_rope == null and (sprite.rotation != 0.0 or sprite.position != sprite_base_position):
		_tilt_sprite(move_toward(sprite.rotation, 0.0, rope_tilt_return_speed * delta))

	# Ahead of the ledge states' early returns, so a hang resets it too.
	# A wall slide or climb breaks the fall, so sliding down a tall wall
	# isn't a hard landing.
	if (is_on_floor() or ledge_state != LedgeState.NONE or is_wall_sliding or is_climbing
			or is_wall_running or swing_rope != null or diamond_freeze_timer > 0.0):
		fall_peak_y = global_position.y
	else:
		fall_peak_y = minf(fall_peak_y, global_position.y)

	if diamond_freeze_timer > 0.0:
		_process_diamond_freeze(delta)
		return

	# Jump buffering: a press slightly before landing still counts,
	# instead of getting silently dropped.
	# Under a ceiling too low to stand (a crawl tunnel), jump does nothing
	# at all: no hop into the ceiling, no charge, and no cutting a roll or
	# slide short. A press buffered on the way in is dropped too, so it
	# can't fire the moment the player comes out the other side.
	if _is_low() and not _can_stand():
		jump_buffer_timer = 0.0
	elif Input.is_action_just_pressed("jump"):
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
		has_air_dive = true
		air_abilities_used = 0
		slope_coyote_timer = 0.0
		slide_coyote_timer = 0.0
		is_carrying_momentum = false
		# Updated every grounded frame, so it's frozen at whatever it was
		# on takeoff. Needs actual sprint pace, not just the button: a
		# standing jump with it held shouldn't steer like a sprint.
		air_sprint = Input.is_action_pressed("sprint") and absf(velocity.x) > max_speed
	else:
		coyote_timer -= delta
		slope_coyote_timer -= delta
		slide_coyote_timer -= delta
	# Refreshed by a real sprint on the ground, not a dash or the slide's
	# own speed, so the window only opens coming out of a sprint. Pressing
	# Down to slide crouches and starts slowing the body straight away, so
	# without the window the press would have to land on the exact frame.
	if is_on_floor() and air_sprint and dash_timer <= 0.0 and not is_sliding:
		slide_window_timer = slide_sprint_window
	else:
		slide_window_timer -= delta

	var wall_side := 0
	if can_wall_jump and not is_on_floor():
		wall_side = _wall_side()
	if wall_side != 0:
		last_wall_side = wall_side
		wall_coyote_timer = wall_coyote_time
	else:
		wall_coyote_timer -= delta

	# One button for the whole family: a dash on the ground (a roll or,
	# sprinting, a slide with Down), a dash or dive in the air.
	# Held while the windup or dash runs (set on the press, so a second
	# press mid-windup can't queue another), so it counts down from
	# whenever and however the dash ends: timed out, jumped out of, or
	# cut off by a wall, ledge or rope.
	if windup_timer <= 0.0 and dash_timer <= 0.0:
		dash_cooldown_timer -= delta
	if (Input.is_action_just_pressed("dash") and windup_timer <= 0.0 and not is_diving
			and dive_land_timer <= 0.0 and not is_charging_jump and not is_slope_sliding):
		var vertical := Input.get_axis("move_up", "crouch")
		if is_on_floor():
			_try_start_ground_move(direction, vertical > 0.0 or is_crouching)
		# Straight down is the dive. Down with a side held is still a dash.
		elif vertical > 0.0 and direction == 0.0:
			if can_dive and has_air_dive and _has_air_ability_left():
				_start_windup(true, direction)
		# The dash needs left or right held. Neutral or Up does nothing, so
		# the air dash is always an aimed choice and never spends itself in
		# whatever way the sprite happens to face. Off a wall slide, climb
		# or wall run it also has to point away from the wall: holding into
		# it is how those are held, so a dash there would fire by accident.
		elif (can_dash and dash_cooldown_timer <= 0.0 and _can_air_dash() and direction != 0.0
				and signf(direction) != float(_held_wall_side())):
			_start_windup(false, direction)

	# A jump during a dash cancels it rather than waiting it out. The
	# dash is longer than the jump buffer, so otherwise an early press
	# would expire mid-dash and feel eaten.
	if dash_timer > 0.0 and jump_buffer_timer > 0.0 and (coyote_timer > 0.0 or wall_coyote_timer > 0.0):
		_end_dash()

	if (not is_climbing and dash_timer <= 0.0 and windup_timer <= 0.0 and not is_diving
			and not is_charging_jump and not is_slope_sliding and _can_start_climb(direction)):
		_start_climb()

	# Attach: a fresh grab press on the ground, facing a wall at the hands.
	# A fresh press only, so grab held while walking along a wall doesn't
	# stick the player to it. Any wall works, not just grip ones.
	if (not is_attached and not is_climbing and not is_crouching and roll_timer <= 0.0 and not is_sliding
			and not is_slope_sliding and is_on_floor() and Input.is_action_just_pressed("grab")
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

	# Down has to be held for the press itself, not just a crouch kept up
	# by a low ceiling (where jump is ignored anyway, above). A tap
	# released within the frame never gets here and jumps normally below.
	if (can_charge_jump and not is_charging_jump and is_crouching and Input.is_action_pressed("crouch")
			and jump_buffer_timer > 0.0 and Input.is_action_pressed("jump")):
		is_charging_jump = true
		jump_charge_timer = 0.0
		jump_buffer_timer = 0.0

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
	elif is_charging_jump:
		_apply_jump_charge(delta)
	elif is_slope_sliding:
		_apply_slope_slide()
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

	# Read from this frame's contacts, so a landing on a slope slides
	# straight away instead of touching down first. A dash or windup runs
	# its course and then slides. Holding uphill on a slope gentle enough
	# to run up is plain running instead (slowed in _apply_movement()), but
	# never once a slide has started: that's a committed ride down.
	var slope := _slide_slope_normal()
	if slope != Vector2.ZERO:
		slope_normal = slope
	var running_up := (slope != Vector2.ZERO and not is_slope_sliding and direction != 0.0
			and signf(direction) == -signf(slope.x) and _slope_angle(slope) <= slope_max_run_up_angle)
	if slope != Vector2.ZERO and not running_up and dash_timer <= 0.0 and windup_timer <= 0.0:
		if not is_slope_sliding:
			_start_slope_slide()
	elif is_slope_sliding and slope == Vector2.ZERO:
		_end_slope_slide()

	if is_diving and is_on_floor():
		is_diving = false
		dive_land_timer = dive_land_time
	elif (not was_on_floor and is_on_floor() and not is_slope_sliding
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
	if (not is_on_floor() and not is_diving and windup_timer <= 0.0
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
		# Running up a slide slope (it's only floor while uphill is held)
		# eases off a little, whatever the pace.
		var slope := _slide_slope_normal()
		if is_on_floor() and slope != Vector2.ZERO and signf(direction) == -signf(slope.x):
			target_speed *= slope_uphill_speed_multiplier
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
		var hit := _steep_slope_ahead(velocity.x * delta)
		if hit:
			velocity.x = hit.get_travel().x / delta

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
		elif coyote_timer > 0.0 and slope_coyote_timer > 0.0:
			_slope_kick()
		elif coyote_timer > 0.0 and slide_coyote_timer > 0.0:
			_slide_jump()
		elif coyote_timer > 0.0:
			velocity.y = jump_velocity
			_consume_jump()
		elif wall_coyote_timer > 0.0:
			_wall_jump(last_wall_side)

	# Variable jump height: releasing the button early cuts the
	# jump short, so tapping gives a hop and holding gives full height.
	if Input.is_action_just_released("jump") and velocity.y < 0.0 and not is_launched:
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
	if _grip_at_hands(int(facing)) == null:
		return false
	# Moving away from the wall means the player is leaving it.
	if direction != 0.0 and signf(direction) != facing:
		return false
	return not is_on_floor() or Input.is_action_pressed("move_up")


func _start_climb() -> void:
	is_carrying_momentum = false
	is_climbing = true
	is_attached = false
	climb_side = int(facing)
	is_wall_sliding = false
	wall_jump_lock_timer = 0.0
	velocity = Vector2.ZERO


func _apply_climb(direction: float, delta: float) -> void:
	# The hands are all that has to stay on the wall, so the player can
	# climb down until hanging from the bottom edge by their arms.
	if not Input.is_action_pressed("grab") or _grip_at_hands(climb_side) == null:
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

	var vertical := Input.get_axis("move_up", "crouch")
	if vertical < 0.0:
		velocity.y = -climb_up_speed
	elif vertical > 0.0:
		velocity.y = wall_slide_speed
	else:
		velocity.y = 0.0
	# A small push into the wall keeps move_and_slide() in contact with it.
	velocity.x = climb_side * 10.0


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


# A on the ground. Crouched (or pressing Down) it rolls; otherwise it's
# the same dash as in the air (wind-up included), so a run can burst
# forward without a hop first. The dash only fires on the move, so A
# from a standstill does nothing rather than dashing whichever way the
# sprite faces. With Down straight out of a sprint (slide_window_timer)
# it slides instead of rolling, so a sprint can shoot low into a tunnel.
# The caller has already checked the press.
func _try_start_ground_move(direction: float, crouched: bool) -> void:
	if (roll_timer > 0.0 or is_sliding or is_climbing or is_attached or attack != Attack.NONE
			or dash_timer > 0.0):
		return
	# A direction pressed on the same frame as A counts as moving: the
	# body hasn't picked up speed yet, but the intent is clear.
	var moving := direction != 0.0 or absf(velocity.x) > run_anim_threshold
	if not crouched:
		if moving and can_dash and dash_cooldown_timer <= 0.0:
			_start_windup(false, direction if direction != 0.0 else velocity.x)
		return
	if slide_window_timer > 0.0:
		is_sliding = true
		slide_window_timer = 0.0
		if direction != 0.0:
			facing = signf(direction)
		elif velocity.x != 0.0:
			facing = signf(velocity.x)
		velocity.x = facing * slide_speed
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
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		_slide_jump()
		return
	if not is_on_floor() or absf(velocity.x) < slide_end_speed:
		if not is_on_floor():
			slide_coyote_timer = coyote_time
		is_sliding = false
		_apply_movement(direction, 0, delta)
		return
	velocity.x = move_toward(velocity.x, 0.0, slide_friction * delta)
	velocity.y = minf(velocity.y + gravity * fall_gravity_multiplier * delta, max_fall_speed)


# A low long jump (still cut short by releasing jump) that keeps the
# slide's sideways speed, plus slide_jump_boost, until landing, with the
# rope jump's somersault.
func _slide_jump() -> void:
	velocity.y = jump_velocity * sqrt(slide_jump_height)
	velocity.x += facing * slide_jump_boost
	is_sliding = false
	slide_coyote_timer = 0.0
	_consume_jump()
	is_carrying_momentum = true
	_start_air_spin()


# The SlideSlope pushed against this frame, as its surface normal, or ZERO.
# Only its slope counts: the upright side and the base are plain wall and
# floor (their normals are straight across or straight down).
func _slide_slope_normal() -> Vector2:
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var normal := hit.get_normal()
		if hit.get_collider() is SlideSlope and normal.y < -0.1 and absf(normal.x) > 0.1:
			return normal
	return Vector2.ZERO


# Whatever the body was doing gives way to the slide: a dive or a hard
# fall lands into it with no recovery, since the slope takes the impact.
func _start_slope_slide() -> void:
	is_slope_sliding = true
	is_diving = false
	dive_land_timer = 0.0
	roll_timer = 0.0
	is_sliding = false
	is_charging_jump = false
	is_air_spinning = false
	is_wall_running = false
	_end_attack()


# Off the end of a slope: into the air it keeps the slide's velocity and
# allows a kick for coyote_time; onto flat ground it carries straight
# into the ground slide, which bleeds the speed off, rather than
# stopping dead under running friction.
func _end_slope_slide() -> void:
	is_slope_sliding = false
	if is_on_floor():
		is_sliding = true
		velocity.x = facing * slope_slide_speed
	else:
		slope_coyote_timer = coyote_time


# Constant speed straight down the slope. Nothing held steers it.
func _apply_slope_slide() -> void:
	if jump_buffer_timer > 0.0:
		_slope_kick()
		return
	var downhill := Vector2(-slope_normal.y, slope_normal.x)
	if downhill.y < 0.0:
		downhill = -downhill
	facing = signf(downhill.x)
	velocity = downhill * slope_slide_speed - slope_normal * SLOPE_STICK_SPEED


# The slope's angle from flat, in degrees.
func _slope_angle(normal: Vector2) -> float:
	return rad_to_deg(acos(clampf(-normal.y, -1.0, 1.0)))


# The collision if moving `motion` px sideways would run into a SlideSlope
# too steep to run up (rising the way the body is going), else null.
func _steep_slope_ahead(motion: float) -> KinematicCollision2D:
	var hit := KinematicCollision2D.new()
	if not test_move(global_transform, Vector2(motion, 0.0), hit):
		return null
	var normal := hit.get_normal()
	if (hit.get_collider() is SlideSlope and normal.y < -0.1 and signf(normal.x) == -signf(motion)
			and _slope_angle(normal) > slope_max_run_up_angle):
		return hit
	return null


# Out at right angles to the slope, with the rope jump's somersault. It
# can be cut short by releasing jump, like any other jump. The slide's
# own speed isn't added: the kick is the same push every time.
func _slope_kick() -> void:
	velocity = slope_normal * slope_kick_speed
	facing = signf(slope_normal.x)
	wall_jump_lock_timer = slope_kick_lock_time
	is_slope_sliding = false
	slope_coyote_timer = 0.0
	_consume_jump()
	_start_air_spin()


func _start_air_spin() -> void:
	is_air_spinning = true
	sprite.speed_scale = 1.0
	sprite.flip_h = facing < 0.0
	sprite.play(&"air_spin")
	# The somersault turns the body over anyway, so it starts upright.
	_tilt_sprite(0.0)


# Planted in the crouch while the jump gathers, like a punch: a run skids
# out under friction. Letting go of jump fires it, steered by whatever
# is held from then on.
func _apply_jump_charge(delta: float) -> void:
	# The floor went (a block pulled out from under, say): no jump.
	if not is_on_floor():
		is_charging_jump = false
		_apply_attack_movement(delta)
		return
	jump_charge_timer += delta
	if Input.is_action_pressed("jump"):
		_apply_attack_movement(delta)
		return
	is_charging_jump = false
	var charge := clampf((jump_charge_timer - charged_jump_min_time)
			/ (charged_jump_time - charged_jump_min_time), 0.0, 1.0)
	if jump_charge_timer >= charged_jump_min_time:
		air_abilities_used += 1
	# Height goes with the square of the take-off speed (v^2 = 2gh), so the
	# speed scales by the root of the height multiple.
	velocity.y = jump_velocity * sqrt(lerpf(1.0, charged_jump_max_height, charge))
	_consume_jump()
	# Released to fire, so a second press and release in the air can't
	# cut it short like a normal jump.
	is_launched = true
	# Fades from wherever the charge glow had got to, so an early release
	# doesn't brighten on takeoff.
	glow_fade_timer = ability_glow_fade_time * charge


# Crouching is plain movement with Down held on the ground. Anything
# else that owns the body (a punch, climb, attach, dash) leaves it alone.
# Wherever there's no room to stand, the body stays low whatever the
# state, and on the ground that means crouching: let go of Down in a
# tunnel and the player keeps crawling until they're out.
func _update_crouch() -> void:
	var free := (not is_climbing and not is_attached and attack == Attack.NONE and dash_timer <= 0.0
			and windup_timer <= 0.0 and not is_diving and dive_land_timer <= 0.0
			and roll_timer <= 0.0 and not is_sliding and not is_slope_sliding)
	var trapped := _is_low() and not _can_stand()
	# A jump charge holds the crouch on its own once Down is let go.
	is_crouching = free and is_on_floor() and (Input.is_action_pressed("crouch") or trapped or is_charging_jump)
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


# The ability windup brightens in one smooth ramp rather than a hard
# flash, well clear of photosensitivity limits.
func _update_tint(delta: float) -> void:
	if windup_timer > 0.0:
		var charge := 1.0 - windup_timer / ability_windup_time
		sprite.modulate = Color.WHITE.lerp(ability_windup_glow, charge)
	elif is_charging_jump:
		# The same ramp as the windup, stretched over the whole charge, then
		# a steady pulse for as long as it's held at full. Each pulse starts
		# and ends at full glow, so there's no jump in brightness at the
		# moment the charge fills.
		var over := jump_charge_timer - charged_jump_time
		if over < 0.0:
			sprite.modulate = Color.WHITE.lerp(ability_windup_glow, jump_charge_timer / charged_jump_time)
		else:
			var pulse := 0.5 - 0.5 * cos(TAU * over / charged_jump_flash_period)
			sprite.modulate = ability_windup_glow.lerp(charged_jump_flash_color, pulse)
	elif dash_timer > 0.0 or is_diving:
		# Holds at full glow for the move itself, so the whole ability
		# reads as one burst of magic rather than a charge then a plain dash.
		sprite.modulate = ability_windup_glow
		glow_fade_timer = ability_glow_fade_time
	elif not _can_air_dash() and not is_on_floor():
		# The glow stays on while the dash can't be used (spent, or the
		# air ability limit reached) until it's refilled, so the player
		# can see at a glance that it's gone. Walls and ledges
		# don't refill it, which makes that worth showing. It fades on landing.
		sprite.modulate = ability_windup_glow
		glow_fade_timer = ability_glow_fade_time
	elif dash_cooldown_timer > 0.0:
		# The glow drains with the cooldown itself rather than its own
		# timer, so it's back to normal the moment the next dash is ready
		# and stays in step with any retune of dash_cooldown. No other fade
		# runs on after it, or the glow would outlast the wait.
		sprite.modulate = Color.WHITE.lerp(ability_windup_glow, dash_cooldown_timer / dash_cooldown)
		glow_fade_timer = 0.0
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
	# Only from standing height: a roll or slide into a wall would otherwise read
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
				and not is_crouching and roll_timer <= 0.0 and not is_sliding and not is_slope_sliding):
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
	if Input.is_action_just_released("jump") and velocity.y < 0.0 and not is_launched:
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
	# A jump out of a launch (off a wall, say) is a normal, cuttable one.
	is_launched = false
	# The slide jump and slope kick set it again straight after.
	is_carrying_momentum = false


# Called by a RefillDiamond the player is touching. Returns whether it
# was taken, so the diamond only vanishes when it did something.
func touch_diamond(launch: bool) -> bool:
	# The ledge and rope states own the body, and a second diamond
	# mid-freeze would just restart it.
	if diamond_freeze_timer > 0.0 or ledge_state != LedgeState.NONE or swing_rope != null:
		return false
	# A refill while the dash is ready would be wasted, so the player
	# passes through. The ground always refills, so this covers standing
	# in one. It gives back one use, not all of them, so diamonds extend a
	# chain by a step rather than resetting it like the ground.
	if not launch and _can_air_dash():
		return false
	has_air_dash = true
	air_abilities_used = maxi(air_abilities_used - 1, 0)
	dash_cooldown_timer = 0.0
	# Falling or drifting into a refill doesn't interrupt anything: the
	# next dash is just ready straight away. Dashing into one is the
	# exception, and turns it into a slingshot (below).
	if not launch and dash_timer <= 0.0:
		return true
	diamond_freeze_timer = diamond_freeze_time
	diamond_launch_pending = launch
	# dash_direction survives the reset below, so the shot goes the way
	# the dash was going.
	diamond_shot_pending = not launch
	# Hangs in place like the dash windup, cutting off whatever the body
	# was doing, so it always drops (or launches) from rest.
	windup_timer = 0.0
	dash_timer = 0.0
	is_diving = false
	dive_land_timer = 0.0
	is_climbing = false
	is_wall_sliding = false
	is_wall_running = false
	is_attached = false
	wall_jump_lock_timer = 0.0
	roll_timer = 0.0
	is_sliding = false
	is_charging_jump = false
	is_slope_sliding = false
	is_carrying_momentum = false
	is_air_spinning = false
	is_launched = false
	air_sprint = false
	_end_attack()
	velocity = Vector2.ZERO
	return true


# The tint isn't frozen with the body: the dash glow fades back to normal
# during the hold (_update_tint() runs before this), so the refill reads
# before the player moves again.
func _process_diamond_freeze(delta: float) -> void:
	diamond_freeze_timer -= delta
	velocity = Vector2.ZERO
	sprite.speed_scale = 0.0
	if diamond_freeze_timer > 0.0:
		return
	if diamond_shot_pending:
		diamond_shot_pending = false
		# Runs as an ordinary dash, so it keeps the dash's rules: gravity
		# off, stopped by a wall, cancelled by a jump, and handed back at
		# run speed. The air dash stays refilled for after it.
		facing = dash_direction
		dash_timer = dash_duration * diamond_shot_length
		velocity = Vector2(dash_direction * dash_speed, 0.0)
		return
	if not diamond_launch_pending:
		return
	diamond_launch_pending = false
	_consume_jump()
	# v^2 = 2gh, so n times a jump's height is sqrt(n) times its takeoff
	# speed. Worked out from jump_velocity so it follows any retune.
	velocity.y = jump_velocity * sqrt(diamond_launch_height)
	is_launched = true


# The direction, cooldown and air dash are all settled on the press, not
# when the windup ends, so a second press mid-windup can't queue another.
func _start_windup(dive: bool, direction: float) -> void:
	is_carrying_momentum = false
	windup_is_dive = dive
	windup_timer = ability_windup_time
	if not dive:
		dash_direction = signf(direction)
		facing = dash_direction
		dash_cooldown_timer = dash_cooldown
		# A sprint dash needs sprint pace with the button still held.
		# air_sprint is refreshed every grounded frame and frozen on
		# takeoff, so in the air that means a sprinting takeoff.
		dash_is_sprint = Input.is_action_pressed("sprint") and air_sprint
		has_air_dash = false
	else:
		has_air_dive = false
	# A ground dash spends one too, but the ground refills it at once.
	air_abilities_used += 1
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


func _has_air_ability_left() -> bool:
	return air_abilities_used < max_air_abilities


func _can_air_dash() -> bool:
	return has_air_dash and _has_air_ability_left()


# The wall the player is holding on to by sliding, climbing or running up
# it (-1 left, 1 right), or 0.
func _held_wall_side() -> int:
	if is_wall_sliding:
		return last_wall_side
	if is_climbing:
		return climb_side
	if is_wall_running:
		return wall_run_side
	return 0


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
	is_carrying_momentum = false
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
	# No jumping out of the climb: a press during it is dropped rather than
	# buffered, so it can't fire the moment the climb ends.
	jump_buffer_timer = 0.0
	if t >= 1.0:
		ledge_state = LedgeState.NONE
		velocity = Vector2.ZERO
		# The hang and climb skip the timer updates, so wall coyote is still
		# frozen at whatever the slide or wall run left it, and is_on_floor()
		# is stale until the next move_and_slide(). Without this the first
		# jump off the top is a wall jump back off the ledge. Standing on
		# the top, it should be a plain ground jump in any direction.
		wall_coyote_timer = 0.0
		coyote_timer = coyote_time
		# Same for a wall jump's steering lock left over from before the catch.
		wall_jump_lock_timer = 0.0


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
	# A few results, so the rope just let go of can't hide another one
	# crossing it at the hands.
	var rope: SwingRope = null
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 4):
		var candidate := hit.collider as SwingRope
		if candidate != null and not (candidate == rope_regrab_rope and rope_regrab_timer > 0.0):
			rope = candidate
			break
	if rope == null:
		return false

	swing_rope = rope
	is_carrying_momentum = false
	rope.held = true
	swing_distance = clampf((hands - rope.global_position).dot(rope.direction()), rope_min_hold, rope.length)
	# The swing starts from the speed the player brought across the rope,
	# added to the rope's own: a dash into it swings hard, a jump up from
	# underneath (all speed along the rope) barely moves it, and catching
	# a rope swinging toward you cancels some of it.
	var along := rope.direction()
	var w := rope.angular_velocity + velocity.dot(Vector2(along.y, -along.x)) / swing_distance
	# No higher than a full pump could take it, so a fast catch can't send
	# the swing over the top of the anchor.
	w = _cap_swing(rope.angle, w)
	rope.set_swing(rope.angle, w)
	swing_pass_side = signf(w)
	pump_this_pass = 0.0
	pump_spent_side = 0.0
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
	_tilt_sprite(-rope.angle)
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

	# Turn to hold on from the other side, if there's room for the body
	# there. Facing is otherwise fixed for the whole swing.
	if Input.is_action_just_pressed("turn"):
		var hands := rope.global_position + rope.direction() * swing_distance
		var turned := Vector2(-facing * ledge_hand_offset.x, ledge_hand_offset.y)
		if not test_move(global_transform, hands - turned - global_position):
			facing = -facing

	# Moving the hands leaves the swing alone: the rope swings at its own
	# tempo (_swing_length()) wherever the player holds it, so climbing
	# neither speeds it up nor makes it bigger. A real pendulum shortened
	# this way quickens and pumps itself, which turned a barely-moving rope
	# into a frantic little swing near the top; only the pump adds height.
	# Nor does it shrink the swing: the lower height cap up the rope only
	# stops the pump, so a big swing carries on after a climb.
	var w := rope.angular_velocity
	var vertical := Input.get_axis("move_up", "crouch")
	# No climbing up while the hang pose shows (the release window): the
	# player is flung out to the side there, and hauling up would look
	# wrong. It also keeps Up from fighting the cue to let go.
	if vertical < 0.0 and _in_release_window():
		vertical = 0.0
	var rope_speed := rope_climb_speed if vertical < 0.0 else wall_slide_speed
	var slid_to := swing_distance + vertical * rope_speed * delta
	# Sliding down past the end of the rope drops off it, grab or not, so
	# Down is a way off that keeps the rope's swing.
	if vertical > 0.0 and slid_to > rope.length:
		_release_rope(false)
		velocity += rope.direction() * wall_slide_speed * vertical
		return
	var new_distance := clampf(slid_to, rope_min_hold, rope.length)
	var climbed := new_distance - swing_distance
	swing_distance = new_distance

	var a := rope.angle
	w += -gravity / _swing_length() * sin(a) * delta
	# A pass ends when the swing turns round. Whatever side was pushed
	# toward during it is spent until the other way is pressed.
	# Starting from still isn't a turn: the push that started it belongs
	# to the pass it started, or it would be spent straight away and the
	# first direction pressed would refuse to pump again.
	if signf(w) != 0.0 and signf(w) != swing_pass_side:
		if swing_pass_side != 0.0:
			if pump_this_pass != 0.0:
				pump_spent_side = pump_this_pass
			pump_this_pass = 0.0
		swing_pass_side = signf(w)
	var side := signf(direction)
	if side != 0.0 and side == -pump_spent_side:
		pump_spent_side = 0.0
	# With the swing (or from rest, where any direction starts it) pumps,
	# against it brakes. Pumping stops adding once the swing is at full
	# height. Height comes from the swing's energy rather than its current
	# angle, so a pump at the bottom knows how high the swing will go.
	# Hanging still at the bottom, not just slow: the swing is also slow at
	# the top of every pass, and counting that would let a press pump
	# whichever way it liked there.
	var at_rest := absf(w) < 0.05 and absf(a) < 0.05
	if side != 0.0 and (side == signf(w) or at_rest):
		if side != pump_spent_side:
			pump_this_pass = side
			var reach := clampf(cos(a) - w * w * _swing_length() / (2.0 * gravity), -1.0, 1.0)
			if acos(reach) < _swing_max_angle():
				w += side * rope_pump_accel * _rope_length_scale() / _swing_length() * delta
	elif side != 0.0:
		w = move_toward(w, 0.0, rope_brake_accel * _rope_length_scale() / _swing_length() * delta)
	w *= maxf(1.0 - rope_damping * delta, 0.0)
	rope.set_swing(a + w * delta, w)

	# Hitting a wall or ceiling stops the swing dead, still holding on.
	if not _follow_rope():
		rope.set_swing(a, 0.0)
	_update_swing_animation(direction, climbed)
	_tilt_sprite(-rope.angle)


# The pendulum length the swing runs on: the whole rope, not the hold,
# so the tempo is the same wherever the player holds on (see
# _process_swing()). The hold still sets the height cap and how fast the
# hands, and so the player, actually move.
func _swing_length() -> float:
	return maxf(swing_rope.length, 1.0)


# Pump and brake strength relative to the reference rope: weaker on a
# longer rope, so it takes longer to pump up.
func _rope_length_scale() -> float:
	return rope_pump_reference_length / maxf(swing_rope.length, 1.0)


# The height cap in radians at the current hold: rope_max_angle at the
# rope's end down to rope_top_max_angle at rope_min_hold.
func _swing_max_angle() -> float:
	var t := inverse_lerp(rope_min_hold, swing_rope.length, swing_distance) if swing_rope.length > rope_min_hold else 1.0
	return deg_to_rad(lerpf(rope_top_max_angle, rope_max_angle, clampf(t, 0.0, 1.0)))


# Limits angular velocity `w` at angle `a` so a catch can't swing past
# the height cap. Past the cap already, it can still fall back but not
# carry on outward.
func _cap_swing(a: float, w: float) -> float:
	var cap := _swing_max_angle()
	if absf(a) >= cap:
		return 0.0 if signf(w) == signf(a) else w
	var w_max := sqrt(2.0 * gravity * (cos(a) - cos(cap)) / _swing_length())
	return clampf(w, -w_max, w_max)


# The swing's poses, all drawn holding on to the right:
# - ledge_hang in the release window, whatever is held, so the best
#   moment to jump off reads at a glance.
# - climb cycling forward climbing up the rope, and frozen on its current
#   frame sliding down (a slide, as on a wall).
#   `climbed` is how far down the rope the hands moved this frame.
# - otherwise single held frames, so each reads as a state: pull's
#   ROPE_PULL_FRAME while holding away from facing, else climb's first.
func _update_swing_animation(direction: float, climbed: float) -> void:
	sprite.speed_scale = 1.0
	sprite.flip_h = facing < 0.0
	if _in_release_window():
		_play(&"ledge_hang")
	elif climbed < 0.0:
		sprite.play(&"climb")
	elif climbed > 0.0:
		# Sliding down: the climb frame it was on, frozen.
		if sprite.animation != &"climb":
			sprite.animation = &"climb"
		sprite.pause()
	elif direction != 0.0 and signf(direction) == -facing:
		_hold_frame(&"pull", ROPE_PULL_FRAME)
	else:
		_hold_frame(&"climb", 0)


func _hold_frame(anim: StringName, frame: int) -> void:
	if sprite.animation != anim:
		sprite.animation = anim
	sprite.pause()
	sprite.frame = frame


# The swing's full height in radians, from its energy (as in the pump
# check), so it's known anywhere in the pass, not just at the peak.
func _swing_height() -> float:
	var a := swing_rope.angle
	var w := swing_rope.angular_velocity
	return acos(clampf(cos(a) - w * w * _swing_length() / (2.0 * gravity), -1.0, 1.0))


# True in the outer third of a full swing on the side the player faces,
# either way through, on a big enough swing. The swing's full height comes from
# its energy, as in the pump check.
func _in_release_window() -> bool:
	var a := swing_rope.angle
	if signf(a) != facing:
		return false
	if absf(a) < deg_to_rad(rope_max_angle) / 3.0:
		return false
	return _swing_height() >= deg_to_rad(rope_release_min_swing)


# Leans the sprite by `tilt` radians about the hands (the body box stays
# upright; only the art turns). The rope's own rotation is -angle, so
# passing that lines the body up with it.
# Tips the slide pose to lie along the slope, turned about the feet (or
# leaves it upright, for the run up). The upright body box rests on the
# slope by its uphill corner, which leaves the feet floating above the
# surface by half the box's width times the slope; the sprite drops by
# that much to sit on it.
func _lean_on_slope(tilted: bool) -> void:
	var tilt := atan2(absf(slope_normal.x), -slope_normal.y) * facing if tilted else 0.0
	var sink := standing_shape.size.x * 0.5 * absf(slope_normal.x / slope_normal.y)
	sprite.rotation = tilt
	sprite.position = sprite_base_position.rotated(tilt) + Vector2(0.0, sink)


func _tilt_sprite(tilt: float) -> void:
	var pivot := _rope_hand_offset()
	sprite.rotation = tilt
	sprite.position = pivot + (sprite_base_position - pivot).rotated(tilt)


# Moves the body so the hands sit on the rope. False if something solid
# got in the way first.
func _follow_rope() -> bool:
	var hands := swing_rope.global_position + swing_rope.direction() * swing_distance
	return move_and_collide(hands - _rope_hand_offset() - global_position) == null


# Lets go with the swing's speed. A jump adds lift and briefly locks air
# steering so the launch carries; a plain release just drops.
func _release_rope(jump: bool) -> void:
	var in_window := _in_release_window()
	velocity = _rope_tangent() * swing_rope.angular_velocity * swing_distance
	if jump:
		# At least the boost upward, so a jump on the downswing still rises.
		velocity.y = minf(velocity.y, 0.0) + rope_jump_boost
		velocity.x *= rope_jump_carry
		if in_window:
			velocity.x += facing * rope_window_jump_boost
		wall_jump_lock_timer = rope_release_lock_time
		if velocity.x != 0.0:
			facing = signf(velocity.x)
		_consume_jump()
		_start_air_spin()
	swing_rope.held = false
	rope_regrab_rope = swing_rope
	rope_regrab_timer = rope_regrab_delay
	swing_rope = null
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
		# A steep slide slope's face reads as a wall on the ground, so a run
		# into its foot plays the push. In the air it's a slope to land and
		# slide on, never a wall to slide down or jump off.
		if collision.get_collider() is SlideSlope and collision.get_normal().y < -0.1 and not is_on_floor():
			return false
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
	if is_slope_sliding:
		sprite.flip_h = facing < 0.0
		_play("slide")
		_lean_on_slope(true)
		return

	if is_climbing:
		# The climb sheet is drawn against a wall on the right. The cycle
		# runs going up and holds its frame otherwise: clinging, and
		# sliding down, which is a slide rather than a climb.
		sprite.flip_h = climb_side < 0
		if sprite.animation != "climb":
			sprite.play("climb")
		if velocity.y < 0.0:
			sprite.play("climb")
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
	# Running up a slope: the upright box rests on its uphill corner, so
	# the feet would float above the surface without this.
	if is_on_floor() and _slide_slope_normal() != Vector2.ZERO:
		_lean_on_slope(false)

	if not is_on_floor():
		_play("jump" if velocity.y < 0.0 else "fall")
		return

	# Frozen on one frame, like the windup, so the charge reads as power
	# being held in rather than the idle breathing.
	if is_charging_jump:
		_hold_frame(&"crouch_idle", CHARGE_CROUCH_FRAME)
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
	dash_cooldown_timer = 0.0
	glow_fade_timer = 0.0
	diamond_freeze_timer = 0.0
	diamond_launch_pending = false
	diamond_shot_pending = false
	is_launched = false
	is_diving = false
	dive_land_timer = 0.0
	dive_land_timer_just_ended = false
	wall_jump_lock_timer = 0.0
	is_wall_sliding = false
	is_wall_running = false
	is_attached = false
	is_crouching = false
	is_charging_jump = false
	is_slope_sliding = false
	slope_coyote_timer = 0.0
	slide_coyote_timer = 0.0
	is_carrying_momentum = false
	roll_timer = 0.0
	is_sliding = false
	_set_low(false)
	has_air_dash = true
	has_air_dive = true
	air_abilities_used = 0
	ledge_state = LedgeState.NONE
	is_climbing = false
	if swing_rope != null:
		swing_rope.held = false
		swing_rope = null
	_tilt_sprite(0.0)
	is_air_spinning = false
	_end_attack()
