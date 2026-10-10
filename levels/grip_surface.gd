@tool
class_name GripSurface
extends Area2D

# Marks a stretch of wall the player can climb. Only walls with one of
# these on them can be grabbed and climbed, so climbable routes are a
# level-design choice rather than every wall in the game. Wall slides,
# wall jumps and ledge grabs still work on any wall.
#
# Place it straddling the wall face, a couple of pixels out into the air
# and a few into the wall: the player's hand probe checks a point just
# past their body's edge, which lands inside it while they touch the wall.
#
# A surface with drains_stamina off is free to climb, for the ladders
# it will eventually become. It draws green instead of red.
#
# Drawn as a flat strip for now. Real art should mark grip with a
# texture or shape too, not colour alone, so it reads for colour-blind
# players.

@export var size := Vector2(6.0, 64.0):
	set(value):
		size = value
		_update_shape()
		queue_redraw()
@export var color := Color(0.85, 0.15, 0.15)
@export var drains_stamina := true:
	set(value):
		drains_stamina = value
		queue_redraw()
@export var free_color := Color(0.2, 0.75, 0.3)

var _shape := CollisionShape2D.new()


func _ready() -> void:
	# Built in code rather than saved in the scene, so the shape always
	# matches `size` and there's only one number to edit.
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_update_shape()


func _update_shape() -> void:
	if _shape.shape:
		(_shape.shape as RectangleShape2D).size = size


func _draw() -> void:
	draw_rect(Rect2(-size * 0.5, size), color if drains_stamina else free_color)
