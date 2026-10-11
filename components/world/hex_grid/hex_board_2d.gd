@tool
class_name NucleusHexBoard2D
extends Node2D
## Scene-owned, data-only occupancy drawn with CanvasItem primitives.
## Coordinates, rotations and connection identity share NucleusHexLayout with 3D.
## No TileMap/TileSet is imposed on games; they may replace drawing with TileMapLayer.

signal tile_painted(cell: Vector2i)
signal tile_erased(cell: Vector2i)
signal tile_moved(from_cell: Vector2i, to_cell: Vector2i)
signal tile_rotated(cell: Vector2i, steps: int)
signal corner_connected(
	cell: Vector2i, corner: int, other: Vector2i, other_corner: int, point: Vector2,
)
signal corner_disconnected(
	cell: Vector2i, corner: int, other: Vector2i, other_corner: int, point: Vector2,
)
signal edge_connected(cell: Vector2i, side: int, other: Vector2i)
signal edge_disconnected(cell: Vector2i, side: int, other: Vector2i)

const MAX_TILES: int = 1024
const MAX_RING: int = 24

@export_range(2.0, 100.0, 0.5) var cell_radius: float = 24.0
@export_range(1, 24, 1) var ring_count: int = 6
@export var flat_top: bool = false
@export var show_ghost: bool = true
@export var show_selected_orientation: bool = true
@export var tile_color: Color = Color(0.45, 0.72, 0.87)
@export var grid_color: Color = Color(0.1, 0.62, 0.77, 0.72)
@export var selection_color: Color = Color(1.0, 0.81, 0.25)

var _tiles: Dictionary = {} # Vector2i -> steps 0..5
var _corners: Dictionary = {} # Vector3i shared key -> Array[{cell, corner}]
var _has_selection: bool = false
var _selected: Vector2i = Vector2i.ZERO
var _has_hover: bool = false
var _hovered: Vector2i = Vector2i.ZERO


func is_valid_cell(cell: Vector2i) -> bool:
	return NucleusHexLayout.in_radius(cell, ring_count)


func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(NucleusHexLayout.axial_to_pixel(cell, cell_radius, flat_top))


func world_to_cell(world_position: Vector2) -> Vector2i:
	return NucleusHexLayout.pixel_to_axial(to_local(world_position), cell_radius, flat_top)


func corner_world(cell: Vector2i, corner: int) -> Vector2:
	var center: Vector2 = NucleusHexLayout.axial_to_pixel(cell, cell_radius, flat_top)
	return to_global(center + NucleusHexLayout.corner_offset(corner, cell_radius, flat_top))


func tile_count() -> int:
	return _tiles.size()


func painted_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _tiles:
		result.append(cell)
	return result


func has_tile(cell: Vector2i) -> bool:
	return _tiles.has(cell)


func get_rotation_steps(cell: Vector2i) -> int:
	return int(_tiles.get(cell, 0))


func paint_cell(cell: Vector2i) -> bool:
	if not is_valid_cell(cell) or _tiles.has(cell) or _tiles.size() >= MAX_TILES:
		return false
	_tiles[cell] = 0
	_add_connections(cell)
	queue_redraw()
	tile_painted.emit(cell)
	return true


func erase_cell(cell: Vector2i) -> bool:
	if not _tiles.has(cell):
		return false
	_remove_connections(cell)
	_tiles.erase(cell)
	if _has_selection and _selected == cell:
		_has_selection = false
	queue_redraw()
	tile_erased.emit(cell)
	return true


func move_tile(source: Vector2i, destination: Vector2i) -> bool:
	if not _tiles.has(source) or not is_valid_cell(destination) or _tiles.has(destination):
		return false
	_remove_connections(source)
	var steps: int = int(_tiles[source])
	_tiles.erase(source)
	_tiles[destination] = steps
	if _has_selection and _selected == source:
		_selected = destination
	_add_connections(destination)
	queue_redraw()
	tile_moved.emit(source, destination)
	return true


func rotate_tile(cell: Vector2i, delta_steps: int = 1) -> bool:
	if not _tiles.has(cell):
		return false
	var steps: int = posmod(int(_tiles[cell]) + delta_steps, 6)
	_tiles[cell] = steps
	queue_redraw()
	tile_rotated.emit(cell, steps)
	return true


func highlight_selection(cell: Vector2i, enabled: bool = true) -> void:
	_has_selection = enabled and _tiles.has(cell)
	if _has_selection:
		_selected = cell
	queue_redraw()


func set_hover(cell: Vector2i, enabled: bool = true) -> void:
	var next_visible: bool = enabled and is_valid_cell(cell)
	if _has_hover == next_visible and (not next_visible or _hovered == cell):
		return
	_has_hover = next_visible
	_hovered = cell
	queue_redraw()


