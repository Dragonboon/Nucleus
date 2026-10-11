class_name NucleusHexBoard3D
extends Node3D
## Scene-owned hex cell store. Emits vertex contact events; no physics authority.
## Change grid geometry via configure()/set_*; placed tiles stay in axial coords.

signal tile_painted(cell: Vector3i, tile: Node3D)
signal tile_erased(cell: Vector3i)
signal tile_moved(from_cell: Vector3i, to_cell: Vector3i)
signal tile_rotated(cell: Vector3i, steps: int)
signal edge_connected(cell: Vector3i, side: int, other: Vector3i)
signal edge_disconnected(cell: Vector3i, side: int, other: Vector3i)
signal corner_connected(
	cell: Vector3i, corner: int, other: Vector3i, other_corner: int, point: Vector3,
)
signal corner_disconnected(
	cell: Vector3i, corner: int, other: Vector3i, other_corner: int, point: Vector3,
)

const MAX_TILES: int = 1024
const MAX_RING: int = 24

@export_range(0.1, 20.0, 0.05) var cell_radius: float = 1.5
@export_range(1, 24, 1) var ring_count: int = 6
@export_range(0.05, 10.0, 0.05) var tile_height: float = 0.4
@export_range(0.1, 20.0, 0.05) var layer_step: float = 1.0
@export_range(-8, 8, 1) var active_layer: int = 0
@export var tile_color: Color = Color(0.52, 0.69, 0.79)
@export var show_ghost: bool = true
@export var flat_top: bool = false
## The arrow belongs to the selected tile only; never to the ghost grid.
@export var show_selected_orientation: bool = true

var _tiles: Dictionary = {} # Vector3i -> MeshInstance3D
var _angles: Dictionary = {} # Vector3i -> 0..5
var _vertices: Dictionary = {} # Vector3i corner_key -> Array[{cell, corner}]
var _tile_mesh: ArrayMesh
var _tile_material: StandardMaterial3D
var _selected_material: StandardMaterial3D
var _selected_cell: Vector3i = Vector3i.ZERO
var _selection_active: bool = false
var _ghost: MeshInstance3D
var _hover: MeshInstance3D
var _selection_direction: MeshInstance3D


func _ready() -> void:
	_tile_material = StandardMaterial3D.new()
	_tile_material.albedo_color = tile_color
	_tile_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_tile_material.vertex_color_use_as_albedo = true
	_selected_material = _tile_material.duplicate() as StandardMaterial3D
	_selected_material.albedo_color = Color(1.0, 0.81, 0.25)
	_ghost = MeshInstance3D.new()
	_ghost.name = "GhostGrid"
	add_child(_ghost)
	_hover = MeshInstance3D.new()
	_hover.name = "HoverHex"
	add_child(_hover)
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_material.albedo_color = Color(0.17, 0.84, 1.0, 0.57)
	line_material.no_depth_test = true
	_ghost.material_override = line_material
	var hover_material := line_material.duplicate() as StandardMaterial3D
	hover_material.albedo_color = Color(1.0, 0.9, 0.18, 1.0)
	_hover.material_override = hover_material
	_selection_direction = MeshInstance3D.new()
	_selection_direction.name = "SelectedOrientation"
	var direction_material := StandardMaterial3D.new()
	direction_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	direction_material.albedo_color = Color(0.14, 0.19, 0.25)
	direction_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_selection_direction.material_override = direction_material
	add_child(_selection_direction)
	_rebuild_geometry()
	_hover.visible = false
	_selection_direction.visible = false


func is_valid_cell(cell: Vector3i) -> bool:
	return (
		cell.z >= -8 and cell.z <= 8
		and NucleusHexLayout3D.in_ring(Vector2i(cell.x, cell.y), ring_count)
	)


func world_to_cell(world_position: Vector3, layer: int = 0) -> Vector3i:
	var axial := NucleusHexLayout3D.local_to_axial(to_local(world_position), cell_radius, flat_top)
	return Vector3i(axial.x, axial.y, layer)


func cell_to_world(cell: Vector3i) -> Vector3:
	var local := NucleusHexLayout3D.axial_to_local(Vector2i(cell.x, cell.y), cell_radius, flat_top)
	local.y = float(cell.z) * layer_step
	return to_global(local)


func cell_corner_world(cell: Vector3i, corner: int) -> Vector3:
	var local := NucleusHexLayout3D.corner_local(
		Vector2i(cell.x, cell.y), corner, cell_radius, flat_top,
	)
	local.y = float(cell.z) * layer_step + tile_height
	return to_global(local)


