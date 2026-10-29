class_name NucleusInputDeviceToastBinding
extends Node
## Bridges NucleusInput gamepad connection signals into a scene-owned toast host.

@export var toast_host: NucleusUIToastHost

@export_group("Connection")
@export var show_connected: bool = true
@export var connected_title: String = "Controller connected"
@export var connected_message: String = "{device} is ready."

@export_group("Disconnection")
@export var show_disconnected: bool = true
@export var disconnected_title: String = "Controller disconnected"
@export var disconnected_message: String = "{device} was disconnected."

@export_group("Presentation")
@export_range(0.1, 30.0, 0.1, "or_greater")
var duration: float = 3.0
@export var priority: int = 10


func _ready() -> void:
	_resolve_host()

	if toast_host == null:
		NucleusLog.error(
			"%s requires a NucleusUIToastHost." % get_path(),
			&"InputDeviceToast",
		)
		return

	NucleusInput.gamepad_connected.connect(_on_gamepad_connected)
	NucleusInput.gamepad_disconnected.connect(_on_gamepad_disconnected)


func _exit_tree() -> void:
	if NucleusInput.gamepad_connected.is_connected(_on_gamepad_connected):
		NucleusInput.gamepad_connected.disconnect(_on_gamepad_connected)

	if NucleusInput.gamepad_disconnected.is_connected(_on_gamepad_disconnected):
		NucleusInput.gamepad_disconnected.disconnect(_on_gamepad_disconnected)


func _on_gamepad_connected(device_id: int, device_name: String) -> void:
	if not show_connected or toast_host == null:
		return

	toast_host.enqueue(
		_format_message(connected_message, device_name),
		tr(connected_title),
		duration,
		StringName("gamepad_connected_%d" % device_id),
		priority,
	)


func _on_gamepad_disconnected(device_id: int, device_name: String) -> void:
	if not show_disconnected or toast_host == null:
		return

	toast_host.enqueue(
		_format_message(disconnected_message, device_name),
		tr(disconnected_title),
		duration,
		StringName("gamepad_disconnected_%d" % device_id),
		priority,
	)


func _format_message(template: String, device_name: String) -> String:
	var resolved_name: String = device_name

	if resolved_name.is_empty():
		resolved_name = tr("Controller")

	return tr(template).replace("{device}", resolved_name)


func _resolve_host() -> void:
	if toast_host:
		return

	var parent: Node = get_parent()

	if parent is NucleusUIToastHost:
		toast_host = parent as NucleusUIToastHost
		return

	if parent:
		for child: Node in parent.get_children():
			if child is NucleusUIToastHost:
				toast_host = child as NucleusUIToastHost
				return
