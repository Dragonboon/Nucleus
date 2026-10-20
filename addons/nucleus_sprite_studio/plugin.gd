@tool
extends EditorPlugin
## The native EditorDock supports side panels, bottom panel and floating layout.

const STUDIO_DOCK := preload("res://addons/nucleus_sprite_studio/studio_dock.gd")

var _dock: EditorDock


func _enter_tree() -> void:
	_dock = EditorDock.new()
	_dock.name = "NucleusSpriteStudio"
	_dock.title = "Sprite Studio"
	_dock.layout_key = "nucleus_sprite_studio"
	_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_BL
	_dock.available_layouts = EditorDock.DOCK_LAYOUT_ALL
	var content := STUDIO_DOCK.new()
	content.name = "Sprite Studio"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock.add_child(content)
	add_dock(_dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_dock(_dock)
		_dock.queue_free()
		_dock = null
