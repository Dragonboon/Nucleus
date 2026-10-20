@tool
extends EditorPlugin

const STUDIO_DOCK := preload("res://addons/nucleus_sprite_studio/studio_dock.gd")

var _dock: Control


func _enter_tree() -> void:
	_dock = STUDIO_DOCK.new()
	add_control_to_bottom_panel(_dock, "Sprite Studio")


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
