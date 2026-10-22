class_name PlayerClimb
extends Node

# Holding on to walls with grab: the Celeste-style climb on GripSurfaces
# (handholds included), and the attach from the ground, which pushes and
# pulls MovableBlocks. Walking into a block pushes it too.

# Wall climb (Celeste-style: hold grab against a wall). The climb up is
# Celeste's speed, scaled by our run speed so the climb keeps the same
# relationship to running that it has there. Down climbs down at the
# same pace with the cycle reversed, rather than sliding, so going down
# a wall is as deliberate as going up it.
@export var climb_up_speed: float = 60.0
# Physics layers holding GripSurface areas. Only walls marked with one
# can be climbed; slides, wall jumps and ledge grabs work on any wall.
@export_flags_2d_physics var grip_mask: int = 4
# Push and pull speed from an attach on a MovableBlock. Slow and even, so
# moving a block reads as effort rather than carrying it.
@export var push_speed: float = 44.0

var is_climbing: bool = false
var climb_side: int = 0
# Attached: holding onto a wall from the ground. Against a MovableBlock,
# toward pushes it and away pulls it.
var is_attached: bool = false
var attach_side: int = 0

@onready var player := get_parent() as Player


# Celeste's grab rules: hold grab, face a wall, and not be rising - so a
# jump past a wall isn't snagged on the way up, but you catch at the
# apex. On the ground it also needs Up (pressed from an attach), otherwise
# holding grab while walking along a wall would stick you to it. The wall has to be level
# with the hands: with only the feet against it, the hands would be
# gripping empty air above the top (near the top, holding grab catches
# the ledge instead). Feet don't need to touch, so the lower half of a
# small floating block can be grabbed with the legs hanging below.
func can_start_climb(direction: float) -> bool:
	if not player.can_climb or not Input.is_action_pressed("grab") or player.velocity.y < 0.0:
		return false
	if grip_at_hands(int(player.facing)) == null:
		return false
	# Moving away from the wall means the player is leaving it.
	if direction != 0.0 and signf(direction) != player.facing:
		return false
	return not player.is_on_floor() or Input.is_action_pressed("move_up")


func start_climb() -> void:
	player.is_carrying_momentum = false
	is_climbing = true
	is_attached = false
	climb_side = int(player.facing)
	player.is_wall_sliding = false
	player.wall_jump_lock_timer = 0.0
	player.velocity = Vector2.ZERO
	# A handhold is a single grip point, so the hands snap onto its middle
	# (it's taller than it looks, so a fast fall past it can't skip it in
	# one frame), and every catch hangs from the same spot.
	var grip := grip_at_hands(climb_side)
	if grip != null and grip.handhold:
		player.global_position.y += grip.global_position.y - player.hands_y()


func apply_climb(direction: float, delta: float) -> void:
	# The hands are all that has to stay on the wall, so the player can
	# climb down until hanging from the bottom edge by their arms.
	var grip := grip_at_hands(climb_side)
	if not Input.is_action_pressed("grab") or grip == null:
		# Let go, or the hands left the grip: climbed down past its
		# bottom (of the wall or of the GripSurface), or up past a top
		# with no room to stand (where there is room, the ledge grab
		# takes over first).
		is_climbing = false
		player.apply_movement(direction, 0, delta)
		return
	# Standing on the ground with no Up held: back to walking, or to an
	# attach if grab is still held and the wall is still at the hands.
	if player.is_on_floor() and not Input.is_action_pressed("move_up"):
		is_climbing = false
		if Input.is_action_pressed("grab") and player.is_wall_at_hands(climb_side):
			start_attach(climb_side)
			apply_attach(direction, delta)
		else:
			player.apply_movement(direction, 0, delta)
		return

	if player.jump_buffer_timer > 0.0:
		# Every jump off a climb is a wall jump. Celeste's straight-up
		# climb jump is left out on purpose: spamming it up a wall is a
		# rhythm-breaker, and climbing should be a steady, deliberate pace.
		is_climbing = false
		player.wall_jump(climb_side, true)
		return

	# A handhold can be hung from but not climbed: Up and Down do nothing,
	# and the way on is the full jump off it.
	if grip.handhold:
		player.velocity.y = 0.0
	else:
		player.velocity.y = Input.get_axis("move_up", "crouch") * climb_up_speed
	# A small push into the wall keeps move_and_slide() in contact with it.
	player.velocity.x = climb_side * 10.0


