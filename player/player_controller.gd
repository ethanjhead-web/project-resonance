extends CharacterBody2D

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
@export var can_dash: bool = true
@export var can_wall_jump: bool = true
@export var can_ledge_grab: bool = true
@export var can_climb: bool = true

# Horizontal movement
@export var max_speed: float = 120.0
@export var acceleration: float = 1000.0
@export var friction: float = 900.0
@export var air_acceleration: float = 650.0

# Vertical movement
@export var jump_velocity: float = -360.0
@export var gravity: float = 900.0
@export var fall_gravity_multiplier: float = 1.6
@export var max_fall_speed: float = 420.0
@export var jump_cut_multiplier: float = 0.45

# Forgiveness windows (in seconds)
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

# Dash. Eight directions like Celeste, read from the held direction
# (facing if nothing is held). Speed x duration is the distance (~45px,
# just under 3 tiles) in every direction - diagonals aren't faster.
# Gravity is suspended for the whole dash so it reads as a committed,
# straight line rather than a hop.
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.25
# An upward dash hands back only this share of its exit speed, so it
# carries on rising a little instead of stalling dead at the end, but
# doesn't turn into a second jump. 0.75 is Celeste's value.
@export var dash_end_up_multiplier: float = 0.75

# Wall slide and wall jump
@export var wall_slide_speed: float = 60.0
# A slide only starts if the wall carries on at least this far below
# the feet. A small block is barely taller than the player, so the
# whole body is against it for just a few frames - without this it
# flashes a slide pose and drops off again.
@export var wall_slide_min_length: float = 8.0
# x pushes away from the wall, y is the upward kick. The push is faster
# than max_speed so a wall jump visibly launches you off the wall.
@export var wall_jump_velocity: Vector2 = Vector2(160.0, -330.0)
# Input is ignored this long after a wall jump. Without it, holding
# toward the wall cancels the push on the very next frame and the jump
# looks like it went straight up.
@export var wall_jump_lock_time: float = 0.14
# Same idea as coyote_time: a jump pressed just after drifting off a
# wall still counts as a wall jump.
@export var wall_coyote_time: float = 0.1
@export var wall_check_distance: float = 2.0

# Wall climb (Celeste-style: hold grab against a wall). Speeds are
# Celeste's, scaled by our run speed so the climb keeps the same
# relationship to running that it has there.
@export var climb_up_speed: float = 60.0
@export var climb_down_speed: float = 110.0
# Stamina is measured in seconds of climbing upward. It only refills on
# the ground, which is what turns a wall into a route you plan rather
# than a place you can rest.
@export var climb_stamina: float = 3.0
# Drain per second while holding still, relative to climbing up. 0.22
# is Celeste's ratio: clinging buys time, climbing spends it.
@export var climb_hold_drain: float = 0.22
# Stamina cost of a climb jump (straight up off the wall). Celeste's
# cost is a quarter of the full bar.
@export var climb_jump_cost: float = 0.75
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

# Below this horizontal speed the run animation hands back to idle, so
# the last few pixels of deceleration don't play a stuttery run cycle.
@export var run_anim_threshold: float = 10.0

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var spawn_position: Vector2
var facing: float = 1.0

var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
# One dash per trip through the air, refilled on the ground or a wall.
var has_air_dash: bool = true

var wall_coyote_timer: float = 0.0
var last_wall_side: int = 0
var wall_jump_lock_timer: float = 0.0
var is_wall_sliding: bool = false

var is_climbing: bool = false
var climb_side: int = 0
var stamina: float = 0.0