func intersect_cursor(camera: Camera3D, screen_point: Vector2, layer: int = 0) -> Dictionary:
	if camera == null or layer < -8 or layer > 8:
		return {}
	var normal := global_transform.basis.y.normalized()
	var plane_origin := to_global(Vector3.UP * (float(layer) * layer_step))
	var plane := Plane(normal, plane_origin)
	var from := camera.project_ray_origin(screen_point)
	var direction := camera.project_ray_normal(screen_point)
	var point: Variant = plane.intersects_ray(from, direction)
	if point == null:
		return {}
	var cell := world_to_cell(point as Vector3, layer)
	if not is_valid_cell(cell):
		return {}
	return {"cell": cell, "world_position": cell_to_world(cell)}


func has_tile(cell: Vector3i) -> bool:
	return _tiles.has(cell)


func tile_at(cell: Vector3i) -> Node3D:
	return _tiles.get(cell) as Node3D


## Highlight one authored tile without changing the shared material.
func highlight_selection(cell: Vector3i, enabled: bool = true) -> void:
	if _selection_active and _tiles.has(_selected_cell):
		var previous: MeshInstance3D = _tiles[_selected_cell]
		previous.material_override = _tile_material
	_selection_active = enabled and _tiles.has(cell)
	if _selection_active:
		_selected_cell = cell
		var selected: MeshInstance3D = _tiles[cell]
		selected.material_override = _selected_material
	_update_selected_direction()


func tile_count() -> int:
	return _tiles.size()


func painted_cells() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for key: Vector3i in _tiles:
		result.append(key)
	return result


func paint_cell(cell: Vector3i) -> bool:
	if (
		not is_inside_tree() or _tile_mesh == null
		or not is_valid_cell(cell) or _tiles.has(cell)
		or _tiles.size() >= MAX_TILES
	):
		return false
	var tile := MeshInstance3D.new()
	tile.name = "Hex_%d_%d_%d" % [cell.x, cell.y, cell.z]
	tile.mesh = _tile_mesh
	tile.material_override = _tile_material
	add_child(tile)
	_tiles[cell] = tile
	_angles[cell] = 0
	_position_tile(tile, cell)
	_add_connections(cell)
	tile_painted.emit(cell, tile)
	return true


func erase_cell(cell: Vector3i) -> bool:
	if not _tiles.has(cell):
		return false
	_remove_connections(cell)
	if _selection_active and _selected_cell == cell:
		_selection_active = false
		_update_selected_direction()
	var tile: MeshInstance3D = _tiles[cell]
	_tiles.erase(cell)
	_angles.erase(cell)
	tile.queue_free()
	tile_erased.emit(cell)
	return true


func move_tile(from_cell: Vector3i, to_cell: Vector3i) -> bool:
	if not _tiles.has(from_cell) or not is_valid_cell(to_cell) or _tiles.has(to_cell):
		return false
	_remove_connections(from_cell)
	var tile: MeshInstance3D = _tiles[from_cell]
	var angle: int = _angles[from_cell]
	_tiles.erase(from_cell)
	_angles.erase(from_cell)
	_tiles[to_cell] = tile
	_angles[to_cell] = angle
	if _selection_active and _selected_cell == from_cell:
		_selected_cell = to_cell
	tile.name = "Hex_%d_%d_%d" % [to_cell.x, to_cell.y, to_cell.z]
	_position_tile(tile, to_cell)
	_update_selected_direction()
	_add_connections(to_cell)
	tile_moved.emit(from_cell, to_cell)
	return true


func rotate_tile(cell: Vector3i, delta_steps: int = 1) -> bool:
	if not _tiles.has(cell):
		return false
	var steps: int = posmod(int(_angles[cell]) + delta_steps, 6)
	_angles[cell] = steps
	var tile: MeshInstance3D = _tiles[cell]
	tile.rotation.y = deg_to_rad(float(steps) * 60.0)
	_update_selected_direction()
	tile_rotated.emit(cell, steps)
	return true


func get_rotation_steps(cell: Vector3i) -> int:
	return int(_angles.get(cell, 0))


func shared_corner_count() -> int:
	var count: int = 0
	for key: Vector3i in _vertices:
		var group: Array = _vertices[key]
		count += group.size() * (group.size() - 1) / 2
	return count


