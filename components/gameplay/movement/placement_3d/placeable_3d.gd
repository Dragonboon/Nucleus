@tool
class_name NucleusPlaceable3D
extends Node3D
## Attach to a placeable scene root, or as a direct child with target=root.
## Only authored identity and admission metadata live here; world/save owners
## and multiplayer authority remain in the consuming game.

@export var target: Node3D
@export var profile: NucleusPlacementProfile3D
@export var stable_id: StringName = &""

var _visual_bounds_cache: Dictionary = {}


## Call this after procedurally modifying a placeable's child meshes.
func invalidate_visual_bounds() -> void:
	_visual_bounds_cache.clear()


func get_visual_bounds() -> Dictionary:
	if _visual_bounds_cache.is_empty():
		_visual_bounds_cache = NucleusPlacementGeometry3D.get_visual_bounds(get_root())
	return _visual_bounds_cache


func _ready() -> void:
	if target == null:
		target = self


func get_root() -> Node3D:
	return target if target != null else self


func get_configuration_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if profile == null:
		errors.append("Assign a NucleusPlacementProfile3D.")
	else:
		errors.append_array(profile.validate())
	return errors


func _get_configuration_warnings() -> PackedStringArray:
	return get_configuration_errors()


## The root can contain a composed placeable instead of extending it.
static func find_in(root: Node) -> NucleusPlaceable3D:
	if root == null:
		return null
	if root is NucleusPlaceable3D:
		return root as NucleusPlaceable3D
	for child: Node in root.get_children():
		var found := find_in(child)
		if found != null:
			return found
	return null


## Only a collider's own root/ancestor may supply its support metadata.
static func find_for_collider(collider: Object) -> NucleusPlaceable3D:
	var current := collider as Node
	while current != null:
		if current is NucleusPlaceable3D:
			return current as NucleusPlaceable3D
		for child: Node in current.get_children():
			if child is NucleusPlaceable3D:
				var placeable := child as NucleusPlaceable3D
				if placeable.get_root() == current:
					return placeable
		current = current.get_parent()
	return null


static func collision_rids(root: Node) -> Array[RID]:
	var result: Array[RID] = []
	if root == null:
		return result
	_append_rids(root, result)
	return result


static func _append_rids(node: Node, out: Array[RID]) -> void:
	if node is CollisionObject3D:
		out.append((node as CollisionObject3D).get_rid())
	for child: Node in node.get_children():
		_append_rids(child, out)
