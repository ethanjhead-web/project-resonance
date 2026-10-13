@tool
class_name SlideSlope
extends StaticBody2D

# A right-angled triangle of solid world geometry whose slope is too
# slippery to stand on: the player slides down it at a constant speed
# and can kick off it at right angles (see the player's slope slide).
# Its upright side and flat base are ordinary wall and floor/ceiling, so
# they wall slide, wall jump and ledge grab like any block.
#
# The origin is the top-left of its bounding box, so it lines up with the
# tile grid like the painter's blocks. Keep the slope at 45° or shallower
# (height no more than width): anything steeper counts as a wall to the
# player's body, not a floor, and wouldn't slide.
#
# Drawn with ticks across the slope like the level sketch, so the slide
# surface reads by shape and not colour alone.

enum Downhill { LEFT = -1, RIGHT = 1 }

@export var size := Vector2(64.0, 64.0):
	set(value):
		size = value
		_update_shape()
		queue_redraw()
# Which way the slope runs down. RIGHT puts the upright side on the left.
@export var downhill: Downhill = Downhill.RIGHT:
	set(value):
		downhill = value
		_update_shape()
		queue_redraw()
@export var fill_color := Color(0.33, 0.29, 0.36)
@export var slope_color := Color(0.95, 0.8, 0.45)
@export var tick_spacing: float = 8.0
@export var tick_length: float = 5.0

var _shape := CollisionPolygon2D.new()


func _ready() -> void:
	# Built in code like GripSurface's, so the collision always matches
	# the drawing and there's only size and downhill to edit.
	add_child(_shape)
	_update_shape()


func _points() -> PackedVector2Array:
	if downhill == Downhill.RIGHT:
		return PackedVector2Array([Vector2.ZERO, Vector2(size.x, size.y), Vector2(0.0, size.y)])
	return PackedVector2Array([Vector2(size.x, 0.0), Vector2(size.x, size.y), Vector2(0.0, size.y)])


func _update_shape() -> void:
	_shape.polygon = _points()


func _draw() -> void:
	var points := _points()
	draw_colored_polygon(points, fill_color)
	# The slope runs from the top corner to the bottom corner on the
	# downhill side.
	var top := points[0]
	var bottom := Vector2(size.x if downhill == Downhill.RIGHT else 0.0, size.y)
	draw_line(top, bottom, slope_color, 2.0)
	var along := (bottom - top).normalized()
	var inward := Vector2(-along.y, along.x) * (1.0 if downhill == Downhill.RIGHT else -1.0)
	var length := top.distance_to(bottom)
	# Kept clear of the corners so no tick pokes out of the narrow tips.
	var d := tick_spacing
	while d < length - tick_spacing:
		var p := top + along * d
		draw_line(p, p + inward * tick_length, slope_color, 1.0)
		d += tick_spacing