func set_cell_radius(value: float) -> void:
	if not is_finite(value):
		return
	cell_radius = clampf(value, 2.0, 100.0)
	queue_redraw()


func set_ring_count(value: int) -> void:
	ring_count = clampi(value, 1, MAX_RING)
	queue_redraw()


func set_flat_top(value: bool) -> void:
	flat_top = value
	queue_redraw()


func clear_tiles() -> void:
	for cell: Vector2i in painted_cells():
		erase_cell(cell)


func shared_corner_count() -> int:
	var total: int = 0
	for key: Vector3i in _corners:
		var group: Array = _corners[key]
		total += group.size() * (group.size() - 1) / 2
	return total


func _add_connections(cell: Vector2i) -> void:
	for corner: int in range(6):
		var key: Vector3i = NucleusHexLayout.corner_key(Vector3i(cell.x, cell.y, 0), corner)
		var entries: Array = _corners.get(key, [])
		for other: Dictionary in entries:
			corner_connected.emit(
				cell, corner, other["cell"], int(other["corner"]),
				corner_world(cell, corner),
			)
		entries.append({"cell": cell, "corner": corner})
		_corners[key] = entries
	for side: int in range(6):
		var neighbor: Vector2i = NucleusHexLayout.edge_neighbor(cell, side)
		if _tiles.has(neighbor):
			edge_connected.emit(cell, side, neighbor)


func _remove_connections(cell: Vector2i) -> void:
	for corner: int in range(6):
		var key: Vector3i = NucleusHexLayout.corner_key(Vector3i(cell.x, cell.y, 0), corner)
		var entries: Array = _corners.get(key, [])
		for other: Dictionary in entries:
			if other["cell"] != cell:
				corner_disconnected.emit(
					cell, corner, other["cell"], int(other["corner"]),
					corner_world(cell, corner),
				)
		for index: int in range(entries.size() - 1, -1, -1):
			if entries[index]["cell"] == cell:
				entries.remove_at(index)
		if entries.is_empty():
			_corners.erase(key)
		else:
			_corners[key] = entries
	for side: int in range(6):
		var neighbor: Vector2i = NucleusHexLayout.edge_neighbor(cell, side)
		if _tiles.has(neighbor):
			edge_disconnected.emit(cell, side, neighbor)


func _draw() -> void:
	if cell_radius <= 0.0:
		return
	if show_ghost:
		for cell: Vector2i in NucleusHexLayout.cells_in_radius(ring_count):
			# Draw each shared edge once, preventing doubled alpha and overdraw.
			for side: int in range(6):
				var adjacent: Vector2i = NucleusHexLayout.edge_neighbor(cell, side)
				if is_valid_cell(adjacent) and _cell_less(adjacent, cell):
					continue
				var a: Vector2 = _corner(cell, side)
				var b: Vector2 = _corner(cell, side + 1)
				draw_line(a, b, grid_color, 1.25, true)
	for cell: Vector2i in _tiles:
		var selected: bool = _has_selection and _selected == cell
		var color: Color = selection_color if selected else tile_color
		var points := PackedVector2Array()
		for corner: int in range(6):
			points.append(_corner(cell, corner))
		draw_colored_polygon(points, color)
		points.append(points[0])
		draw_polyline(points, Color(0.08, 0.17, 0.22), 1.5, true)
	if _has_hover and is_valid_cell(_hovered):
		var outline := PackedVector2Array()
		for corner: int in range(7):
			outline.append(_corner(_hovered, corner))
		draw_polyline(outline, Color(1.0, 0.89, 0.26), 2.5, true)
	if _has_selection and show_selected_orientation and _tiles.has(_selected):
		var angle: float = float(int(_tiles[_selected])) * PI / 3.0
		var center: Vector2 = NucleusHexLayout.axial_to_pixel(
			_selected, cell_radius, flat_top,
		)
		var tip: Vector2 = Vector2(0, -0.73 * cell_radius).rotated(angle)
		var tail: Vector2 = Vector2(0, 0.25 * cell_radius).rotated(angle)
		draw_line(center + tail, center + tip, Color(0.15, 0.21, 0.27), 3.0, true)
		var wing_a: Vector2 = Vector2(-0.19, -0.4) * cell_radius
		var wing_b: Vector2 = Vector2(0.19, -0.4) * cell_radius
		draw_colored_polygon(PackedVector2Array([
			center + tip, center + wing_a.rotated(angle),
			center + wing_b.rotated(angle),
		]), Color(0.15, 0.21, 0.27))


func _corner(cell: Vector2i, index: int) -> Vector2:
	return NucleusHexLayout.axial_to_pixel(cell, cell_radius, flat_top) + (
		NucleusHexLayout.corner_offset(index, cell_radius, flat_top)
	)


static func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)