# Attach: a fresh grab press on the ground, facing a wall at the hands.
# A fresh press only, so grab held while walking along a wall doesn't
# stick the player to it. Any wall works, not just grip ones.
func try_start_attach(direction: float) -> void:
	var crouch := player.crouch
	var dash := player.dash
	if (not is_attached and not is_climbing and not crouch.is_crouching and crouch.roll_timer <= 0.0
			and not crouch.is_sliding and not player.slope.is_slope_sliding and player.is_on_floor()
			and Input.is_action_just_pressed("grab") and dash.dash_timer <= 0.0 and dash.windup_timer <= 0.0
			and dash.dive_land_timer <= 0.0 and not (direction != 0.0 and signf(direction) != player.facing)
			and player.is_wall_at_hands(int(player.facing))):
		start_attach(int(player.facing))


func start_attach(side: int) -> void:
	is_attached = true
	attach_side = side
	player.facing = side


# Facing locked to the wall, whatever the d-pad says. Against a plain
# wall toward and away only change the pose (push and pull) and the feet
# stay planted; against a MovableBlock they move the block and the player
# together. Letting go, a jump, or the wall or floor disappearing ends it.
func apply_attach(direction: float, delta: float) -> void:
	var held := player.wall_at(attach_side, player.hands_y())
	if (not Input.is_action_pressed("grab") or not player.is_on_floor() or player.jump_buffer_timer > 0.0
			or held == null):
		is_attached = false
		player.apply_movement(direction, 0, delta)
		return
	player.apply_attack_movement(delta)
	var block := held as MovableBlock
	if block == null or direction == 0.0:
		return
	var dx := signf(direction) * push_speed * delta
	# A pull walks the player backwards, so it stops at whatever is
	# behind them rather than dragging the block into their body.
	if signf(direction) == -attach_side and player.test_move(player.global_transform, Vector2(dx, 0.0)):
		return
	# The block moves first and the player follows exactly as far as it
	# went, so the hands stay on it even when it jams against a wall.
	player.velocity.x = block.slide(dx, player) / delta


# Walking into a MovableBlock pushes it at push_speed, the same as an
# attach push. Velocity is set outright rather than accelerated, because
# move_and_slide() zeroes it against the block every frame, and building
# up from zero each time left the push crawling. Any gap left from the
# approach (the probe reaches a little ahead) closes on the first frame.
func push_block_ahead(side: int, delta: float) -> void:
	var hit := player.wall_hit(side, player.hands_y())
	var block := hit.get("collider") as MovableBlock
	if block == null:
		return
	var half_width: float = (player.body_shape.shape as RectangleShape2D).size.x * 0.5
	var gap := maxf(absf(hit.position.x - player.global_position.x) - half_width, 0.0)
	player.velocity.x = (side * gap + block.slide(side * push_speed * delta, player)) / delta


# The GripSurface on a wall at the hands, or null if there isn't one.
# The point sits where the hand ray ends, just inside the wall face.
func grip_at_hands(side: int) -> GripSurface:
	if not player.is_wall_at_hands(side):
		return null
	var body_shape := player.body_shape
	var size: Vector2 = (body_shape.shape as RectangleShape2D).size
	var query := PhysicsPointQueryParameters2D.new()
	query.position = Vector2(player.global_position.x + side * (size.x * 0.5 + player.wall_check_distance),
			player.global_position.y + body_shape.position.y - size.y * 0.5 + 1.0)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = grip_mask
	var hits := player.get_world_2d().direct_space_state.intersect_point(query, 1)
	return null if hits.is_empty() else hits[0].collider as GripSurface


func reset() -> void:
	is_attached = false
	is_climbing = false