enum LedgeState { NONE, HANGING, CLIMBING }
var ledge_state: LedgeState = LedgeState.NONE
var ledge_side: int = 0
var ledge_corner: Vector2
var ledge_timer: float = 0.0
var ledge_regrab_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	spawn_position = global_position
	stamina = climb_stamina


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	_update_tired_tint()

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

	# Coyote time: a short grace window after walking off a ledge
	# where a jump still counts, so near-misses feel fair.
	if is_on_floor():
		coyote_timer = coyote_time
		has_air_dash = true
		stamina = climb_stamina
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

	dash_cooldown_timer -= delta
	if (can_dash and Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0
			and (is_on_floor() or has_air_dash)):
		_start_dash(direction, Input.get_axis("move_up", "crouch"))

	# A jump during a dash cancels it rather than waiting it out. The
	# dash is longer than the jump buffer, so otherwise an early press
	# would expire mid-dash and feel eaten.
	if dash_timer > 0.0 and jump_buffer_timer > 0.0 and (coyote_timer > 0.0 or wall_coyote_timer > 0.0):
		_end_dash()

	if not is_climbing and dash_timer <= 0.0 and _can_start_climb(direction):
		_start_climb()

	if dash_timer > 0.0:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
		if dash_timer <= 0.0:
			_end_dash()
	elif is_climbing:
		_apply_climb(direction, delta)
	else:
		_apply_movement(direction, wall_side, delta)

	# Floor state has to be read before move_and_slide() updates it,
	# otherwise there's no way to tell that we only just touched down.
	var was_on_floor := is_on_floor()
	move_and_slide()

	# A dash only ends early when it's fully blocked - straight into a
	# wall, floor or ceiling. A diagonal that meets a surface slides along
	# it instead (up a wall, along the floor), the way Celeste's does.
	if dash_timer > 0.0 and get_real_velocity().length() < dash_speed * 0.1:
		_end_dash()

	# Checked after moving so the ledge test uses this frame's position.
	# Only on the way down (or flat, mid-dash): grabbing while rising
	# would interrupt jumps that were already going to clear the ledge.
	# Climbing up is the exception - reaching the top of a wall hands off
	# to the ledge hang, and holding Up then mounts it. Catching needs
	# grab held, like the climb, so ledges only stop the player when
	# they ask to be stopped.
	if (can_ledge_grab and ledge_regrab_timer <= 0.0 and not is_on_floor()
			and Input.is_action_pressed("grab")
			and (velocity.y >= 0.0 or is_climbing) and _try_grab_ledge(int(facing))):
		return

	_update_animation(direction, wall_side, was_on_floor)


func _apply_movement(direction: float, wall_side: int, delta: float) -> void:
	# Horizontal movement. Air acceleration is separate from ground
	# acceleration so you can give the player less control mid-air
	# if you want that heavier, committed-to-the-jump feeling.
	if wall_jump_lock_timer > 0.0:
		wall_jump_lock_timer -= delta
	else:
		var target_speed := direction * max_speed
		var accel := acceleration if is_on_floor() else air_acceleration
		if direction != 0.0:
			velocity.x = move_toward(velocity.x, target_speed, accel * delta)
			facing = signf(direction)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# Asymmetric gravity: falling pulls harder than rising. This is
	# most of what separates "weighty" from "floaty" - it stops the
	# character hanging at the top of a jump arc.
	if velocity.y < 0.0:
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
		velocity.y = min(velocity.y, wall_slide_speed)
		has_air_dash = true
	else:
		velocity.y = min(velocity.y, max_fall_speed)

	# Ground jump takes priority so standing next to a wall never
	# turns a normal jump into a wall jump.
	if jump_buffer_timer > 0.0:
		if coyote_timer > 0.0:
			velocity.y = jump_velocity
			_consume_jump()
		elif wall_coyote_timer > 0.0:
			_wall_jump(last_wall_side)

	# Variable jump height: releasing the button early cuts the
	# jump short, so tapping gives a hop and holding gives full height.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _wall_jump(side: int) -> void:
	velocity = Vector2(-side * wall_jump_velocity.x, wall_jump_velocity.y)
	facing = -side
	wall_jump_lock_timer = wall_jump_lock_time
	is_wall_sliding = false
	_consume_jump()


