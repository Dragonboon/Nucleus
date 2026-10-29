class_name NucleusDevelopmentTools
extends Node
## Ready-to-instance debug shell containing a command registry and palette.

@export var debug_build_only: bool = true
@export var toggle_action: StringName = &""
@export var start_open: bool = false

@onready var registry: NucleusDevelopmentCommandRegistry = %Registry
@onready var palette: NucleusDevelopmentCommandPalette = %Palette


func _enter_tree() -> void:
	var registry_node := get_node_or_null("Registry") as NucleusDevelopmentCommandRegistry
	if registry_node != null:
		registry_node.debug_build_only = debug_build_only


func _ready() -> void:
	if debug_build_only and not OS.is_debug_build():
		queue_free()
		return

	if not toggle_action.is_empty() and not InputMap.has_action(toggle_action):
		push_warning(
			"DevelopmentTools toggle_action '%s' is not defined in InputMap."
			% str(toggle_action)
		)
	if start_open:
		palette.open_palette()


func _unhandled_input(event: InputEvent) -> void:
	if toggle_action.is_empty() or not InputMap.has_action(toggle_action):
		return
	if event.is_action_pressed(toggle_action):
		toggle_palette()
		get_viewport().set_input_as_handled()


func open_palette() -> void:
	palette.open_palette()


func close_palette() -> void:
	palette.close_palette()


func toggle_palette() -> void:
	if palette.is_open():
		close_palette()
	else:
		open_palette()


func get_registry() -> NucleusDevelopmentCommandRegistry:
	return registry
