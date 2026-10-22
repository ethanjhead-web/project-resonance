class_name PlayerDash
extends Node

# The dash family on A: the dash (air, or on the move on the ground), the
# dive, the windup before both and its glow, the air ability limit, hard
# landings, and the refill and bounce diamonds that hand the dash back.
# A roll or slide (A crouched) is the Crouch component's.

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

# A bounce diamond, or dashing into a refill one, hangs the player still
# for this long (a beat to register it) before throwing them on. Touching
# a refill any other way doesn't pause.
@export var diamond_freeze_time: float = 0.8
# A bounce diamond's launch, as a multiple of a full jump's height.
@export var diamond_launch_height: float = 2.0
# The shot out of a refill diamond that was dashed into, as a multiple of
# a plain dash's distance. It moves at dash_speed, so this is its length.
@export var diamond_shot_length: float = 1.6

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

var diamond_freeze_timer: float = 0.0
var diamond_launch_pending: bool = false
# Dashed into a refill diamond: after the freeze, shoots on in dash_direction.
var diamond_shot_pending: bool = false

@onready var player := get_parent() as Player


# One button for the whole family: a dash on the ground (a roll or,
# sprinting, a slide with Down), a dash or dive in the air.
func handle_press(direction: float, delta: float) -> void:
	# Held while the windup or dash runs (set on the press, so a second
	# press mid-windup can't queue another), so it counts down from
	# whenever and however the dash ends: timed out, jumped out of, or
	# cut off by a wall, ledge or rope.
	if windup_timer <= 0.0 and dash_timer <= 0.0:
		dash_cooldown_timer -= delta
	if (not Input.is_action_just_pressed("dash") or windup_timer > 0.0 or is_diving
			or dive_land_timer > 0.0 or player.crouch.is_charging_jump or player.slope.is_slope_sliding):
		return
	var vertical := Input.get_axis("move_up", "crouch")
	if player.is_on_floor():
		player.crouch.try_start_ground_move(direction, vertical > 0.0 or player.crouch.is_crouching)
	# Straight down is the dive. Down with a side held is still a dash.
	elif vertical > 0.0 and direction == 0.0:
		if player.can_dive and has_air_dive and has_air_ability_left():
			start_windup(true, direction)
	# The dash needs left or right held. Neutral or Up does nothing, so
	# the air dash is always an aimed choice and never spends itself in
	# whatever way the sprite happens to face. Off a wall slide, climb
	# or wall run it also has to point away from the wall: holding into
	# it is how those are held, so a dash there would fire by accident.
	elif (player.can_dash and dash_cooldown_timer <= 0.0 and can_air_dash() and direction != 0.0
			and signf(direction) != float(player.held_wall_side())):
		start_windup(false, direction)


# Moves the body while the windup, dash, dive or the dive's landing
# recovery runs. Returns false, doing nothing, when none of them is.
func apply(delta: float) -> bool:
	if windup_timer > 0.0:
		windup_timer -= delta
		player.velocity = Vector2.ZERO
		if windup_timer <= 0.0:
			if windup_is_dive:
				start_dive()
			else:
				start_dash()
	elif dash_timer > 0.0:
		dash_timer -= delta
		player.velocity = Vector2(dash_direction * dash_speed, 0.0)
		if dash_timer <= 0.0:
			end_dash()
	elif is_diving:
		player.velocity = Vector2(0.0, dive_speed)
	elif dive_land_timer > 0.0:
		dive_land_timer -= delta
		dive_land_timer_just_ended = dive_land_timer <= 0.0
		player.apply_attack_movement(delta)
	else:
		return false
	return true


# After moving: a dive that hit the ground, or a long enough fall, starts
# the landing recovery.
func update_landing(was_on_floor: bool) -> void:
	if is_diving and player.is_on_floor():
		is_diving = false
		dive_land_timer = dive_land_time
	elif (not was_on_floor and player.is_on_floor() and not player.slope.is_slope_sliding
			and player.global_position.y - player.fall_peak_y >= hard_land_height):
		# An air punch would otherwise carry on as a grounded one under
		# the recovery pose.
		player.punch.end_attack()
		dive_land_timer = dive_land_time


# The direction, cooldown and air dash are all settled on the press, not
# when the windup ends, so a second press mid-windup can't queue another.
func start_windup(dive: bool, direction: float) -> void:
	player.is_carrying_momentum = false
	windup_is_dive = dive
	windup_timer = ability_windup_time
	if not dive:
		dash_direction = signf(direction)
		player.facing = dash_direction
		dash_cooldown_timer = dash_cooldown
		# A sprint dash needs sprint pace with the button still held.
		# air_sprint is refreshed every grounded frame and frozen on
		# takeoff, so in the air that means a sprinting takeoff.
		dash_is_sprint = Input.is_action_pressed("sprint") and player.air_sprint
		has_air_dash = false
	else:
		has_air_dive = false
	# A ground dash spends one too, but the ground refills it at once.
	air_abilities_used += 1
	# Hangs in place, cutting off whatever the body was doing. A dive
	# pressed mid-dash cancels the dash here.
	dash_timer = 0.0
	player.climb.is_climbing = false
	player.is_wall_sliding = false
	player.is_wall_running = false
	player.wall_jump_lock_timer = 0.0
	player.crouch.roll_timer = 0.0
	player.crouch.is_sliding = false
	player.punch.end_attack()
	player.velocity = Vector2.ZERO


