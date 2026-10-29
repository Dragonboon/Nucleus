@tool
class_name NucleusAnimationEventBinding
extends Node
## Filters one semantic event from NucleusAnimationEventRelay.
##
## This removes repetitive event-id checks from ordinary scene scripts.

signal triggered(payload: Variant)

@export var relay: NucleusAnimationEventRelay:
	set(value):
		_disconnect_relay()
		relay = value
		_connect_relay()
		update_configuration_warnings()

@export var event_id: StringName:
	set(value):
		event_id = value
		update_configuration_warnings()


func _ready() -> void:
	_resolve_dependencies()
	_connect_relay()


func _exit_tree() -> void:
	_disconnect_relay()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if relay == null:
		warnings.append(
			"Assign an AnimationEventRelay or place one nearby."
		)

	if event_id == &"":
		warnings.append("event_id is required.")

	return warnings


func _on_event_received(
	received_id: StringName,
	payload: Variant,
) -> void:
	if received_id == event_id:
		triggered.emit(payload)


func _connect_relay() -> void:
	if relay == null:
		return

	if not relay.event_received.is_connected(_on_event_received):
		relay.event_received.connect(_on_event_received)


func _disconnect_relay() -> void:
	if relay == null:
		return

	if relay.event_received.is_connected(_on_event_received):
		relay.event_received.disconnect(_on_event_received)


func _resolve_dependencies() -> void:
	if relay != null:
		return

	var root := get_parent()

	while root != null and relay == null:
		if root is NucleusAnimationEventRelay:
			relay = root as NucleusAnimationEventRelay
			break

		for node: Node in NucleusNodeUtils.descendants(root):
			if node is NucleusAnimationEventRelay:
				relay = node as NucleusAnimationEventRelay
				break

		root = root.get_parent()
