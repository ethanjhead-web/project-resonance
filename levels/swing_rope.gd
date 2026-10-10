@tool
class_name SwingRope
extends Area2D

# A rope hanging from its position (the anchor) that the player can catch
# by holding grab and swing from. Place the node where the rope meets the
# ceiling; it hangs straight down `length` pixels.
#
# The rope owns its swing (angle and angular velocity) so it keeps moving
# after the player lets go and settles back on its own. While someone is
# holding it, the player drives the swing and writes it back here, since
# the pendulum's length is wherever their hands are, not the rope's end.
#
# It's a rigid straight line for now: no sag or bend, just the swing.

@export var length: float = 200.0:
	set(value):
		length = value
		_update_shape()
		queue_redraw()
@export var swing_gravity: float = 800.0
# Damping while nobody is holding it, so a released rope settles back to
# hanging straight in a few swings rather than swinging forever.
@export var free_damping: float = 1.2
@export var color := Color(0.72, 0.55, 0.32)
@export var width: float = 2.0

# 0 is hanging straight down; positive swings the free end to the right.
var angle: float = 0.0
var angular_velocity: float = 0.0
# Set by the player while they hold on, so the rope doesn't also run its
# own swing on top of theirs.
var held: bool = false

var _shape := CollisionShape2D.new()


func _ready() -> void:
	# Built in code like GripSurface's, so the shape always matches `length`.
	_shape.shape = SegmentShape2D.new()
	add_child(_shape)
	_update_shape()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or held:
		return
	# An empty rope swings about its middle, so it uses half its length.
	angular_velocity += -swing_gravity / (length * 0.5) * sin(angle) * delta
	angular_velocity *= maxf(1.0 - free_damping * delta, 0.0)
	angle += angular_velocity * delta
	rotation = -angle


# The unit vector from the anchor along the rope.
func direction() -> Vector2:
	return Vector2(sin(angle), cos(angle))


func set_swing(new_angle: float, new_angular_velocity: float) -> void:
	angle = new_angle
	angular_velocity = new_angular_velocity
	# rotation turns clockwise on screen, which swings the end left, so
	# it's the negative of the angle.
	rotation = -angle


func _update_shape() -> void:
	if _shape.shape:
		var segment := _shape.shape as SegmentShape2D
		segment.a = Vector2.ZERO
		segment.b = Vector2(0.0, length)


func _draw() -> void:
	draw_line(Vector2.ZERO, Vector2(0.0, length), color, width)
	# A small knot where it's tied to the ceiling.
	draw_rect(Rect2(-2.0, -1.0, 4.0, 3.0), color.darkened(0.3))
