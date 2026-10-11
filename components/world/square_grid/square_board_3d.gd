class_name NucleusSquareBoard3D
extends Node3D
## Bounded scene-owned square occupancy, with optional native mesh diagnostics.
## Visual tiles are placeholders, not collision-tested placement or GridMap cells.

signal tile_painted(cell: Vector3i)
signal tile_erased(cell: Vector3i)
signal tile_rotated(cell: Vector3i, steps: int)

const MAX_TILES: int = 1024
const MIN_LAYER: int = -8
const MAX_LAYER: int = 8
const MAX_HALF_EXTENT: int = 24

@export var cell_spacing: Vector2 = Vector2(2.0, 2.0)
@export_range(0.1, 10.0, 0.1) var layer_step: float = 2.0
@export_range(0.05, 2.0, 0.05) var tile_height: float = 0.25
@export_range(1, 24, 1) var half_extent: int = 8
@export_range(-8, 8, 1) var active_layer: int = 0
@export var show_ghost: bool = true
@export var show_selected_orientation: bool = true

var _tiles: Dictionary = {} # Vector3i -> {node: MeshInstance3D, rotation: int}
var _mesh: BoxMesh
var _material: StandardMaterial3D
var _selected_material: StandardMaterial3D
var _ghost: MeshInstance3D
var _hover: MeshInstance3D
var _selection_direction: MeshInstance3D
var _has_selection: bool = false
var _selected_cell: Vector3i = Vector3i.ZERO
var _has_hover: bool = false
var _hover_cell: Vector3i = Vector3i.ZERO


func _ready() -> void:
	_mesh = BoxMesh.new()
	_mesh.size = Vector3(cell_spacing.x * 0.94, tile_height, cell_spacing.y * 0.94)
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.30, 0.65, 0.75)
	_selected_material = _material.duplicate() as StandardMaterial3D
	_selected_material.albedo_color = Color(1.0, 0.77, 0.26)

	_ghost = MeshInstance3D.new()
	_ghost.name = "GhostGrid"
	_ghost.material_override = _line_material(Color(0.22, 0.85, 1.0, 0.74))
	add_child(_ghost)

	_hover = MeshInstance3D.new()
	_hover.name = "HoverCell"
	_hover.material_override = _line_material(Color(1.0, 0.85, 0.27, 1.0))
	add_child(_hover)

	_selection_direction = MeshInstance3D.new()
	_selection_direction.name = "SelectedOrientation"
	var arrow_material := StandardMaterial3D.new()
	arrow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	arrow_material.albedo_color = Color(1.0, 0.81, 0.24)
	_selection_direction.material_override = arrow_material
	add_child(_selection_direction)

	_rebuild_visual_geometry()
	_update_ghost_layer()
	_update_selection_marker()
	_hover.visible = false


func is_valid_cell(cell: Vector3i) -> bool:
	var extent: int = clampi(half_extent, 1, MAX_HALF_EXTENT)
	return (
		absi(cell.x) <= extent and absi(cell.y) <= extent
		and cell.z >= MIN_LAYER and cell.z <= MAX_LAYER
	)


func cell_to_world(cell: Vector3i) -> Vector3:
	return to_global(NucleusSquareLayout.local_3d(cell, cell_spacing, layer_step))


func world_to_cell(world: Vector3, layer: int = 0) -> Vector3i:
	if not world.is_finite() or not cell_spacing.is_finite():
		return Vector3i.ZERO
	if cell_spacing.x <= 0.0 or cell_spacing.y <= 0.0:
		return Vector3i.ZERO
	var local: Vector3 = to_local(world)
	return Vector3i(
		roundi(local.x / cell_spacing.x),
		roundi(local.z / cell_spacing.y),
		layer,
	)


func intersect_cursor(camera: Camera3D, screen: Vector2, layer: int = 0) -> Dictionary:
	if camera == null or layer < MIN_LAYER or layer > MAX_LAYER:
		return {}
	var plane := Plane(
		global_transform.basis.y.normalized(),
		to_global(Vector3.UP * float(layer) * layer_step),
	)
	var point: Variant = plane.intersects_ray(
		camera.project_ray_origin(screen),
		camera.project_ray_normal(screen),
	)
	if point == null:
		return {}
	var cell: Vector3i = world_to_cell(point as Vector3, layer)
	return {"cell": cell, "world_position": cell_to_world(cell)} if is_valid_cell(cell) else {}


func has_tile(cell: Vector3i) -> bool:
	return _tiles.has(cell)


func tile_at(cell: Vector3i) -> Node3D:
	return _tiles[cell]["node"] if has_tile(cell) else null


func tile_count() -> int:
	return _tiles.size()


func painted_cells() -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for cell: Vector3i in _tiles:
		cells.append(cell)
	return cells


func paint_cell(cell: Vector3i) -> bool:
	if (
		not is_inside_tree() or _mesh == null
		or not is_valid_cell(cell) or has_tile(cell)
		or tile_count() >= MAX_TILES
	):
		return false
	var tile := MeshInstance3D.new()
	tile.name = "Square_%d_%d_%d" % [cell.x, cell.y, cell.z]
	tile.mesh = _mesh
	tile.material_override = _material
	tile.position = NucleusSquareLayout.local_3d(cell, cell_spacing, layer_step)
	add_child(tile)
	_tiles[cell] = {"node": tile, "rotation": 0}
	tile_painted.emit(cell)
	return true


func erase_cell(cell: Vector3i) -> bool:
	if not has_tile(cell):
		return false
	if _has_selection and _selected_cell == cell:
		_has_selection = false
		_update_selection_marker()
	var tile: MeshInstance3D = _tiles[cell]["node"]
	_tiles.erase(cell)
	tile.queue_free()
	tile_erased.emit(cell)
	return true


