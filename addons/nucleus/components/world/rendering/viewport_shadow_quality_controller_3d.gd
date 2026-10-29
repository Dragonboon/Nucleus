@tool
class_name NucleusViewportShadowQualityController3D
extends Node
## Applies a native positional shadow-atlas tier to one Viewport.
##
## If target_viewport is unassigned, the controller uses its owning Viewport.
## Only one runtime writer should own shadow-atlas quality for a given Viewport.

signal quality_changed(quality: int)

@export var target_viewport: Viewport:
	set(value):
		if not Engine.is_editor_hint():
			_restore_authored_state()

		target_viewport = value
		_baseline_captured = false
		update_configuration_warnings()
		_apply_quality()

@export var profile: NucleusViewportShadowQualityProfile3D:
	set(value):
		_disconnect_profile()
		profile = value
		_connect_profile()
		update_configuration_warnings()
		_apply_quality()

@export_enum("Minimal", "Reduced", "Full")
var quality: int = NucleusViewportShadowQualityProfile3D.Quality.FULL:
	set(value):
		var resolved: int = clampi(
			value,
			NucleusViewportShadowQualityProfile3D.Quality.MINIMAL,
			NucleusViewportShadowQualityProfile3D.Quality.FULL,
		)

		if quality == resolved:
			return

		quality = resolved
		_apply_quality()

		if is_node_ready() and not Engine.is_editor_hint():
			quality_changed.emit(quality)

var _resolved_viewport: Viewport
var _authored_atlas_size: int = 2048
var _authored_use_16_bits: bool = true
var _authored_quadrants: Array[int] = [0, 0, 0, 0]
var _baseline_captured: bool = false
var _connected_profile: NucleusViewportShadowQualityProfile3D


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_resolve_viewport()
	_capture_authored_state()
	_connect_profile()
	_apply_quality()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	_disconnect_profile()
	_restore_authored_state()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()

	if profile == null:
		warnings.append(
			"Assign a NucleusViewportShadowQualityProfile3D."
		)

	return warnings


func set_quality(value: int) -> void:
	quality = value


func apply_now() -> Error:
	_resolve_viewport()

	if _resolved_viewport == null or profile == null:
		return ERR_UNCONFIGURED

	_apply_quality()
	return OK


func get_target_viewport() -> Viewport:
	_resolve_viewport()
	return _resolved_viewport


func _apply_quality() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return

	_resolve_viewport()

	if _resolved_viewport == null or profile == null:
		return

	_capture_authored_state()

	var atlas_size: int = profile.get_atlas_size(quality)

	_resolved_viewport.positional_shadow_atlas_size = (
		_authored_atlas_size
		if atlas_size < 0
		else atlas_size
	)
	_resolved_viewport.positional_shadow_atlas_16_bits = (
		profile.get_use_16_bits(
			quality,
			_authored_use_16_bits,
		)
	)

	for quadrant: int in range(4):
		var subdivision: int = profile.get_quadrant_subdivision(
			quality,
			quadrant,
			_authored_quadrants[quadrant],
		)
		_resolved_viewport.set_positional_shadow_atlas_quadrant_subdiv(
			quadrant,
			subdivision,
		)


func _resolve_viewport() -> void:
	var next_viewport: Viewport = target_viewport

	if next_viewport == null and is_inside_tree():
		next_viewport = get_viewport()

	if _resolved_viewport == next_viewport:
		return

	if not Engine.is_editor_hint():
		_restore_authored_state()

	_resolved_viewport = next_viewport
	_baseline_captured = false


func _capture_authored_state() -> void:
	if _resolved_viewport == null or _baseline_captured:
		return

	_authored_atlas_size = (
		_resolved_viewport.positional_shadow_atlas_size
	)
	_authored_use_16_bits = (
		_resolved_viewport.positional_shadow_atlas_16_bits
	)

	for quadrant: int in range(4):
		_authored_quadrants[quadrant] = (
			_resolved_viewport
			.get_positional_shadow_atlas_quadrant_subdiv(
				quadrant
			)
		)

	_baseline_captured = true


func _restore_authored_state() -> void:
	if _resolved_viewport == null or not _baseline_captured:
		return

	_resolved_viewport.positional_shadow_atlas_size = (
		_authored_atlas_size
	)
	_resolved_viewport.positional_shadow_atlas_16_bits = (
		_authored_use_16_bits
	)

	for quadrant: int in range(4):
		_resolved_viewport.set_positional_shadow_atlas_quadrant_subdiv(
			quadrant,
			_authored_quadrants[quadrant],
		)

	_baseline_captured = false


func _connect_profile() -> void:
	if profile == null or _connected_profile == profile:
		return

	_connected_profile = profile

	if not profile.changed.is_connected(_on_profile_changed):
		profile.changed.connect(_on_profile_changed)


func _disconnect_profile() -> void:
	if _connected_profile == null:
		return

	if _connected_profile.changed.is_connected(_on_profile_changed):
		_connected_profile.changed.disconnect(_on_profile_changed)

	_connected_profile = null


func _on_profile_changed() -> void:
	_apply_quality()