# Celeste's grab rules: hold grab, face a wall, and not be rising - so a
# jump past a wall isn't snagged on the way up, but you catch at the
# apex. On the ground it also needs Up, otherwise holding grab while
# walking along a wall would stick you to it. The wall has to cover the
# whole body (same test as the wall slide): with only the feet against
# it, the hands would be gripping empty air above the top. Above a
# wall's top, holding grab catches the ledge instead.
func _can_start_climb(direction: float) -> bool:
	if not can_climb or stamina <= 0.0 or not Input.is_action_pressed("grab"):
		return false
	if velocity.y < 0.0 or not _is_wall_full_height(int(facing)):
		return false
	# Moving away from the wall means the player is leaving it.
	if direction != 0.0 and signf(direction) != facing:
		return false
	return not is_on_floor() or Input.is_action_pressed("move_up")


func _start_climb() -> void:
	is_climbing = true
	climb_side = int(facing)
	is_wall_sliding = false
	wall_jump_lock_timer = 0.0
	velocity = Vector2.ZERO


func _apply_climb(direction: float, delta: float) -> void:
	# Once on, the hands are all that has to stay on the wall - the
	# player can climb down until they're hanging from the bottom edge
	# by their arms, feet dangling below it.
	if not Input.is_action_pressed("grab") or not _is_wall_at_hands(climb_side):
		# Let go, or the hands left the wall: climbed down past its
		# bottom, or up past a top with no room to stand (where there is
		# room, the ledge grab takes over first).
		is_climbing = false
		_apply_movement(direction, 0, delta)
		return
	# Standing on the ground with no Up held: back to walking.
	if is_on_floor() and not Input.is_action_pressed("move_up"):
		is_climbing = false
		_apply_movement(direction, 0, delta)
		return

	if jump_buffer_timer > 0.0:
		is_climbing = false
		if direction != 0.0 and signf(direction) == -climb_side:
			_wall_jump(climb_side)
		else:
			# Climb jump: straight up the wall for a chunk of stamina.
			# Grab held through it re-catches at the apex, which is how
			# Celeste lets you scale a wall faster than climbing.
			velocity = Vector2(0.0, jump_velocity)
			stamina -= climb_jump_cost
			_consume_jump()
		return

	var vertical := Input.get_axis("move_up", "crouch")
	if vertical < 0.0:
		velocity.y = -climb_up_speed
		stamina -= delta
	elif vertical > 0.0:
		# Sliding down is free, so a tired player can still back off.
		velocity.y = climb_down_speed
	else:
		velocity.y = 0.0
		stamina -= climb_hold_drain * delta
	# A small push into the wall keeps move_and_slide() in contact with it.
	velocity.x = climb_side * 10.0

	if stamina <= 0.0:
		stamina = 0.0
		is_climbing = false


# Soft red pulse while climbing on low stamina. It's a tint fade rather
# than a hard flash, and slower than 3 per second, so it stays well clear
# of photosensitivity limits.
func _update_tired_tint() -> void:
	if is_climbing and stamina < climb_tired_threshold:
		var pulse := (sin(Time.get_ticks_msec() / 1000.0 * TAU * 2.0) + 1.0) * 0.5
		sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.35, 0.35), pulse)
	else:
		sprite.modulate = Color.WHITE


func _consume_jump() -> void:
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	wall_coyote_timer = 0.0


func _start_dash(direction: float, vertical: float) -> void:
	# Snapped to eight directions: the stick's exact angle is ignored, so
	# a slightly-off diagonal still dashes at a clean 45 degrees.
	var dir := Vector2(signf(direction), signf(vertical))
	if dir == Vector2.ZERO:
		dir.x = facing
	# Off a wall the held direction points into it, which would end the
	# dash on its first frame. Flip that part away from the wall, so
	# toward-and-up from a climb becomes away-and-up.
	var wall := 0
	if is_wall_sliding:
		wall = last_wall_side
	elif is_climbing:
		wall = climb_side
	if wall != 0 and dir.x == wall:
		dir.x = -wall
	dash_direction = dir.normalized()
	is_climbing = false
	if dir.x != 0.0:
		facing = dir.x
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	has_air_dash = false
	wall_jump_lock_timer = 0.0
	is_wall_sliding = false


