@tool
extends EditorPlugin
## Keep the plugin active while allowing its dock to be temporarily closed.

const STUDIO_DOCK := preload("res://addons/nucleus_sprite_studio/studio_dock.gd")
const STUDIO_ICON := preload("res://addons/nucleus_sprite_studio/studio_icon.svg")

var _dock: EditorDock
var _toolbar_toggle: Button


func _enter_tree() -> void:
	_dock = EditorDock.new()
	_dock.name = "NucleusSpriteStudio"
	_dock.title = "Sprite Studio"
	_dock.dock_icon = STUDIO_ICON
	_dock.force_show_icon = true
	_dock.title_color = Color("#65d6e8")
	_dock.layout_key = "nucleus_sprite_studio"
	_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_BL
	_dock.available_layouts = EditorDock.DOCK_LAYOUT_ALL
	_dock.closable = true
	var content := STUDIO_DOCK.new()
	content.name = "Sprite Studio"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock.add_child(content)
	_dock.closed.connect(_on_dock_closed)
	_dock.opened.connect(_on_dock_opened)
	add_dock(_dock)

	_toolbar_toggle = Button.new()
	_toolbar_toggle.icon = STUDIO_ICON
	_toolbar_toggle.text = "Sprite Studio  ● ON"
	_toolbar_toggle.tooltip_text = (
		"Sprite Studio plugin is enabled. Click to show or hide its dock. "
		+ "This does not disable the plugin."
	)
	_toolbar_toggle.toggle_mode = true
	_toolbar_toggle.button_pressed = true
	_toolbar_toggle.toggled.connect(_toggle_dock)
	add_control_to_container(CONTAINER_TOOLBAR, _toolbar_toggle)


func _exit_tree() -> void:
	if _toolbar_toggle != null:
		remove_control_from_container(CONTAINER_TOOLBAR, _toolbar_toggle)
		_toolbar_toggle.queue_free()
		_toolbar_toggle = null
	if _dock != null:
		remove_dock(_dock)
		_dock.queue_free()
		_dock = null


func _toggle_dock(show_dock: bool) -> void:
	if _dock == null:
		return
	if show_dock:
		_dock.make_visible()
	else:
		_dock.close()
	_update_toggle_label(show_dock)


func _on_dock_closed() -> void:
	_update_toggle_label(false)


func _on_dock_opened() -> void:
	_update_toggle_label(true)


func _update_toggle_label(visible_dock: bool) -> void:
	if _toolbar_toggle == null:
		return
	_toolbar_toggle.set_pressed_no_signal(visible_dock)
	_toolbar_toggle.text = "Sprite Studio  ● ON" if visible_dock else "Sprite Studio  ○"
	_toolbar_toggle.tooltip_text = (
		"Plugin enabled; dock visible. Click to hide."
		if visible_dock else "Plugin enabled; dock closed. Click to open."
	)
