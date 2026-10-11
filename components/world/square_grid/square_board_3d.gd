class_name NucleusSquareBoard3D
extends Node3D
## Lightweight optional visual occupancy. Godot GridMap owns production meshes.
signal tile_painted(cell: Vector3i)
signal tile_erased(cell: Vector3i)
signal tile_rotated(cell: Vector3i, steps: int)

@export var cell_spacing: Vector2 = Vector2(2.0, 2.0)
@export_range(0.1, 10.0, 0.1) var layer_step: float = 2.0
@export_range(0.05, 2.0, 0.05) var tile_height: float = 0.25
@export_range(1, 24, 1) var half_extent: int = 8
@export_range(-8, 8, 1) var active_layer: int = 0
var _tiles: Dictionary = {}
var _mesh: BoxMesh
var _material: StandardMaterial3D

func _ready() -> void:
	_mesh = BoxMesh.new()
	_mesh.size = Vector3(cell_spacing.x * 0.94, tile_height, cell_spacing.y * 0.94)
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.3, 0.65, 0.75)

func is_valid_cell(cell: Vector3i) -> bool:
	return (
		absi(cell.x) <= half_extent and absi(cell.y) <= half_extent
		and absi(cell.z) <= 8
	)

func cell_to_world(cell: Vector3i) -> Vector3:
	return to_global(NucleusSquareLayout.local_3d(cell, cell_spacing, layer_step))

func world_to_cell(world: Vector3, layer: int = 0) -> Vector3i:
	var local: Vector3 = to_local(world)
	return Vector3i(roundi(local.x / cell_spacing.x), roundi(local.z / cell_spacing.y), layer)

func intersect_cursor(camera: Camera3D, screen: Vector2, layer: int = 0) -> Dictionary:
	if camera == null or layer < -8 or layer > 8:
		return {}
	var plane := Plane(global_transform.basis.y.normalized(),
		to_global(Vector3.UP * float(layer) * layer_step))
	var point: Variant = plane.intersects_ray(
		camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	if point == null:
		return {}
	var cell: Vector3i = world_to_cell(point, layer)
	return {"cell": cell, "world_position": cell_to_world(cell)} if is_valid_cell(cell) else {}

func has_tile(cell: Vector3i) -> bool:
	return _tiles.has(cell)

func tile_count() -> int:
	return _tiles.size()

func paint_cell(cell: Vector3i) -> bool:
	if not is_inside_tree() or not is_valid_cell(cell) or has_tile(cell) or tile_count() >= 1024:
		return false
	var tile := MeshInstance3D.new()
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
	tile_rotated.emit(cell, int(data["rotation"]))
	return true

func get_rotation_steps(cell: Vector3i) -> int:
	return int(_tiles[cell]["rotation"]) if has_tile(cell) else 0

func clear_tiles() -> void:
	for cell: Vector3i in _tiles.keys():
		erase_cell(cell)