func _end_dash() -> void:
	dash_timer = 0.0
	# Hand back at run speed rather than dash speed, so the player
	# doesn't skate on after the dash visibly ends.
	velocity = dash_direction * max_speed
	if velocity.y < 0.0:
		velocity.y *= dash_end_up_multiplier


# Looks for a grabbable ledge on `side` with three physics probes rather
# than reading tiles, so it works on any collision shape - tiles,
# moving platforms, whatever comes later.
func _try_grab_ledge(side: int) -> bool:
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
		return false
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
		return false
	var corner := Vector2(wall_x, top_hit.position.y)

	# 3. Room to stand on top, so the climb can't end inside a ceiling.
	# Lifted 1px so resting on the ledge's own surface doesn't count.
	var stand_query := PhysicsShapeQueryParameters2D.new()
	stand_query.shape = body_shape.shape
	stand_query.transform = Transform2D(0.0,
			corner + Vector2(side * ledge_stand_inset, -1.0) + body_shape.position)
	stand_query.collision_mask = collision_mask
	stand_query.exclude = exclude
	if not space.intersect_shape(stand_query, 1).is_empty():
		return false

	ledge_state = LedgeState.HANGING
	ledge_side = side
	ledge_corner = corner
	ledge_timer = 0.0
	global_position = corner - Vector2(side * ledge_hand_offset.x, ledge_hand_offset.y)
	velocity = Vector2.ZERO
	dash_timer = 0.0
	is_wall_sliding = false
	is_climbing = false
	has_air_dash = true
	# The ledge sheet is drawn holding a ledge on the right.
	sprite.flip_h = side < 0
	_play("ledge_hang")
	return true


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
	var size: Vector2 = (body_shape.shape as RectangleShape2D).size
	var top := global_position.y + body_shape.position.y - size.y * 0.5
	# Inset 1px from the top edge (and the feet ray from the bottom edge)
	# so a ray lying exactly on a tile seam doesn't count.
	return _is_wall_at(side, top + 1.0)


func _is_wall_at(side: int, y: float) -> bool:
	var size: Vector2 = (body_shape.shape as RectangleShape2D).size
	var ray := PhysicsRayQueryParameters2D.create(
			Vector2(global_position.x, y),
			Vector2(global_position.x + side * (size.x * 0.5 + wall_check_distance), y),
			collision_mask, [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _is_wall(side: int) -> bool:
	var collision := KinematicCollision2D.new()
	if test_move(global_transform, Vector2(side * wall_check_distance, 0.0), collision):
		return absf(collision.get_normal().x) > 0.7
	return false


func _update_animation(direction: float, wall_side: int, was_on_floor: bool) -> void:
	if dash_timer > 0.0:
		# The pack only has a sideways dash pose. Straight up or down
		# borrow the jump and fall poses, since rotating pixel art off
		# the 90-degree grid would make it jaggy.
		if dash_direction.x == 0.0:
			_play("jump" if dash_direction.y < 0.0 else "fall")
		else:
			sprite.flip_h = dash_direction.x < 0.0
			_play("dash")
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

	if is_wall_sliding:
		# The wall sheets are drawn against a wall on the right.
		sprite.flip_h = wall_side < 0
		if sprite.animation != "wall_land" and sprite.animation != "wall_slide":
			_play("wall_land")
		elif sprite.animation == "wall_land" and not sprite.is_playing():
			_play("wall_slide")
		return

	# Facing only changes on input, not velocity, so skidding to a stop
	# after reversing doesn't flicker the sprite back and forth.
	sprite.flip_h = facing < 0.0

	if not is_on_floor():
		_play("jump" if velocity.y < 0.0 else "fall")
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

	_play("run" if moving else "idle")


# play() restarts a non-looping animation if called again with the same
# name, which would freeze jump/fall on their first frame. Guard it.
func _play(anim: StringName) -> void:
	if sprite.animation != anim:
		sprite.play(anim)


func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	dash_timer = 0.0
	wall_jump_lock_timer = 0.0
	is_wall_sliding = false
	has_air_dash = true
	ledge_state = LedgeState.NONE
	is_climbing = false
	stamina = climb_stamina
