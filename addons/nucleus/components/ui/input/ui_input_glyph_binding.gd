class_name NucleusInputGlyphBinding
extends Node
## Presents the current action binding as a game-owned glyph with text fallback.
##
## Core Input remains authoritative for binding/source/family state. This
## component owns only the assigned TextureRect/Label presentation.

signal glyph_changed(
	texture: Texture2D,
	fallback_text: String,
	source: int,
)

@export var action: StringName
@export var profile: NucleusInputGlyphProfile

@export_group("Targets")
@export var glyph_target: TextureRect
@export var fallback_label: Label
@export var manage_visibility: bool = true
@export var show_fallback_text: bool = true

@export_group("Binding")
@export_range(0, 8, 1, "or_greater")
var binding_index: int = 0
@export var follow_active_source: bool = true
@export_enum("Keyboard & Mouse:1", "Gamepad:2", "Touch:3")
var fixed_source: int = NucleusInputTypes.Source.KEYBOARD_MOUSE


func _ready() -> void:
	_resolve_targets()

	NucleusInput.input_source_changed.connect(_on_input_source_changed)
	NucleusInput.active_gamepad_changed.connect(_on_active_gamepad_changed)
	NucleusInput.action_binding_changed.connect(_on_action_binding_changed)

	refresh()


func _exit_tree() -> void:
	if NucleusInput.input_source_changed.is_connected(_on_input_source_changed):
		NucleusInput.input_source_changed.disconnect(_on_input_source_changed)

	if NucleusInput.active_gamepad_changed.is_connected(
		_on_active_gamepad_changed
	):
		NucleusInput.active_gamepad_changed.disconnect(
			_on_active_gamepad_changed
		)

	if NucleusInput.action_binding_changed.is_connected(
		_on_action_binding_changed
	):
		NucleusInput.action_binding_changed.disconnect(
			_on_action_binding_changed
		)


func refresh() -> void:
	var source := _get_source()
	var events: Array[InputEvent] = NucleusInput.get_action_events(
		action,
		source,
	)
	var event: InputEvent

	if binding_index >= 0 and binding_index < events.size():
		event = events[binding_index]

	var texture: Texture2D

	if profile and event:
		texture = profile.resolve_event(
			event,
			NucleusInput.active_gamepad_family,
		)

	var fallback_text := NucleusInput.get_binding_text(
		action,
		source,
		binding_index,
	)

	if glyph_target:
		glyph_target.texture = texture

		if manage_visibility:
			glyph_target.visible = texture != null

	if fallback_label:
		fallback_label.text = fallback_text

		if manage_visibility:
			fallback_label.visible = (
				texture == null
				and show_fallback_text
				and not fallback_text.is_empty()
			)

	glyph_changed.emit(
		texture,
		fallback_text,
		source,
	)


func _resolve_targets() -> void:
	if glyph_target == null:
		glyph_target = get_parent() as TextureRect


func _get_source() -> int:
	return (
		NucleusInput.active_source
		if follow_active_source
		else fixed_source
	)


func _on_input_source_changed(
	_source: int,
	_previous_source: int,
) -> void:
	if follow_active_source:
		refresh()


func _on_active_gamepad_changed(
	_device_id: int,
	_family: int,
) -> void:
	if _get_source() == NucleusInputTypes.Source.GAMEPAD:
		refresh()


func _on_action_binding_changed(changed_action: StringName) -> void:
	if changed_action == action:
		refresh()
