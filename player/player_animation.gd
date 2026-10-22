class_name PlayerAnimation
extends Node

# Picks the animation for whatever the body is doing, once it has moved
# each frame, and owns the sprite's lean (on a rope or a slope) and the
# somersault. Moves that start their own animation (a punch, a roll, the
# ledge climb, the rope poses) play it themselves and are left alone here.
# The ability glow is the Dash component's (update_tint()).

# The crouch frame held while a jump charges: the crouch idle is a
# breathing loop, and this is where the head sits lowest, so the body
# reads as coiled rather than resting.
const CHARGE_CROUCH_FRAME := 3

# A jump off a rope or slope, or a slide jump, somersaults (air_spin, once
# through) before handing back to the usual jump and fall poses.
var is_air_spinning: bool = false

@onready var player := get_parent() as Player
@onready var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")


func update_animation(direction: float, wall_side: int, was_on_floor: bool) -> void:
	var dash := player.dash
	var crouch := player.crouch
	var climb := player.climb
	var facing := player.facing
	var velocity := player.velocity
	# Only the run cycle speeds up with a sprint; everything else plays
	# at its authored rate.
	sprite.speed_scale = 1.0
	# Frozen on whatever frame was showing. speed_scale rather than
	# pause(), so the move's own animation still starts cleanly after.
	if dash.windup_timer > 0.0:
		sprite.flip_h = facing < 0.0
		sprite.speed_scale = 0.0
		return
	if dash.dash_timer > 0.0:
		sprite.flip_h = dash.dash_direction < 0.0
		play("dash")
		return

	# No dive art in the pack yet, so it borrows the fall pose. The
	# landing recovery holds land's deepest crouch (frame 0) for the whole
	# of dive_land_time to sell the impact, then stands up through the
	# rest of the sheet like a normal landing.
	if dash.is_diving:
		sprite.flip_h = facing < 0.0
		play("fall")
		return
	if dash.dive_land_timer > 0.0:
		sprite.flip_h = facing < 0.0
		play("land")
		sprite.frame = 0
		sprite.pause()
		return
	if dash.dive_land_timer_just_ended:
		dash.dive_land_timer_just_ended = false
		# play() resumes a paused animation where it stopped, so this
		# carries on from the crouch frame. The usual landing rule below
		# then lets any movement cancel the stand-up.
		sprite.play("land")

	# The punch plays itself out from its own start; just hold it here.
	if player.punch.is_punching():
		return
	# Likewise the roll, from crouch.try_start_ground_move().
	if crouch.roll_timer > 0.0:
		return
	if crouch.is_sliding:
		sprite.flip_h = velocity.x < 0.0
		play("slide")
		return
	if player.slope.is_slope_sliding:
		sprite.flip_h = facing < 0.0
		play("slide")
		lean_on_slope(true)
		return

	if climb.is_climbing:
		# The climb sheet is drawn against a wall on the right. The cycle
		# runs forwards going up, backwards going down, and holds its
		# frame while clinging.
		sprite.flip_h = climb.climb_side < 0
		if sprite.animation != "climb":
			sprite.play("climb")
		if velocity.y < 0.0:
			sprite.play("climb")
		elif velocity.y > 0.0:
			sprite.play_backwards("climb")
		else:
			sprite.pause()
		return

	if player.is_wall_running:
		# Borrows the climb cycle, sped up so the limbs keep pace with
		# the body the way the sprint does with the run cycle.
		sprite.flip_h = player.wall_run_side < 0
		sprite.play("climb")
		sprite.speed_scale = maxf(1.0, -velocity.y / climb.climb_up_speed)
		return

	if climb.is_attached:
		# All three sheets are drawn holding on to the right, and their
		# AtlasTexture margins put the hands on the wall face.
		sprite.flip_h = climb.attach_side < 0
		var pose := int(signf(direction))
		play("push" if pose == climb.attach_side else "pull" if pose == -climb.attach_side else "push_idle")
		return

	if player.is_wall_sliding:
		# The wall sheets are drawn against a wall on the right. Straight
		# into the slide, with no wall_land lead-in: the impact pose
		# delayed the slide reading and made the wall feel sticky.
		sprite.flip_h = wall_side < 0
		play("wall_slide")
		return

	# The somersault plays through once in the air. Anything above here
	# that takes over the sprite (a wall slide, a dash, a punch) cuts it
	# off, and so does landing.
	if is_air_spinning:
		if not player.is_on_floor() and sprite.animation == &"air_spin" and sprite.is_playing():
			return
		is_air_spinning = false

	# Facing only changes on input, not velocity, so skidding to a stop
	# after reversing doesn't flicker the sprite back and forth.
	sprite.flip_h = facing < 0.0
	# Running up a slope: the upright box rests on its uphill corner, so
	# the feet would float above the surface without this.
	if player.is_on_floor() and player.slope.slide_slope_normal() != Vector2.ZERO:
		lean_on_slope(false)

	if not player.is_on_floor():
		play("jump" if velocity.y < 0.0 else "fall")
		return

	# Frozen on one frame, like the windup, so the charge reads as power
	# being held in rather than the idle breathing.
	if crouch.is_charging_jump:
		hold_frame(&"crouch_idle", CHARGE_CROUCH_FRAME)
		return
	# Ahead of the push and landing checks, so crawling into a wall or
	# landing with Down held goes straight into the crouch poses.
	if crouch.is_crouching:
		play("crouch_walk" if absf(velocity.x) > player.run_anim_threshold else "crouch_idle")
		return

	# Running into a wall pushes against it instead. Without this the run
	# cycle stutters: move_and_slide() zeroes velocity on frames where it
	# registers the wall and not on others, so the speed check flickers.
	# The wall probe is used instead of is_on_wall(), which flickers too.
	if direction != 0.0 and player.touching_wall_side() == int(signf(direction)):
		play("push")
		return

	var moving := absf(velocity.x) > player.run_anim_threshold

	# Landing recovery only plays when standing still. Any input cancels
	# it, because locking the player into an animation on touchdown
	# makes movement feel sluggish.
	if not was_on_floor and not moving:
		play("land")
		return
	if sprite.animation == "land" and sprite.is_playing() and not moving:
		return

	# Legs keep pace with the sprint so the feet don't skate.
	if moving:
		sprite.speed_scale = maxf(1.0, absf(velocity.x) / player.max_speed)
	play("run" if moving else "idle")


