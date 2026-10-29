class_name NucleusUITooltipBinding
extends Node
## Translation-aware adapter over Godot's native Control tooltip system.
##
## Native tooltips already support Theme styling, project-wide delay, and
## button shortcut text. This component only handles reusable translated text.

@export var target: Control

@export var text_key: StringName
@export_multiline var fallback_text: String = ""

@export var mirror_to_accessibility_description: bool = true
@export var overwrite_accessibility_description: bool = false

var _owns_accessibility_description: bool = false


func _ready() -> void:
	if not _resolve_target():
		return

	_apply_tooltip()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and target:
		_apply_tooltip()


func refresh() -> void:
	if target:
		_apply_tooltip()


func _resolve_target() -> bool:
	if target == null:
		target = get_parent() as Control

	if target:
		return true

	NucleusLog.error(
		"%s requires a Control target or parent." % get_path(),
		&"UITooltip",
	)

	return false


func _apply_tooltip() -> void:
	var text: String = _resolve_text()

	target.tooltip_text = text

	if not mirror_to_accessibility_description:
		return

	if (
		overwrite_accessibility_description
		or _owns_accessibility_description
		or target.accessibility_description.is_empty()
	):
		target.accessibility_description = text
		_owns_accessibility_description = true


func _resolve_text() -> String:
	if text_key == &"":
		return fallback_text

	var translated: String = str(
		TranslationServer.translate(text_key)
	)

	return fallback_text if translated == str(text_key) else translated