func set_hover(cell: Vector3i, visible: bool = true) -> void:
	if _hover == null:
		return
	_hover.visible = visible and show_ghost and is_valid_cell(cell)
	if _hover.visible:
		_hover.position = NucleusHexLayout3D.axial_to_local(
			Vector2i(cell.x, cell.y), cell_radius, flat_top,
		)
		_hover.position.y = float(cell.z) * layer_step + tile_height + 0.07


func set_cell_radius(value: float) -> void:
	if not is_finite(value):
		return
	cell_radius = clampf(value, 0.1, 20.0)
	_rebuild_geometry()


func set_tile_height(value: float) -> void:
	if not is_finite(value):
		return
	tile_height = clampf(value, 0.05, 10.0)
	_rebuild_geometry()


func set_layer_step(value: float) -> void:
	if not is_finite(value):
		return
	layer_step = clampf(value, 0.1, 20.0)
	_rebuild_geometry()


func set_ring_count(value: int) -> void:
	ring_count = clampi(value, 1, MAX_RING)
	_rebuild_ghost()


func set_active_layer(value: int) -> void:
	active_layer = clampi(value, -8, 8)
	_rebuild_ghost()


func set_flat_top(value: bool) -> void:
	flat_top = value
	_rebuild_geometry()


func set_ghost_visible(value: bool) -> void:
	show_ghost = value
	if _ghost != null:
		_ghost.visible = value
	if _hover != null and not value:
		_hover.visible = false


func set_show_selected_orientation(enabled: bool) -> void:
	show_selected_orientation = enabled
	_update_selected_direction()


func clear_tiles() -> void:
	for cell: Vector3i in painted_cells():
		erase_cell(cell)


func _position_tile(tile: MeshInstance3D, cell: Vector3i) -> void:
	tile.position = NucleusHexLayout3D.axial_to_local(Vector2i(cell.x, cell.y), cell_radius, flat_top)
	tile.position.y = float(cell.z) * layer_step + tile_height * 0.5
	tile.rotation.y = deg_to_rad(float(int(_angles.get(cell, 0))) * 60.0)


## One unlit, directionally asymmetric gizmo (not a marker on every tile).
## Hex prisms are rotationally symmetric, so this shows their stored yaw.
func _update_selected_direction() -> void:
	if _selection_direction == null:
		return
	_selection_direction.visible = (
		show_selected_orientation and _selection_active
		and _tiles.has(_selected_cell)
	)
	if not _selection_direction.visible:
		return
	var axial := Vector2i(_selected_cell.x, _selected_cell.y)
	_selection_direction.position = NucleusHexLayout3D.axial_to_local(axial, cell_radius, flat_top)
	_selection_direction.position.y = (
		float(_selected_cell.z) * layer_step + tile_height + 0.035
	)
	var steps: int = int(_angles.get(_selected_cell, 0))
	_selection_direction.rotation.y = deg_to_rad(float(steps) * 60.0)


func _add_connections(cell: Vector3i) -> void:
	for corner: int in range(6):
		var key: Vector3i = NucleusHexLayout3D.corner_key(cell, corner)
		var other_corners: Array = _vertices.get(key, [])
		for other: Dictionary in other_corners:
			corner_connected.emit(
				cell, corner, other["cell"], int(other["corner"]),
				cell_corner_world(cell, corner),
			)
		other_corners.append({"cell": cell, "corner": corner})
		_vertices[key] = other_corners
	for side: int in range(6):
		var other_cell: Vector3i = _edge_cell(cell, side)
		if _tiles.has(other_cell):
			edge_connected.emit(cell, side, other_cell)


func _remove_connections(cell: Vector3i) -> void:
	for corner: int in range(6):
		var key: Vector3i = NucleusHexLayout3D.corner_key(cell, corner)
		var entries: Array = _vertices.get(key, [])
		for other: Dictionary in entries:
			if other["cell"] != cell:
				corner_disconnected.emit(
					cell, corner, other["cell"], int(other["corner"]),
					cell_corner_world(cell, corner),
				)
		for index: int in range(entries.size() - 1, -1, -1):
			if entries[index]["cell"] == cell:
				entries.remove_at(index)
		if entries.is_empty():
			_vertices.erase(key)
		else:
			_vertices[key] = entries
	for side: int in range(6):
		var other_cell: Vector3i = _edge_cell(cell, side)
		if _tiles.has(other_cell):
			edge_disconnected.emit(cell, side, other_cell)


