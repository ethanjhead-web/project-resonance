class_name PlayerCrouch
extends Node

# Everything low: the crouch and crawl, the low body box and standing back
# up, the roll and slide (A on the ground), the slide jump, and the
# charged jump (Down+jump).

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

var is_crouching: bool = false
var is_charging_jump: bool = false
var jump_charge_timer: float = 0.0
var roll_timer: float = 0.0
var roll_direction: float = 1.0
var is_sliding: bool = false
# Counts down from slide_sprint_window once the body drops off sprint pace.
var slide_window_timer: float = 0.0
# Like the slope's coyote timer, for running off a ledge mid-slide: a jump
# just after is still a slide jump.
var slide_coyote_timer: float = 0.0

# The low body box, swapped in for the player's standing_shape.
var crouch_shape := RectangleShape2D.new()
# One pixel narrower than the body, so a wall the player is touching
# doesn't count as something in the way of standing up.
var stand_probe_shape := RectangleShape2D.new()

@onready var player := get_parent() as Player


# Called from the player's _ready(), once its body shape is known.
func setup() -> void:
	crouch_shape.size = Vector2(player.standing_shape.size.x, crouch_height)
	stand_probe_shape.size = player.standing_shape.size - Vector2(2.0, 0.0)


# A on the ground. Crouched (or pressing Down) it rolls; otherwise it's
# the same dash as in the air (wind-up included), so a run can burst
# forward without a hop first. The dash only fires on the move, so A
# from a standstill does nothing rather than dashing whichever way the
# sprite faces. With Down straight out of a sprint (slide_window_timer)
# it slides instead of rolling, so a sprint can shoot low into a tunnel.
# The caller has already checked the press.
func try_start_ground_move(direction: float, crouched: bool) -> void:
	if (roll_timer > 0.0 or is_sliding or player.climb.is_climbing or player.climb.is_attached
			or player.punch.is_punching() or player.dash.dash_timer > 0.0):
		return
	# A direction pressed on the same frame as A counts as moving: the
	# body hasn't picked up speed yet, but the intent is clear.
	var moving := direction != 0.0 or absf(player.velocity.x) > player.run_anim_threshold
	if not crouched:
		if moving and player.can_dash and player.dash.dash_cooldown_timer <= 0.0:
			player.dash.start_windup(false, direction if direction != 0.0 else player.velocity.x)
		return
	if slide_window_timer > 0.0:
		is_sliding = true
		slide_window_timer = 0.0
		if direction != 0.0:
			player.facing = signf(direction)
		elif player.velocity.x != 0.0:
			player.facing = signf(player.velocity.x)
		player.velocity.x = player.facing * slide_speed
		return
	roll_direction = signf(direction) if direction != 0.0 else player.facing
	player.facing = roll_direction
	roll_timer = roll_duration
	# Started here rather than in update_animation(), so a roll straight
	# after a roll restarts the sheet instead of holding its last frame.
	var sprite := player.sprite
	var frames := sprite.sprite_frames
	var anim_length := frames.get_frame_count(&"roll") / frames.get_animation_speed(&"roll")
	sprite.flip_h = roll_direction < 0.0
	sprite.play(&"roll", anim_length / roll_duration)


# Committed for its length: no steering, but a jump cancels it (a press
# shouldn't be eaten mid-roll), and running off an edge ends it so the
# body falls rather than rolling on through the air.
func apply_roll(direction: float, delta: float) -> void:
	roll_timer -= delta
	if not player.is_on_floor() or (player.jump_buffer_timer > 0.0 and player.coyote_timer > 0.0):
		roll_timer = 0.0
		player.apply_movement(direction, 0, delta)
		return
	player.velocity.x = roll_direction * roll_speed
	player.velocity.y = minf(player.velocity.y + player.gravity * player.fall_gravity_multiplier * delta,
			player.max_fall_speed)


# Bleeds the sprint off under its own friction, then hands back to a
# crouch (or standing, if Down isn't held and there's room). A jump
# cancels it into a jump that keeps the speed; leaving the ground or
# hitting a wall ends it.
func apply_slide(direction: float, delta: float) -> void:
	if player.jump_buffer_timer > 0.0 and player.coyote_timer > 0.0:
		slide_jump()
		return
	if not player.is_on_floor() or absf(player.velocity.x) < slide_end_speed:
		if not player.is_on_floor():
			slide_coyote_timer = player.coyote_time
		is_sliding = false
		player.apply_movement(direction, 0, delta)
		return
	player.velocity.x = move_toward(player.velocity.x, 0.0, slide_friction * delta)
	player.velocity.y = minf(player.velocity.y + player.gravity * player.fall_gravity_multiplier * delta,
			player.max_fall_speed)


