@tool
class_name NucleusSquareBoard2D
extends Node2D
## Optional visual authoring board, not a replacement for TileMapLayer.
## Tiles store only integer positions and 90-degree orientation steps.

signal tile_painted(cell: Vector2i)
signal tile_erased(cell: Vector2i)
signal tile_rotated(cell: Vector2i, steps: int)
signal edge_connected(cell: Vector2i, side: int, other: Vector2i)
signal edge_disconnected(cell: Vector2i, side: int, other: Vector2i)
signal corner_connected(cell: Vector2i, corner: int, other: Vector2i, other_corner: int)
signal corner_disconnected(cell: Vector2i, corner: int, other: Vector2i, other_corner: int)

const MAX_TILES: int = 1024
@export var cell_size: Vector2 = Vector2(48.0, 48.0)
@export var half_extent: Vector2i = Vector2i(8, 7)
@export var isometric: bool = false
@export var show_ghost: bool = true
@export var show_selected_orientation: bool = true
@export var tile_color: Color = Color(0.30, 0.69, 0.78)
@export var grid_color: Color = Color(0.27, 0.53, 0.63, 0.52)
@export var selection_color: Color = Color(1.0, 0.79, 0.30)

var _tiles: Dictionary = {} # Vector2i -> rotation steps (0..3)
var _corners: Dictionary = {} # exact Vector3i -> [{cell, corner}]
var _has_selected: bool = false
var _selected: Vector2i
var _has_hover: bool = false
var _hovered: Vector2i


func is_valid_cell(cell: Vector2i) -> bool:
	return (
		absi(cell.x) <= clampi(half_extent.x, 0, 24)
		and absi(cell.y) <= clampi(half_extent.y, 0, 24)
	)


func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(NucleusSquareLayout.cell_to_local(cell, cell_size, isometric))


func world_to_cell(world_position: Vector2) -> Vector2i:
	return NucleusSquareLayout.local_to_cell(to_local(world_position), cell_size, isometric)


func has_tile(cell: Vector2i) -> bool:
	return _tiles.has(cell)


func tile_count() -> int:
	return _tiles.size()


func painted_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _tiles:
		result.append(cell)
	return result


func get_rotation_steps(cell: Vector2i) -> int:
	return int(_tiles.get(cell, 0))


func paint_cell(cell: Vector2i) -> bool:
	if not is_valid_cell(cell) or has_tile(cell) or _tiles.size() >= MAX_TILES:
		return false
	_tiles[cell] = 0
	_connect_cell(cell, true)
	queue_redraw()
	tile_painted.emit(cell)
	return true


func erase_cell(cell: Vector2i) -> bool:
	if not has_tile(cell):
		return false
	_connect_cell(cell, false)
	_tiles.erase(cell)
	if _has_selected and _selected == cell:
		_has_selected = false
	queue_redraw()
	tile_erased.emit(cell)
	return true


func rotate_tile(cell: Vector2i, delta_steps: int = 1) -> bool:
	if not has_tile(cell):
		return false
	_tiles[cell] = posmod(get_rotation_steps(cell) + delta_steps, 4)
	queue_redraw()
	tile_rotated.emit(cell, get_rotation_steps(cell))
	return true


func select_cell(cell: Vector2i, enabled: bool = true) -> void:
	_has_selected = enabled and has_tile(cell)
	if _has_selected:
		_selected = cell
	queue_redraw()


func set_hover(cell: Vector2i, enabled: bool = true) -> void:
	_has_hover = enabled and is_valid_cell(cell)
	_hovered = cell
	queue_redraw()


func shared_corner_count() -> int:
	var total: int = 0
	for key: Vector3i in _corners:
		var size: int = _corners[key].size()
		@warning_ignore("integer_division")
		total += size * (size - 1) / 2
	return total


func clear_tiles() -> void:
	for cell: Vector2i in painted_cells():
		erase_cell(cell)


func _connect_cell(cell: Vector2i, adding: bool) -> void:
	for corner in range(4):
		var key: Vector3i = NucleusSquareLayout.corner_key(
			Vector3i(cell.x, cell.y, 0), corner
		)
		var entries: Array = _corners.get(key, [])
		for entry: Dictionary in entries:
			if entry["cell"] != cell:
				if adding:
					corner_connected.emit(cell, corner, entry["cell"], entry["corner"])
				else:
					corner_disconnected.emit(cell, corner, entry["cell"], entry["corner"])
		if adding:
			entries.append({"cell": cell, "corner": corner})
		else:
			for i in range(entries.size() - 1, -1, -1):
				if entries[i]["cell"] == cell:
					entries.remove_at(i)
		if entries.is_empty():
			_corners.erase(key)
		else:
			_corners[key] = entries
	for side in range(4):
		var other: Vector2i = NucleusSquareLayout.neighbor(cell, side)
		if has_tile(other):
			if adding:
				edge_connected.emit(cell, side, other)
			else:
				edge_disconnected.emit(cell, side, other)


func _points(cell: Vector2i) -> PackedVector2Array:
	var center: Vector2 = NucleusSquareLayout.cell_to_local(cell, cell_size, isometric)
	var points := PackedVector2Array()
	for corner in range(4):
		points.append(center + NucleusSquareLayout.corner_offset(
			corner, cell_size, isometric
		))
	return points


func _draw() -> void:
	if not cell_size.is_finite() or cell_size.x <= 0.0 or cell_size.y <= 0.0:
		return
	if show_ghost:
		for y in range(-clampi(half_extent.y, 0, 24), clampi(half_extent.y, 0, 24) + 1):
			for x in range(-clampi(half_extent.x, 0, 24), clampi(half_extent.x, 0, 24) + 1):
				var cell := Vector2i(x, y)
				var points: PackedVector2Array = _points(cell)
				for side in range(4):
					var other: Vector2i = NucleusSquareLayout.neighbor(cell, side)
					if is_valid_cell(other) and (other.x < x or (other.x == x and other.y < y)):
						continue
					draw_line(points[side], points[(side + 1) % 4], grid_color, 1.0, true)
	for cell: Vector2i in _tiles:
		var points: PackedVector2Array = _points(cell)
		var color: Color = selection_color if _has_selected and cell == _selected else tile_color
		draw_colored_polygon(points, color)
		points.append(points[0])
		draw_polyline(points, Color(0.10, 0.17, 0.23), 1.5, true)
	if _has_hover:
		var outline: PackedVector2Array = _points(_hovered)
		outline.append(outline[0])
		draw_polyline(outline, selection_color, 2.5, true)
	if _has_selected and show_selected_orientation and has_tile(_selected):
		var center: Vector2 = NucleusSquareLayout.cell_to_local(
			_selected, cell_size, isometric
		)
		var endpoint: Vector2 = NucleusSquareLayout.cell_to_local(
			NucleusSquareLayout.neighbor(_selected, get_rotation_steps(_selected)),
			cell_size, isometric
		)
		draw_line(center, center.lerp(endpoint, 0.32), Color(0.08, 0.17, 0.24), 3.0, true)
