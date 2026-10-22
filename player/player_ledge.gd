class_name PlayerLedge
extends Node

# Ledge grab, hang and climb, and the mount straight off a wall run.

# Where the fingertips sit relative to the feet in the hang frame. The
# hang snaps so this point lands exactly on the ledge corner, which is
# what makes it read as holding on rather than floating near the wall.
# The rope swing borrows it for where the hands are.
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

enum LedgeState { NONE, HANGING, CLIMBING }
var ledge_state: LedgeState = LedgeState.NONE
var ledge_side: int = 0
var ledge_corner: Vector2
var ledge_timer: float = 0.0
var ledge_regrab_timer: float = 0.0

@onready var player := get_parent() as Player


func is_on_ledge() -> bool:
	return ledge_state != LedgeState.NONE


# Runs the hang or the climb, which own the body while they last.
# Returns false, doing nothing else, when neither is running.
func update(direction: float, delta: float) -> bool:
	ledge_regrab_timer -= delta
	if ledge_state == LedgeState.HANGING:
		_process_ledge_hang(direction, delta)
		return true
	if ledge_state == LedgeState.CLIMBING:
		_process_ledge_climb(delta)
		return true
	return false


func try_grab_ledge(side: int) -> bool:
	var corner: Variant = _find_ledge(side)
	if corner == null:
		return false
	_snap_to_ledge(side, corner)
	player.anim.play("ledge_hang")
	return true


# Straight from wherever the body is into the ledge climb, no hang.
func try_mount_ledge(side: int) -> bool:
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
	var space := player.get_world_2d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	var position := player.global_position
	var hands_y := position.y + ledge_hand_offset.y
	# Just below the lowest ledge top we'd accept, so it hits wall face.
	var probe_y := hands_y + ledge_snap_range + 1.0

	# 1. A wall face in front of the body.
	var wall_ray := PhysicsRayQueryParameters2D.create(
			Vector2(position.x, probe_y),
			Vector2(position.x + side * (ledge_hand_offset.x + ledge_reach), probe_y),
			player.collision_mask, exclude)
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
			player.collision_mask, exclude)
	var top_hit := space.intersect_ray(top_ray)
	if top_hit.is_empty() or top_hit.normal.y > -0.7:
		return null
	var corner := Vector2(wall_x, top_hit.position.y)

	# 3. Room to stand on top, so the climb can't end inside a ceiling.
	# Lifted 1px so resting on the ledge's own surface doesn't count.
	var standing_shape := player.standing_shape
	var stand_query := PhysicsShapeQueryParameters2D.new()
	stand_query.shape = standing_shape
	stand_query.transform = Transform2D(0.0,
			corner + Vector2(side * ledge_stand_inset, -1.0 - standing_shape.size.y * 0.5))
	stand_query.collision_mask = player.collision_mask
	stand_query.exclude = exclude
	if not space.intersect_shape(stand_query, 1).is_empty():
		return null
	return corner


# Puts the body in the hang pose on the ledge at `corner`.
func _snap_to_ledge(side: int, corner: Vector2) -> void:
	player.is_carrying_momentum = false
	ledge_state = LedgeState.HANGING
	ledge_side = side
	ledge_corner = corner
	ledge_timer = 0.0
	player.global_position = corner - Vector2(side * ledge_hand_offset.x, ledge_hand_offset.y)
	player.velocity = Vector2.ZERO
	player.dash.dash_timer = 0.0
	player.is_wall_sliding = false
	player.is_wall_running = false
	player.climb.is_climbing = false
	# The hang skips the rest of _physics_process, so a punch thrown
	# into the ledge would otherwise never get cleaned up.
	player.punch.end_attack()
	# The ledge sheet is drawn holding a ledge on the right.
	player.sprite.flip_h = side < 0


func _process_ledge_hang(direction: float, delta: float) -> void:
	ledge_timer += delta
	player.velocity = Vector2.ZERO
	var away := direction != 0.0 and signf(direction) != ledge_side

	# Releasing grab lets go, the same as on a climb.
	if away or Input.is_action_pressed("crouch") or not Input.is_action_pressed("grab"):
		# A jump pressed while hanging is discarded on the way down,
		# otherwise it would fire as a wall jump the moment we let go.
		player.jump_buffer_timer = 0.0
		_release_ledge()
		player.anim.play("fall")
	# Up or a fresh jump press mounts, never toward the wall. Toward is
	# usually already held when the grab happens, so it would mount
	# instantly. Jump uses the buffer (a press, not a hold) so a jump
	# held from before the catch doesn't mount on its own; a press
	# during the catch window is kept until the window ends.
	elif ledge_timer >= ledge_catch_time and (Input.is_action_pressed("move_up") or player.jump_buffer_timer > 0.0):
		player.jump_buffer_timer = 0.0
		_start_ledge_climb()


func _release_ledge() -> void:
	ledge_state = LedgeState.NONE
	ledge_regrab_timer = ledge_regrab_delay


func _start_ledge_climb() -> void:
	ledge_state = LedgeState.CLIMBING
	ledge_timer = 0.0
	# The climb art is drawn in place and the body is moved in code, so
	# the animation is stretched to last exactly as long as the movement.
	var sprite := player.sprite
	var frames := sprite.sprite_frames
	var anim_length := frames.get_frame_count(&"ledge_climb") / frames.get_animation_speed(&"ledge_climb")
	# speed_scale multiplies on top of that stretch, and nothing else resets
	# it here: update_animation() doesn't run during a ledge climb. Left at
	# the wall run's sped-up value, the poses would finish early and freeze
	# on the last frame while the body was still mid-climb.
	sprite.speed_scale = 1.0
	sprite.play(&"ledge_climb", anim_length / ledge_climb_time)


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
	player.global_position = ledge_corner + Vector2(local.x * ledge_side, local.y)
	# No jumping out of the climb: a press during it is dropped rather than
	# buffered, so it can't fire the moment the climb ends.
	player.jump_buffer_timer = 0.0
	if t >= 1.0:
		ledge_state = LedgeState.NONE
		player.velocity = Vector2.ZERO
		# The hang and climb skip the timer updates, so wall coyote is still
		# frozen at whatever the slide or wall run left it, and is_on_floor()
		# is stale until the next move_and_slide(). Without this the first
		# jump off the top is a wall jump back off the ledge. Standing on
		# the top, it should be a plain ground jump in any direction.
		player.wall_coyote_timer = 0.0
		player.coyote_timer = player.coyote_time
		# Same for a wall jump's steering lock left over from before the catch.
		player.wall_jump_lock_timer = 0.0


func reset() -> void:
	ledge_state = LedgeState.NONE