func has_air_ability_left() -> bool:
	return air_abilities_used < player.max_air_abilities


func can_air_dash() -> bool:
	return has_air_dash and has_air_ability_left()


func start_dash() -> void:
	dash_timer = sprint_dash_duration if dash_is_sprint else dash_duration
	player.velocity = Vector2(dash_direction * dash_speed, 0.0)


# A commitment straight down, with no steering until it lands.
func start_dive() -> void:
	is_diving = true
	player.air_sprint = false
	player.velocity = Vector2(0.0, dive_speed)


func end_dash() -> void:
	dash_timer = 0.0
	# Hand back at run speed rather than dash speed, so the player
	# doesn't skate on after the dash visibly ends. Still holding sprint
	# hands back at sprint speed, so there's no dip before the sprint.
	player.velocity = Vector2(dash_direction * player.run_speed(), 0.0)


# The ability windup brightens in one smooth ramp rather than a hard
# flash, well clear of photosensitivity limits.
func update_tint(delta: float) -> void:
	var sprite := player.sprite
	var crouch := player.crouch
	if windup_timer > 0.0:
		var charge := 1.0 - windup_timer / ability_windup_time
		sprite.modulate = Color.WHITE.lerp(ability_windup_glow, charge)
	elif crouch.is_charging_jump:
		# The same ramp as the windup, stretched over the whole charge, then
		# a steady pulse for as long as it's held at full. Each pulse starts
		# and ends at full glow, so there's no jump in brightness at the
		# moment the charge fills.
		var over := crouch.jump_charge_timer - crouch.charged_jump_time
		if over < 0.0:
			sprite.modulate = Color.WHITE.lerp(ability_windup_glow, crouch.jump_charge_timer / crouch.charged_jump_time)
		else:
			var pulse := 0.5 - 0.5 * cos(TAU * over / crouch.charged_jump_flash_period)
			sprite.modulate = ability_windup_glow.lerp(crouch.charged_jump_flash_color, pulse)
	elif dash_timer > 0.0 or is_diving:
		# Holds at full glow for the move itself, so the whole ability
		# reads as one burst of magic rather than a charge then a plain dash.
		sprite.modulate = ability_windup_glow
		glow_fade_timer = ability_glow_fade_time
	elif not can_air_dash() and not player.is_on_floor():
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


# Called through the player by a RefillDiamond it's touching. Returns
# whether it was taken, so the diamond only vanishes when it did something.
func touch_diamond(launch: bool) -> bool:
	# The ledge and rope states own the body, and a second diamond
	# mid-freeze would just restart it.
	if diamond_freeze_timer > 0.0 or player.ledge.is_on_ledge() or player.rope.swing_rope != null:
		return false
	# A refill while the dash is ready would be wasted, so the player
	# passes through. The ground always refills, so this covers standing
	# in one. It gives back one use, not all of them, so diamonds extend a
	# chain by a step rather than resetting it like the ground.
	if not launch and can_air_dash():
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
	player.climb.is_climbing = false
	player.is_wall_sliding = false
	player.is_wall_running = false
	player.climb.is_attached = false
	player.wall_jump_lock_timer = 0.0
	player.crouch.roll_timer = 0.0
	player.crouch.is_sliding = false
	player.crouch.is_charging_jump = false
	player.slope.is_slope_sliding = false
	player.is_carrying_momentum = false
	player.anim.is_air_spinning = false
	player.is_launched = false
	player.air_sprint = false
	player.punch.end_attack()
	player.velocity = Vector2.ZERO
	return true


# The tint isn't frozen with the body: the dash glow fades back to normal
# during the hold (update_tint() runs before this), so the refill reads
# before the player moves again.
func process_diamond_freeze(delta: float) -> void:
	diamond_freeze_timer -= delta
	player.velocity = Vector2.ZERO
	player.sprite.speed_scale = 0.0
	if diamond_freeze_timer > 0.0:
		return
	if diamond_shot_pending:
		diamond_shot_pending = false
		# Runs as an ordinary dash, so it keeps the dash's rules: gravity
		# off, stopped by a wall, cancelled by a jump, and handed back at
		# run speed. The air dash stays refilled for after it.
		player.facing = dash_direction
		dash_timer = dash_duration * diamond_shot_length
		player.velocity = Vector2(dash_direction * dash_speed, 0.0)
		return
	if not diamond_launch_pending:
		return
	diamond_launch_pending = false
	player.consume_jump()
	# v^2 = 2gh, so n times a jump's height is sqrt(n) times its takeoff
	# speed. Worked out from jump_velocity so it follows any retune.
	player.velocity.y = player.jump_velocity * sqrt(diamond_launch_height)
	player.is_launched = true


func reset() -> void:
	dash_timer = 0.0
	windup_timer = 0.0
	dash_cooldown_timer = 0.0
	glow_fade_timer = 0.0
	diamond_freeze_timer = 0.0
	diamond_launch_pending = false
	diamond_shot_pending = false
	is_diving = false
	dive_land_timer = 0.0
	dive_land_timer_just_ended = false
	has_air_dash = true
	has_air_dive = true
	air_abilities_used = 0