# play() restarts a non-looping animation if called again with the same
# name, which would freeze jump/fall on their first frame. Guard it.
func play(anim: StringName) -> void:
	if sprite.animation != anim:
		sprite.play(anim)


func hold_frame(anim: StringName, frame: int) -> void:
	if sprite.animation != anim:
		sprite.animation = anim
	sprite.pause()
	sprite.frame = frame


func start_air_spin() -> void:
	is_air_spinning = true
	sprite.speed_scale = 1.0
	sprite.flip_h = player.facing < 0.0
	sprite.play(&"air_spin")
	# The somersault turns the body over anyway, so it starts upright.
	tilt_sprite(0.0)


# Off a rope, the lean straightens out rather than snapping upright
# mid-fall. Also catches the slope run-up, which drops the sprite onto
# the slope without tilting it: at zero tilt this just puts it back.
func straighten(delta: float) -> void:
	if (player.rope.swing_rope == null
			and (sprite.rotation != 0.0 or sprite.position != player.sprite_base_position)):
		tilt_sprite(move_toward(sprite.rotation, 0.0, player.rope.rope_tilt_return_speed * delta))


# Leans the sprite by `tilt` radians about the hands (the body box stays
# upright; only the art turns). The rope's own rotation is -angle, so
# passing that lines the body up with it.
func tilt_sprite(tilt: float) -> void:
	var pivot := player.rope.rope_hand_offset()
	sprite.rotation = tilt
	sprite.position = pivot + (player.sprite_base_position - pivot).rotated(tilt)


# Tips the slide pose to lie along the slope, turned about the feet (or
# leaves it upright, for the run up). The upright body box rests on the
# slope by its uphill corner, which leaves the feet floating above the
# surface by half the box's width times the slope; the sprite drops by
# that much to sit on it.
func lean_on_slope(tilted: bool) -> void:
	var slope_normal := player.slope.slope_normal
	var tilt := atan2(absf(slope_normal.x), -slope_normal.y) * player.facing if tilted else 0.0
	var sink := player.standing_shape.size.x * 0.5 * absf(slope_normal.x / slope_normal.y)
	sprite.rotation = tilt
	sprite.position = player.sprite_base_position.rotated(tilt) + Vector2(0.0, sink)


func reset() -> void:
	tilt_sprite(0.0)
	is_air_spinning = false
