class_name PlayerRope
extends Node

# Rope swing. Hold grab to catch a SwingRope anywhere along it; the hands
# go where the catch box (centred on them) met the rope. The swing is a
# pendulum from the anchor to the hands, using the player's gravity.

@export_flags_2d_physics var rope_mask: int = 8
@export var rope_catch_size: Vector2 = Vector2(16.0, 16.0)
# Up climbs the hands along the rope; Down slides them at rope_slide_speed,
# quicker than a wall slide so dropping to the end of the rope (or off it)
# doesn't drag. They stop rope_min_hold below the anchor, so the head
# stays clear of the ceiling.
@export var rope_climb_speed: float = 60.0
@export var rope_slide_speed: float = 120.0
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

# The pull frame held on a rope while pressing away from facing: the more
# upright of the leans, legs together and bent.
const ROPE_PULL_FRAME := 2

# The rope being held, or null. swing_distance is how far down it the
# hands are.
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
var rope_regrab_timer: float = 0.0
var rope_regrab_rope: SwingRope = null

@onready var player := get_parent() as Player


# Runs the swing, which owns the body while a rope is held. Returns false,
# doing nothing else, when no rope is.
func update(direction: float, delta: float) -> bool:
	rope_regrab_timer -= delta
	if swing_rope == null:
		return false
	_process_swing(direction, delta)
	return true


# Where the hands are relative to the feet: the hang pose's, since the
# swing borrows the ledge hang art (drawn holding on to the right).
func rope_hand_offset() -> Vector2:
	var offset := player.ledge.ledge_hand_offset
	return Vector2(player.facing * offset.x, offset.y)


func try_catch_rope() -> bool:
	var hands := player.global_position + rope_hand_offset()
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
	for hit in player.get_world_2d().direct_space_state.intersect_shape(query, 4):
		var candidate := hit.collider as SwingRope
		if candidate != null and not (candidate == rope_regrab_rope and rope_regrab_timer > 0.0):
			rope = candidate
			break
	if rope == null:
		return false

	swing_rope = rope
	player.is_carrying_momentum = false
	rope.held = true
	swing_distance = clampf((hands - rope.global_position).dot(rope.direction()), rope_min_hold, rope.length)
	# The swing starts from the speed the player brought across the rope,
	# added to the rope's own: a dash into it swings hard, a jump up from
	# underneath (all speed along the rope) barely moves it, and catching
	# a rope swinging toward you cancels some of it.
	var along := rope.direction()
	var w := rope.angular_velocity + player.velocity.dot(Vector2(along.y, -along.x)) / swing_distance
	# No higher than a full pump could take it, so a fast catch can't send
	# the swing over the top of the anchor.
	w = _cap_swing(rope.angle, w)
	rope.set_swing(rope.angle, w)
	swing_pass_side = signf(w)
	pump_this_pass = 0.0
	pump_spent_side = 0.0
	# The jump that reached the rope is still in the buffer, and would
	# otherwise fire as a jump off it on the first swing frame.
	player.jump_buffer_timer = 0.0
	player.velocity = Vector2.ZERO
	player.dash.dash_timer = 0.0
	player.wall_jump_lock_timer = 0.0
	player.is_wall_sliding = false
	player.is_wall_running = false
	player.climb.is_climbing = false
	# The swing skips the rest of _physics_process, so a punch thrown into
	# the rope would otherwise never get cleaned up.
	player.punch.end_attack()
	_follow_rope()
	_update_swing_animation(0.0, 0.0)
	player.anim.tilt_sprite(-rope.angle)
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
	if player.jump_buffer_timer > 0.0:
		_release_rope(true)
		return

	# Turn to hold on from the other side, if there's room for the body
	# there. Facing is otherwise fixed for the whole swing.
	if Input.is_action_just_pressed("turn"):
		var hands := rope.global_position + rope.direction() * swing_distance
		var offset := player.ledge.ledge_hand_offset
		var turned := Vector2(-player.facing * offset.x, offset.y)
		if not player.test_move(player.global_transform, hands - turned - player.global_position):
			player.facing = -player.facing

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
	var rope_speed := rope_climb_speed if vertical < 0.0 else rope_slide_speed
	var slid_to := swing_distance + vertical * rope_speed * delta
	# Sliding down past the end of the rope drops off it, grab or not, so
	# Down is a way off that keeps the rope's swing.
	if vertical > 0.0 and slid_to > rope.length:
		_release_rope(false)
		player.velocity += rope.direction() * rope_slide_speed * vertical
		return
	var new_distance := clampf(slid_to, rope_min_hold, rope.length)
	var climbed := new_distance - swing_distance
	swing_distance = new_distance

	var gravity := player.gravity
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
	player.anim.tilt_sprite(-rope.angle)


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
	var w_max := sqrt(2.0 * player.gravity * (cos(a) - cos(cap)) / _swing_length())
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
	var sprite := player.sprite
	sprite.speed_scale = 1.0
	sprite.flip_h = player.facing < 0.0
	if _in_release_window():
		player.anim.play(&"ledge_hang")
	elif climbed < 0.0:
		sprite.play(&"climb")
	elif climbed > 0.0:
		# Sliding down: the climb frame it was on, frozen.
		if sprite.animation != &"climb":
			sprite.animation = &"climb"
		sprite.pause()
	elif direction != 0.0 and signf(direction) == -player.facing:
		player.anim.hold_frame(&"pull", ROPE_PULL_FRAME)
	else:
		player.anim.hold_frame(&"climb", 0)


# The swing's full height in radians, from its energy (as in the pump
# check), so it's known anywhere in the pass, not just at the peak.
func _swing_height() -> float:
	var a := swing_rope.angle
	var w := swing_rope.angular_velocity
	return acos(clampf(cos(a) - w * w * _swing_length() / (2.0 * player.gravity), -1.0, 1.0))


# True in the outer third of a full swing on the side the player faces,
# either way through, on a big enough swing. The swing's full height comes from
# its energy, as in the pump check.
func _in_release_window() -> bool:
	var a := swing_rope.angle
	if signf(a) != player.facing:
		return false
	if absf(a) < deg_to_rad(rope_max_angle) / 3.0:
		return false
	return _swing_height() >= deg_to_rad(rope_release_min_swing)


# Moves the body so the hands sit on the rope. False if something solid
# got in the way first.
func _follow_rope() -> bool:
	var hands := swing_rope.global_position + swing_rope.direction() * swing_distance
	return player.move_and_collide(hands - rope_hand_offset() - player.global_position) == null


# Lets go with the swing's speed. A jump adds lift and briefly locks air
# steering so the launch carries; a plain release just drops.
func _release_rope(jump: bool) -> void:
	var in_window := _in_release_window()
	player.velocity = _rope_tangent() * swing_rope.angular_velocity * swing_distance
	if jump:
		# At least the boost upward, so a jump on the downswing still rises.
		player.velocity.y = minf(player.velocity.y, 0.0) + rope_jump_boost
		player.velocity.x *= rope_jump_carry
		if in_window:
			player.velocity.x += player.facing * rope_window_jump_boost
		player.wall_jump_lock_timer = rope_release_lock_time
		if player.velocity.x != 0.0:
			player.facing = signf(player.velocity.x)
		player.consume_jump()
		player.anim.start_air_spin()
	swing_rope.held = false
	rope_regrab_rope = swing_rope
	rope_regrab_timer = rope_regrab_delay
	swing_rope = null
	player.air_sprint = false


func reset() -> void:
	if swing_rope != null:
		swing_rope.held = false
		swing_rope = null
