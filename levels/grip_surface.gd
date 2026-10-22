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
# Drawn as a flat strip for now. Real art should mark grip with a
# texture or shape too, not colour alone, so it reads for colour-blind
# players.

@export var size := Vector2(6.0, 64.0):
	set(value):
		size = value
		_update_shape()
		queue_redraw()
@export var color := Color(0.2, 0.75, 0.3)
# A handhold can be grabbed and hung from but not climbed: the player's
# hands snap to its middle, and Up and Down do nothing. Jumping off is a
# full jump, like off any climb. Drawn as a small peg instead of a strip,
# so it reads by shape as well as colour. Its size is the catch area,
# taller than the peg so a fast fall can't pass it between frames.
@export var handhold := false:
	set(value):
		handhold = value
		queue_redraw()
@export var handhold_color := Color(0.95, 0.65, 0.2)
const HANDHOLD_PEG := Vector2(6.0, 4.0)

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
	if handhold:
		var peg := Rect2(-HANDHOLD_PEG * 0.5, HANDHOLD_PEG)
		draw_rect(peg, handhold_color)
		draw_rect(peg.grow(1.0), handhold_color.darkened(0.6), false, 1.0)
	else:
		draw_rect(Rect2(-size * 0.5, size), color)
