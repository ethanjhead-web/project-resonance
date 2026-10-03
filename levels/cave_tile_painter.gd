@tool
extends TileMapLayer

# Builds a cave room from a text layout so blocking out a level is just
# typing: "#" is solid brick, "." is open air. Each cell then gets the
# right tile from "Tilemap (Super Basic)" by checking its neighbours, so
# edges, corners and the brick rim all line up automatically.
#
# Edit the layout in the Inspector, then press "Rebuild From Layout".
# Rebuilding replaces every tile, so hand-painted changes made in the
# editor's TileMap panel are lost - rebuild first, paint after.
#
# Layout rules this tileset can draw cleanly:
#   - Air gaps should be at least 2 tiles wide/tall.
#   - Free-floating blocks should be exactly 2x2 (the pack's block art).
# Anything outside the layout counts as solid, so the border reads as wall.

const SOURCE_ID := 0

@export_multiline var layout: String = ""
@export_tool_button("Rebuild From Layout", "TileMap") var rebuild_button := rebuild

var _rows: PackedStringArray = []


func _ready() -> void:
	# Only auto-build when empty, so tiles painted by hand in the editor
	# aren't wiped every time the scene opens.
	if get_used_cells().is_empty():
		rebuild()


func rebuild() -> void:
	clear()
	_rows = layout.strip_edges().split("\n")
	for y in _rows.size():
		for x in _rows[y].length():
			var cell := Vector2i(x, y)
			var atlas := _solid_tile(cell) if _is_solid(cell) else _air_tile(cell)
			set_cell(cell, SOURCE_ID, atlas)


func _is_solid(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= _rows.size():
		return true
	var row := _rows[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return true
	return row[cell.x] == "#"


# Which orthogonal sides of `cell` are open air (for solid cells).
func _open_sides(cell: Vector2i) -> Dictionary:
	return {
		"n": not _is_solid(cell + Vector2i.UP),
		"s": not _is_solid(cell + Vector2i.DOWN),
		"w": not _is_solid(cell + Vector2i.LEFT),
		"e": not _is_solid(cell + Vector2i.RIGHT),
	}


# A solid cell with air on two touching sides is a convex corner. Those
# use the pack's 2x2 floating-block tiles, and the air around them needs
# the matching rim tiles - so neighbours ask this to pick their own tile.
func _corner_kind(cell: Vector2i) -> String:
	if not _is_solid(cell):
		return ""
	var o := _open_sides(cell)
	if o.n and o.w: return "tl"
	if o.n and o.e: return "tr"
	if o.s and o.w: return "bl"
	if o.s and o.e: return "br"
	return ""


func _solid_tile(cell: Vector2i) -> Vector2i:
	var o := _open_sides(cell)
	var x := cell.x
	var y := cell.y

	match _corner_kind(cell):
		"tl": return Vector2i(1, 1)
		"tr": return Vector2i(2, 1)
		"bl": return Vector2i(1, 2)
		"br": return Vector2i(2, 2)

	# Edge bricks: the pack shades the side facing the cave darker,
	# so pick the variant whose shadow faces the open side.
	if o.n: return Vector2i(1 + posmod(x, 4), 9)
	if o.s: return Vector2i(1 + posmod(x, 4), 4)
	if o.w: return Vector2i(5, 5 + posmod(y, 4))
	if o.e: return Vector2i(0, 5 + posmod(y, 4))

	# Inner corners of the cave (only a diagonal neighbour is open).
	if not _is_solid(cell + Vector2i(1, 1)): return Vector2i(0, 4)
	if not _is_solid(cell + Vector2i(-1, 1)): return Vector2i(5, 4)
	if not _is_solid(cell + Vector2i(1, -1)): return Vector2i(0, 9)
	if not _is_solid(cell + Vector2i(-1, -1)): return Vector2i(5, 9)

	# Deep fill. The pack has no dedicated interior tile, so alternate
	# light-top / light-bottom brick rows for a layered-stone look.
	# Keep walkable surfaces on even rows so the bands line up under them.
	if posmod(y, 2) == 1:
		return Vector2i(1 + posmod(x, 4), 4)
	return Vector2i(1 + posmod(x, 4), 9)


func _air_tile(cell: Vector2i) -> Vector2i:
	var x := cell.x
	var y := cell.y
	var n := _is_solid(cell + Vector2i.UP)
	var s := _is_solid(cell + Vector2i.DOWN)
	var w := _is_solid(cell + Vector2i.LEFT)
	var e := _is_solid(cell + Vector2i.RIGHT)

	# Inside corners of the cave.
	if n and w: return Vector2i(1, 5)
	if n and e: return Vector2i(4, 5)
	if s and w: return Vector2i(1, 8)
	if s and e: return Vector2i(4, 8)

	# Single edges: use the floating-block rim when the neighbour is a
	# convex corner block, otherwise the cave-wall rim.
	if s:
		match _corner_kind(cell + Vector2i.DOWN):
			"tl": return Vector2i(1, 0)
			"tr": return Vector2i(2, 0)
		return Vector2i(2 + posmod(x, 2), 8)
	if n:
		match _corner_kind(cell + Vector2i.UP):
			"bl": return Vector2i(1, 3)
			"br": return Vector2i(2, 3)
		return Vector2i(2 + posmod(x, 2), 5)
	if e:
		match _corner_kind(cell + Vector2i.RIGHT):
			"tl": return Vector2i(0, 1)
			"bl": return Vector2i(0, 2)
		return Vector2i(4, 6 + posmod(y, 2))
	if w:
		match _corner_kind(cell + Vector2i.LEFT):
			"tr": return Vector2i(3, 1)
			"br": return Vector2i(3, 2)
		return Vector2i(1, 6 + posmod(y, 2))

	# Diagonal-only: the outside corner of a block.
	if _is_solid(cell + Vector2i(1, 1)): return Vector2i(0, 0)
	if _is_solid(cell + Vector2i(-1, 1)): return Vector2i(3, 0)
	if _is_solid(cell + Vector2i(1, -1)): return Vector2i(0, 3)
	if _is_solid(cell + Vector2i(-1, -1)): return Vector2i(3, 3)

	# Open air: the starry background, varied so it doesn't look tiled.
	return Vector2i(2 + posmod(x, 2), 6 + posmod(y, 2))
