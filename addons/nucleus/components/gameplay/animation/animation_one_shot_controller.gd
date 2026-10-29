@tool
class_name NucleusAnimationOneShotController
extends Node
## Semantic runtime control for authored AnimationNodeOneShot nodes.
##
## The AnimationTree graph and filters remain native Godot content.

signal one_shot_requested(
	slot_id: StringName,
	request: int,
)

@export var animation_tree: AnimationTree:
	set(value):
		animation_tree = value
		update_configuration_warnings()

@export var slots: Array[NucleusAnimationOneShotSlot] = []:
	set(value):
		slots = value
		_rebuild_slot_map()
		update_configuration_warnings()

var _slot_map: Dictionary[StringName, NucleusAnimationOneShotSlot] = {}


func _ready() -> void:
	_resolve_dependencies()
	_rebuild_slot_map()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if animation_tree == null:
		warnings.append(
			"Assign an AnimationTree or place one near this controller."
		)

	var known: Dictionary[StringName, bool] = {}

	for index: int in range(slots.size()):
		var slot := slots[index]

		if slot == null:
			warnings.append("slots[%d] is null." % index)
			continue

		for error: String in slot.get_validation_errors():
			warnings.append("slots[%d]: %s" % [index, error])

		if slot.slot_id != &"":
			if known.has(slot.slot_id):
				warnings.append(
					"Duplicate one-shot slot_id '%s'." % slot.slot_id
				)
			known[slot.slot_id] = true

	return warnings


func fire(slot_id: StringName) -> Error:
	return request(
		slot_id,
		AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE,
	)


func abort(
	slot_id: StringName,
	fade_out: bool = true,
) -> Error:
	var request_value := (
		AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT
		if fade_out
		else AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
	)
	return request(slot_id, request_value)


func request(
	slot_id: StringName,
	request_value: int,
) -> Error:
	if animation_tree == null:
		return ERR_UNCONFIGURED

	var slot: NucleusAnimationOneShotSlot = _slot_map.get(slot_id)

	if slot == null:
		return ERR_DOES_NOT_EXIST

	var parameter := slot.get_request_parameter()

	if parameter == &"":
		return ERR_INVALID_DATA

	animation_tree.set(parameter, request_value)
	one_shot_requested.emit(slot_id, request_value)
	return OK


func is_active(slot_id: StringName) -> bool:
	if animation_tree == null:
		return false

	var slot: NucleusAnimationOneShotSlot = _slot_map.get(slot_id)

	if slot == null:
		return false

	var parameter := slot.get_active_parameter()

	if parameter == &"":
		return false

	return bool(animation_tree.get(parameter))


func refresh_slots() -> void:
	_rebuild_slot_map()


func _rebuild_slot_map() -> void:
	_slot_map.clear()

	for slot: NucleusAnimationOneShotSlot in slots:
		if slot == null or slot.slot_id == &"":
			continue
		if not _slot_map.has(slot.slot_id):
			_slot_map[slot.slot_id] = slot


func _resolve_dependencies() -> void:
	if animation_tree != null:
		return

	var root := get_parent()

	while root != null and animation_tree == null:
		if root is AnimationTree:
			animation_tree = root as AnimationTree
			break

		for node: Node in NucleusNodeUtils.descendants(root):
			if node is AnimationTree:
				animation_tree = node as AnimationTree
				break

		root = root.get_parent()
