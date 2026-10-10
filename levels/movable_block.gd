@tool
class_name MovableBlock
extends AnimatableBody2D

# A block the player can push and pull from an attach (hold grab against
# it on the ground). It's solid world geometry like any wall, so it can
# be stood on, wall jumped off and ledge grabbed, and it falls under its
# own gravity, so pushing it off a ledge drops it.
#
# Drawn with the tileset's 2x2 floating-block art, so it matches the
# fixed blocks, plus a blue bar on each side face to mark it as
# grabbable. Real art should mark that with a shape or texture too, not
# colour alone, so it reads for colour-blind players.

const SIZE := Vector2(32.0, 32.0)
const TILES := preload("res://assets/Tilemap (Super Basic)/Basic Tilemap.png")
# The pack's floating block: atlas tiles (1, 1) to (2, 2).
const BLOCK_REGION := Rect2(16.0, 16.0, 32.0, 32.0)

@export var gravity: float = 800.0
@export var max_fall_speed: float = 420.0
@export var bar_color := Color(0.25, 0.55, 1.0)
@export var bar_width: float = 3.0

var fall_speed: float = 0.0
# Set by slide(), cleared after each physics frame. The block only snaps
# to a whole pixel once nothing is pushing it.
var _pushed: bool = false


func _ready() -> void:
	# Moved from code with move_and_collide(), which sync_to_physics
	# doesn't support (it's meant for AnimationPlayer-driven platforms).
	sync_to_physics = false
	# Built in code like GripSurface's, so the shape always matches the art.
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	(shape.shape as RectangleShape2D).size = SIZE
	add_child(shape)


func _physics_process(delta: float) -> void:
	# @tool scripts run their physics in the editor too.
	if Engine.is_editor_hint():
		return
	# A kinematic body that moves only when pushed or falling. Running
	# move_and_slide() every frame against the floor and the player made
	# it creep by fractions of a pixel while it sat still.
	if _on_floor():
		fall_speed = 0.0
		if not _pushed:
			_snap_to_pixel()
	else:
		fall_speed = minf(fall_speed + gravity * delta, max_fall_speed)
		if move_and_collide(Vector2(0.0, fall_speed * delta)):
			fall_speed = 0.0
	_pushed = false


func _on_floor() -> bool:
	return test_move(global_transform, Vector2(0.0, 1.0))


# Pushes leave it on a fraction of a pixel, and a block resting off the
# pixel grid wobbles a pixel against the tiles as the camera moves. Only
# snaps where there's room, so it never steps into a wall or the player;
# if the player is in the way it waits until they move off. Each axis is
# tested on its own with no safe margin: landings and jams leave the
# block a hair off a surface, and ending exactly flush with it is fine.
func _snap_to_pixel() -> void:
	var offset := global_position.round() - global_position
	for axis: Vector2 in [Vector2(offset.x, 0.0), Vector2(0.0, offset.y)]:
		if axis != Vector2.ZERO and not test_move(global_transform, axis, null, 0.0):
			global_position += axis


# Moves the block sideways by up to `dx` and returns how far it actually
# went, so the player can follow exactly that far and stay in contact.
# The player is excluded for the move: on a pull the block steps into
# space the player is about to leave this same frame.
func slide(dx: float, mover: PhysicsBody2D) -> float:
	if not _on_floor():
		return 0.0
	_pushed = true
	var start := global_position.x
	add_collision_exception_with(mover)
	move_and_collide(Vector2(dx, 0.0))
	remove_collision_exception_with(mover)
	return global_position.x - start


func _draw() -> void:
	draw_texture_rect_region(TILES, Rect2(-SIZE * 0.5, SIZE), BLOCK_REGION)
	# Each bar sits 1px proud of its face, so it reads as a handle on the
	# side rather than part of the block's own shading.
	var half := SIZE * 0.5
	draw_rect(Rect2(-half.x - 1.0, -half.y, bar_width, SIZE.y), bar_color)
	draw_rect(Rect2(half.x + 1.0 - bar_width, -half.y, bar_width, SIZE.y), bar_color)
