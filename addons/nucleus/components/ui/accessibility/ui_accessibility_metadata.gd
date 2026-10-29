class_name NucleusUIAccessibilityMetadata
extends Node
## Keeps one Control's screen-reader metadata synchronized with translations.
##
## Godot owns the accessibility tree. This component only supplies translated
## human-readable metadata to the native Control accessibility properties.

@export var target: Control

@export_group("Accessible name")
@export var name_key: StringName
@export var fallback_name: String = ""

@export_group("Accessible description")
@export var description_key: StringName
@export_multiline var fallback_description: String = ""

@export_group("Live region")
@export_enum("Off", "Polite", "Assertive")
var live_mode: int = 0


func _ready() -> void:
	if not _resolve_target():
		return

	_apply_metadata()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and target:
		_apply_metadata()


func refresh() -> void:
	if target:
		_apply_metadata()


func _resolve_target() -> bool:
	if target == null:
		target = get_parent() as Control

	if target:
		return true

	NucleusLog.error(
		"%s requires a Control target or parent." % get_path(),
		&"UIAccessibility",
	)

	return false


func _apply_metadata() -> void:
	target.accessibility_name = _translated_or_fallback(
		name_key,
		fallback_name,
	)
	target.accessibility_description = _translated_or_fallback(
		description_key,
		fallback_description,
	)
	target.accessibility_live = (
		live_mode as AccessibilityServer.AccessibilityLiveMode
	)


func _translated_or_fallback(
	key: StringName,
	fallback: String,
) -> String:
	if key == &"":
		return fallback

	var translated: String = str(
		TranslationServer.translate(key)
	)

	if translated == str(key) and not fallback.is_empty():
		return fallback

	return translated