# A low long jump (still cut short by releasing jump) that keeps the
# slide's sideways speed, plus slide_jump_boost, until landing, with the
# rope jump's somersault.
func slide_jump() -> void:
	player.velocity.y = player.jump_velocity * sqrt(slide_jump_height)
	player.velocity.x += player.facing * slide_jump_boost
	is_sliding = false
	slide_coyote_timer = 0.0
	player.consume_jump()
	player.is_carrying_momentum = true
	player.anim.start_air_spin()


# Down has to be held for the press itself, not just a crouch kept up
# by a low ceiling (where jump is ignored anyway). A tap released within
# the frame never gets here and jumps normally.
func try_start_charge() -> void:
	if (player.can_charge_jump and not is_charging_jump and is_crouching and Input.is_action_pressed("crouch")
			and player.jump_buffer_timer > 0.0 and Input.is_action_pressed("jump")):
		is_charging_jump = true
		jump_charge_timer = 0.0
		player.jump_buffer_timer = 0.0


# Planted in the crouch while the jump gathers, like a punch: a run skids
# out under friction. Letting go of jump fires it, steered by whatever
# is held from then on.
func apply_jump_charge(delta: float) -> void:
	# The floor went (a block pulled out from under, say): no jump.
	if not player.is_on_floor():
		is_charging_jump = false
		player.apply_attack_movement(delta)
		return
	jump_charge_timer += delta
	if Input.is_action_pressed("jump"):
		player.apply_attack_movement(delta)
		return
	is_charging_jump = false
	var charge := clampf((jump_charge_timer - charged_jump_min_time)
			/ (charged_jump_time - charged_jump_min_time), 0.0, 1.0)
	if jump_charge_timer >= charged_jump_min_time:
		player.dash.air_abilities_used += 1
	# Height goes with the square of the take-off speed (v^2 = 2gh), so the
	# speed scales by the root of the height multiple.
	player.velocity.y = player.jump_velocity * sqrt(lerpf(1.0, charged_jump_max_height, charge))
	player.consume_jump()
	# Released to fire, so a second press and release in the air can't
	# cut it short like a normal jump.
	player.is_launched = true
	# Fades from wherever the charge glow had got to, so an early release
	# doesn't brighten on takeoff.
	player.dash.glow_fade_timer = player.dash.ability_glow_fade_time * charge


# Crouching is plain movement with Down held on the ground. Anything
# else that owns the body (a punch, climb, attach, dash) leaves it alone.
# Wherever there's no room to stand, the body stays low whatever the
# state, and on the ground that means crouching: let go of Down in a
# tunnel and the player keeps crawling until they're out.
func update_crouch() -> void:
	var dash := player.dash
	var free := (not player.climb.is_climbing and not player.climb.is_attached and not player.punch.is_punching()
			and dash.dash_timer <= 0.0 and dash.windup_timer <= 0.0 and not dash.is_diving
			and dash.dive_land_timer <= 0.0 and roll_timer <= 0.0 and not is_sliding
			and not player.slope.is_slope_sliding)
	var trapped := is_low() and not can_stand()
	# A jump charge holds the crouch on its own once Down is let go.
	is_crouching = free and player.is_on_floor() and (Input.is_action_pressed("crouch") or trapped or is_charging_jump)
	set_low(is_crouching or roll_timer > 0.0 or is_sliding or trapped)


func is_low() -> bool:
	return player.body_shape.shape == crouch_shape


# The box keeps its bottom edge at the feet (the origin) whichever
# height it is, so changing height never lifts or sinks the player.
func set_low(low: bool) -> void:
	var shape := crouch_shape if low else player.standing_shape
	var body_shape := player.body_shape
	if body_shape.shape == shape:
		return
	body_shape.shape = shape
	body_shape.position.y = -shape.size.y * 0.5


# Whether the standing box fits here. Lifted 1px so the floor under the
# feet doesn't count.
func can_stand() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = stand_probe_shape
	query.transform = Transform2D(0.0, player.global_position
			+ Vector2(0.0, -player.standing_shape.size.y * 0.5 - 1.0))
	query.collision_mask = player.collision_mask
	var exclude: Array[RID] = [player.get_rid()]
	query.exclude = exclude
	return player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func reset() -> void:
	is_crouching = false
	is_charging_jump = false
	slide_coyote_timer = 0.0
	roll_timer = 0.0
	is_sliding = false
	set_low(false)
