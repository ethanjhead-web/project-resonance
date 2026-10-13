@tool
class_name RefillDiamond
extends Area2D

# A floating diamond that hands the air dash back when the player touches
# it, so a route can ask for a second dash before landing. The player
# freezes for a moment on contact, then it vanishes for respawn_time.
#
# A plain refill only takes a touch while the dash is spent, so it isn't
# wasted by brushing past it with the dash still ready. A `launch` one
# (the bounce) always fires: after the freeze it throws the player
# straight up, and it refills the dash too.
#
# The glyph inside tells the two apart, so they don't rely on colour.

@export var launch: bool = false
@export var glyph: String = "%":
	set(value):
		glyph = value
		queue_redraw()
# Tip to tip. About twice the player's head.
@export var size: float = 20.0:
	set(value):
		size = value
		_update_shape()
		queue_redraw()
@export var respawn_time: float = 5.0
@export var color := Color(1.0, 0.82, 0.15)
@export var outline_color := Color(0.55, 0.38, 0.05)
@export var glyph_color := Color(0.25, 0.15, 0.0)
@export var glyph_size: int = 11
# The burst when it's collected: it swells to pop_scale times its size
# while fading out, over pop_time.
@export var pop_time: float = 0.4
@export var pop_scale: float = 2.0

var _shape := CollisionShape2D.new()
var _respawn_timer: float = 0.0
var _pop_timer: float = 0.0


func _ready() -> void:
	# Built in code like GripSurface's, so the shape always matches `size`.
	_shape.shape = ConvexPolygonShape2D.new()
	add_child(_shape)
	_update_shape()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _respawn_timer > 0.0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			queue_redraw()
		return
	# Polled rather than body_entered, so a player already standing in it
	# when it comes back (or when the dash runs out) still sets it off.
	for body in get_overlapping_bodies():
		if body.has_method("touch_diamond") and body.call("touch_diamond", launch):
			_respawn_timer = respawn_time
			_pop_timer = pop_time
			queue_redraw()
			return


# The burst runs on the render frame rather than the physics tick, so the
# swell stays smooth at any refresh rate.
func _process(delta: float) -> void:
	if _pop_timer > 0.0:
		_pop_timer -= delta
		queue_redraw()


func _points() -> PackedVector2Array:
	var r := size * 0.5
	return PackedVector2Array([Vector2(0.0, -r), Vector2(r, 0.0), Vector2(0.0, r), Vector2(-r, 0.0)])


func _update_shape() -> void:
	if _shape.shape:
		(_shape.shape as ConvexPolygonShape2D).points = _points()


func _draw() -> void:
	var points := _points()
	var outline := points.duplicate()
	outline.append(points[0])
	if _respawn_timer > 0.0:
		# A faint outline while it's gone, so the player can see where it
		# will come back.
		draw_polyline(outline, Color(color, 0.35), 1.0)
		if _pop_timer > 0.0:
			# Ease-out on the swell: it bursts outward fast and slows as it
			# fades, so it reads as a small explosion rather than a steady
			# grow. The fade is linear, so it's gone exactly as the swell ends.
			var t := 1.0 - maxf(_pop_timer, 0.0) / pop_time
			var grow := 1.0 - pow(1.0 - t, 3.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * lerpf(1.0, pop_scale, grow))
			_draw_diamond(points, outline, 1.0 - t)
			draw_set_transform(Vector2.ZERO)
		return
	_draw_diamond(points, outline, 1.0)


func _draw_diamond(points: PackedVector2Array, outline: PackedVector2Array, alpha: float) -> void:
	draw_colored_polygon(points, Color(color, alpha))
	draw_polyline(outline, Color(outline_color, alpha), 1.0)
	var font := ThemeDB.fallback_font
	# draw_string() places the baseline, so drop it by half the glyph's
	# height to centre it.
	var baseline := (font.get_ascent(glyph_size) - font.get_descent(glyph_size)) * 0.5
	draw_string(font, Vector2(-size * 0.5, baseline), glyph, HORIZONTAL_ALIGNMENT_CENTER,
			size, glyph_size, Color(glyph_color, alpha))