static func _edge_cell(cell: Vector3i, side: int) -> Vector3i:
	var axial: Vector2i = NucleusHexLayout.edge_neighbor(
		Vector2i(cell.x, cell.y), side,
	)
	return Vector3i(axial.x, axial.y, cell.z)


func _rebuild_geometry() -> void:
	if not is_inside_tree() or _ghost == null:
		return
	_tile_mesh = _build_hex_prism(cell_radius, tile_height, flat_top)
	_selection_direction.mesh = _build_direction_arrow(cell_radius)
	for cell: Vector3i in _tiles:
		var tile: MeshInstance3D = _tiles[cell]
		tile.mesh = _tile_mesh
		_position_tile(tile, cell)
	_rebuild_ghost()
	_update_selected_direction()


func _rebuild_ghost() -> void:
	if _ghost == null:
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var line_y := float(active_layer) * layer_step + 0.035
	for axial: Vector2i in NucleusHexLayout3D.cells_in_radius(ring_count):
		for side: int in range(6):
			var other: Vector2i = NucleusHexLayout.edge_neighbor(axial, side)
			if NucleusHexLayout.in_radius(other, ring_count):
				if other.x < axial.x or (other.x == axial.x and other.y < axial.y):
					continue
			var a := NucleusHexLayout3D.corner_local(axial, side, cell_radius, flat_top)
			var b := NucleusHexLayout3D.corner_local(axial, side + 1, cell_radius, flat_top)
			a.y = line_y
			b.y = line_y
			mesh.surface_add_vertex(a)
			mesh.surface_add_vertex(b)
	mesh.surface_end()
	_ghost.mesh = mesh
	_ghost.visible = show_ghost
	var hover_mesh := ImmediateMesh.new()
	hover_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for index: int in range(6):
		hover_mesh.surface_add_vertex(
			NucleusHexLayout3D.corner_local(Vector2i.ZERO, index, cell_radius, flat_top)
		)
		hover_mesh.surface_add_vertex(
			NucleusHexLayout3D.corner_local(Vector2i.ZERO, index + 1, cell_radius, flat_top)
		)
	hover_mesh.surface_end()
	_hover.mesh = hover_mesh
	_hover.visible = false


static func _build_hex_prism(
	radius: float, height: float, flat_top: bool = false,
) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in range(6):
		var a := NucleusHexLayout3D.corner_local(Vector2i.ZERO, side, radius, flat_top)
		var b := NucleusHexLayout3D.corner_local(Vector2i.ZERO, side + 1, radius, flat_top)
		var top_a := Vector3(a.x, height * 0.5, a.z)
		var top_b := Vector3(b.x, height * 0.5, b.z)
		var bottom_a := Vector3(a.x, -height * 0.5, a.z)
		var bottom_b := Vector3(b.x, -height * 0.5, b.z)
		# Keep the hex uniformly coloured; a separate selected-tile arrow
		# communicates yaw without painting a confusing wedge on every tile.
		_triangle(surface, Vector3.UP, Vector3.UP * height * 0.5, top_a, top_b)
		_triangle(surface, Vector3.DOWN, Vector3.DOWN * height * 0.5, bottom_b, bottom_a)
		var outward := ((a + b) * 0.5).normalized()
		_triangle(surface, outward, top_a, bottom_a, bottom_b)
		_triangle(surface, outward, top_a, bottom_b, top_b)
	return surface.commit()


static func _build_direction_arrow(radius: float) -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := Vector3(0.0, 0.0, -0.66 * radius)
	var head_left := Vector3(-0.28 * radius, 0.0, -0.13 * radius)
	var head_right := Vector3(0.28 * radius, 0.0, -0.13 * radius)
	_triangle(mesh, Vector3.UP, tip, head_left, head_right)
	var left_front := Vector3(-0.085 * radius, 0.0, -0.12 * radius)
	var right_front := Vector3(0.085 * radius, 0.0, -0.12 * radius)
	var left_back := Vector3(-0.085 * radius, 0.0, 0.42 * radius)
	var right_back := Vector3(0.085 * radius, 0.0, 0.42 * radius)
	_triangle(mesh, Vector3.UP, left_front, left_back, right_front)
	_triangle(mesh, Vector3.UP, right_front, left_back, right_back)
	return mesh.commit()


static func _triangle(
	surface: SurfaceTool, normal: Vector3, a: Vector3, b: Vector3, c: Vector3,
	color: Color = Color.WHITE,
) -> void:
	for point: Vector3 in [a, b, c]:
		surface.set_normal(normal)
		surface.set_color(color)
		surface.add_vertex(point)
