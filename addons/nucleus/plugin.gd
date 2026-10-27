@tool
extends EditorPlugin

const Dock = preload("res://addons/nucleus/editor/package_dock.gd")
var _dock: Control

func _enter_tree() -> void:
	_dock = Dock.new()
	_dock.name = "Nucleus"
	add_control_to_bottom_panel(_dock, "Nucleus")

func _exit_tree() -> void:
	if is_instance_valid(_dock):
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