func rotate_tile(cell: Vector3i, steps: int = 1) -> bool:
	if not has_tile(cell):
		return false
	var data: Dictionary = _tiles[cell]
	data["rotation"] = posmod(int(data["rotation"]) + steps, 4)
	(data["node"] as MeshInstance3D).rotation.y = float(data["rotation"]) * PI * 0.5
	_update_selection_marker()
	tile_rotated.emit(cell, int(data["rotation"]))
	return true


func get_rotation_steps(cell: Vector3i) -> int:
	return int(_tiles[cell]["rotation"]) if has_tile(cell) else 0


func has_selection() -> bool:
	return _has_selection and has_tile(_selected_cell)


func get_selected_cell() -> Vector3i:
	return _selected_cell


func highlight_selection(cell: Vector3i, enabled: bool = true) -> void:
	if has_selection():
		var old_tile: MeshInstance3D = _tiles[_selected_cell]["node"]
		old_tile.material_override = _material
	_has_selection = enabled and has_tile(cell)
	if _has_selection:
		_selected_cell = cell
		var tile: MeshInstance3D = _tiles[cell]["node"]
		tile.material_override = _selected_material
	_update_selection_marker()


func set_hover(cell: Vector3i, enabled: bool = true) -> void:
	var visible: bool = enabled and show_ghost and is_valid_cell(cell)
	if _has_hover == visible and (not visible or _hover_cell == cell):
		return
	_has_hover = visible
	_hover_cell = cell
	if _hover == null:
		return
	_hover.visible = visible
	if visible:
		_hover.position = NucleusSquareLayout.local_3d(cell, cell_spacing, layer_step)
		_hover.position.y += tile_height * 0.5 + 0.06


## Moving the ghost plane must not rewrite existing tile coordinates or rotations.
func set_active_layer(value: int) -> void:
	var layer: int = clampi(value, MIN_LAYER, MAX_LAYER)
	if layer == active_layer:
		return
	active_layer = layer
	if has_selection() and _selected_cell.z != layer:
		highlight_selection(_selected_cell, false)
	_update_ghost_layer()
	_has_hover = false
	if _hover != null:
		_hover.visible = false


func set_ghost_visible(enabled: bool) -> void:
	show_ghost = enabled
	if _ghost != null:
		_ghost.visible = enabled
	if not enabled:
		set_hover(_hover_cell, false)


func set_show_selected_orientation(enabled: bool) -> void:
	show_selected_orientation = enabled
	_update_selection_marker()


func clear_tiles() -> void:
	for cell: Vector3i in painted_cells():
		erase_cell(cell)
	highlight_selection(Vector3i.ZERO, false)


func _line_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = true
	return material


func _rebuild_visual_geometry() -> void:
	if _ghost == null:
		return
	var extent: int = clampi(half_extent, 1, MAX_HALF_EXTENT)
	var minimum_x: float = (-float(extent) - 0.5) * cell_spacing.x
	var maximum_x: float = (float(extent) + 0.5) * cell_spacing.x
	var minimum_z: float = (-float(extent) - 0.5) * cell_spacing.y
	var maximum_z: float = (float(extent) + 0.5) * cell_spacing.y
	var lines := PackedVector3Array()
	# Draw each grid boundary once, not four edges for every cell.
	for edge in range(-extent, extent + 2):
		var x: float = (float(edge) - 0.5) * cell_spacing.x
		var z: float = (float(edge) - 0.5) * cell_spacing.y
		lines.append(Vector3(x, 0, minimum_z))
		lines.append(Vector3(x, 0, maximum_z))
		lines.append(Vector3(minimum_x, 0, z))
		lines.append(Vector3(maximum_x, 0, z))
	_ghost.mesh = _array_mesh(Mesh.PRIMITIVE_LINES, lines)

	var half_x: float = cell_spacing.x * 0.49
	var half_z: float = cell_spacing.y * 0.49
	var corners: Array[Vector3] = [
		Vector3(-half_x, 0, -half_z), Vector3(half_x, 0, -half_z),
		Vector3(half_x, 0, half_z), Vector3(-half_x, 0, half_z),
	]
	var outline := PackedVector3Array()
	for side in range(4):
		outline.append(corners[side])
		outline.append(corners[(side + 1) % 4])
	_hover.mesh = _array_mesh(Mesh.PRIMITIVE_LINES, outline)

	var width: float = minf(cell_spacing.x, cell_spacing.y)
	var arrow := PackedVector3Array([
		Vector3(-width * 0.17, 0, width * 0.16),
		Vector3(0, 0, -width * 0.36),
		Vector3(width * 0.17, 0, width * 0.16),
	])
	_selection_direction.mesh = _array_mesh(Mesh.PRIMITIVE_TRIANGLES, arrow)


func _array_mesh(primitive: Mesh.PrimitiveType, vertices: PackedVector3Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(primitive, arrays)
	return mesh


func _update_ghost_layer() -> void:
	if _ghost == null:
		return
	_ghost.visible = show_ghost
	_ghost.position.y = float(active_layer) * layer_step + tile_height * 0.5 + 0.03


func _update_selection_marker() -> void:
	if _selection_direction == null:
		return
	_selection_direction.visible = show_selected_orientation and has_selection()
	if not _selection_direction.visible:
		return
	_selection_direction.position = NucleusSquareLayout.local_3d(
		_selected_cell, cell_spacing, layer_step,
	)
	_selection_direction.position.y += tile_height * 0.5 + 0.075
	_selection_direction.rotation.y = float(get_rotation_steps(_selected_cell)) * PI * 0.5
