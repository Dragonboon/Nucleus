class_name NucleusModularVariantBinding3D
extends Node3D
## Optional visual-only presenter for descriptors from NucleusModularNeighborhood.
## Scene assets come from a trusted PlacementVariantSet3D; never from an input ID.

signal variant_applied(cell: Vector3i, variant_id: StringName)
signal variant_rejected(cell: Vector3i, variant_id: StringName)

@export var catalog: NucleusPlacementVariantSet3D
@export var square_board: NucleusSquareBoard3D

var _visuals: Dictionary = {}


func apply_updates(updates: Array[Dictionary]) -> void:
	if catalog == null or square_board == null:
		return
	if not catalog.validate().is_empty():
		return
	for update: Dictionary in updates:
		var cell: Vector3i = update.get("cell", Vector3i.ZERO)
		var present: bool = bool(update.get("occupied", false))
		var variant_id: StringName = update.get("variant_id", &"")
		if not present or variant_id == &"":
			_remove_visual(cell)
			continue
		var index: int = catalog.find_index(variant_id)
		if index < 0:
			variant_rejected.emit(cell, variant_id)
			continue
		var old: Dictionary = _visuals.get(cell, {})
		var rotation_steps: int = posmod(int(update.get("rotation_steps", 0)), 4)
		if old.get("variant_id", &"") == variant_id:
			var old_node: Node3D = old.get("node")
			if is_instance_valid(old_node):
				old_node.rotation.y = float(rotation_steps) * PI * 0.5
				continue
		var scene: PackedScene = catalog.variants[index].scene
		var instance: Node = scene.instantiate()
		if not instance is Node3D:
			if instance != null:
				instance.free()
			variant_rejected.emit(cell, variant_id)
			continue
		var visual: Node3D = instance as Node3D
		# This presenter intentionally does not materialize colliders or gameplay.
		if _contains_physics(visual):
			visual.free()
			variant_rejected.emit(cell, variant_id)
			continue
		_remove_visual(cell)
		add_child(visual)
		visual.global_position = square_board.cell_to_world(cell)
		visual.global_rotation.y = square_board.global_rotation.y + float(rotation_steps) * PI * 0.5
		_visuals[cell] = {"node": visual, "variant_id": variant_id}
		variant_applied.emit(cell, variant_id)


func clear_visuals() -> void:
	for cell: Vector3i in _visuals.keys():
		_remove_visual(cell)


func _remove_visual(cell: Vector3i) -> void:
	if not _visuals.has(cell):
		return
	var node: Node3D = _visuals[cell]["node"]
	_visuals.erase(cell)
	if is_instance_valid(node):
		node.queue_free()

## Guard against accidentally spawning real placeables as cosmetic duplicates.
func _contains_physics(root: Node) -> bool:
	if root is CollisionObject3D or root is CollisionShape3D:
		return true
	for child: Node in root.get_children():
		if _contains_physics(child):
			return true
	return false
