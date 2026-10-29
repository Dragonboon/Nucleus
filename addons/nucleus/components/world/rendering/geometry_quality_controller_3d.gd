@tool
class_name NucleusGeometryQualityController3D
extends Node
## Applies native GeometryInstance3D LOD, visibility, and shadow quality policy.

signal quality_changed(quality: int)

@export var target: GeometryInstance3D:
	set(value):
		if not Engine.is_editor_hint():
			_restore_authored_state()
		target = value
		_baseline_captured = false
		_apply_quality()
		update_configuration_warnings()

@export var profile: NucleusGeometryQualityProfile3D:
	set(value):
		_disconnect_profile()
		profile = value
		_connect_profile()
		_apply_quality()
		update_configuration_warnings()

@export_enum("Minimal", "Reduced", "Full")
var quality: int = NucleusGeometryQualityProfile3D.Quality.FULL:
	set(value):
		var resolved := clampi(
			value,
			NucleusGeometryQualityProfile3D.Quality.MINIMAL,
			NucleusGeometryQualityProfile3D.Quality.FULL,
		)

		if quality == resolved:
			return

		quality = resolved
		_apply_quality()

		if is_node_ready() and not Engine.is_editor_hint():
			quality_changed.emit(quality)

var _authored_lod_bias: float = 1.0
var _authored_visibility_end: float = 0.0
var _authored_cast_shadow: int = (
	GeometryInstance3D.SHADOW_CASTING_SETTING_ON
)
var _baseline_captured: bool = false
var _connected_profile: NucleusGeometryQualityProfile3D


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_capture_authored_state()
	_connect_profile()
	_apply_quality()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	_disconnect_profile()
	_restore_authored_state()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if target == null:
		warnings.append("Assign a GeometryInstance3D target.")

	if profile == null:
		warnings.append("Assign a NucleusGeometryQualityProfile3D.")

	return warnings


func set_quality(value: int) -> void:
	quality = value


func apply_now() -> void:
	_apply_quality()


func _apply_quality() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return

	if target == null or profile == null:
		return

	_capture_authored_state()

	target.lod_bias = (
		_authored_lod_bias
		* profile.get_lod_bias_scale(quality)
	)

	var visibility_cap := profile.get_visibility_end_cap(quality)

	if visibility_cap > 0.0:
		target.visibility_range_end = (
			minf(_authored_visibility_end, visibility_cap)
			if _authored_visibility_end > 0.0
			else visibility_cap
		)
	else:
		target.visibility_range_end = _authored_visibility_end

	target.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if profile.should_disable_shadows(quality)
		else _authored_cast_shadow
	)


func _capture_authored_state() -> void:
	if target == null or _baseline_captured:
		return

	_authored_lod_bias = target.lod_bias
	_authored_visibility_end = target.visibility_range_end
	_authored_cast_shadow = target.cast_shadow
	_baseline_captured = true


func _restore_authored_state() -> void:
	if target == null or not _baseline_captured:
		return

	target.lod_bias = _authored_lod_bias
	target.visibility_range_end = _authored_visibility_end
	target.cast_shadow = _authored_cast_shadow
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
