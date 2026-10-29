class_name NucleusFloatingTextPresenter2D
extends Node2D
## Scene-owned world-space Labels with a bounded local budget and native Tweens.

@export var profile: NucleusFloatingTextProfile2D
@export_range(1, 1024) var maximum_visible: int = 96
@export var reduced_motion: bool = false
var _entries: Dictionary[Label, Tween] = {}


func show_number(
	value: float, world_position: Vector2, decimals: int = 0,
	style: NucleusFloatingTextProfile2D = null,
) -> Label:
	if not is_finite(value) or decimals < 0 or decimals > 6:
		return null
	return show_text(String.num(value, decimals), world_position, style)


func show_text(
	text: String, world_position: Vector2, style: NucleusFloatingTextProfile2D = null,
) -> Label:
	var appearance := style if style != null else profile
	if (not is_inside_tree() or is_queued_for_deletion() or text.is_empty()
		or not world_position.is_finite() or maximum_visible < 1
		or appearance == null or not appearance.is_valid()):
		return null
	while _entries.size() >= maximum_visible:
		_retire(_entries.keys()[0])
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", appearance.font_size)
	if appearance.font != null:
		label.add_theme_font_override("font", appearance.font)
	label.add_theme_color_override("font_color", appearance.color)
	label.add_theme_color_override("font_outline_color", appearance.outline_color)
	label.add_theme_constant_override("outline_size", appearance.outline_size)
	add_child(label)
	# Coordinates belong to this canvas, never to a global registry or screen HUD.
	label.set_as_top_level(true)
	label.global_position = world_position + appearance.offset
	var tween := label.create_tween().set_parallel(true)
	var destination := label.position
	if not reduced_motion:
		destination += appearance.travel
	tween.tween_property(label, "position", destination, appearance.duration)
	var delay := appearance.duration * appearance.fade_start
	tween.tween_property(label, "modulate:a", 0.0, appearance.duration - delay).set_delay(delay)
	tween.chain().tween_callback(_retire.bind(label))
	_entries[label] = tween
	label.tree_exiting.connect(_forget.bind(label))
	return label


func get_visible_count() -> int:
	return _entries.size()


func clear() -> void:
	for label: Label in _entries.keys():
		_retire(label)


func _exit_tree() -> void:
	clear()


func _retire(label: Label) -> void:
	_forget(label)
	if is_instance_valid(label):
		label.hide()
		label.queue_free()


func _forget(label: Label) -> void:
	var tween: Tween = _entries.get(label)
	_entries.erase(label)
	if tween != null and tween.is_valid():
		tween.kill()
