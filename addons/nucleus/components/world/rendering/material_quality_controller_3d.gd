@tool
class_name NucleusMaterialQualityController3D
extends Node
## Applies an optional material override quality tier to one GeometryInstance3D.
##
## Null tier materials restore the authored material_override instead of
## introducing a synthetic fallback.

signal quality_changed(quality: int)

@export var target: GeometryInstance3D:
	set(value):
		if not Engine.is_editor_hint():
			_restore_authored_state()
		target = value
		_baseline_captured = false
		_apply_quality()
		update_configuration_warnings()

@export var profile: NucleusMaterialQualityProfile3D:
	set(value):
		_disconnect_profile()
		profile = value
		_connect_profile()
		_apply_quality()
		update_configuration_warnings()

@export_enum("Minimal", "Reduced", "Full")
var quality: int = NucleusMaterialQualityProfile3D.Quality.FULL:
	set(value):
		var resolved := clampi(
			value,
			NucleusMaterialQualityProfile3D.Quality.MINIMAL,
			NucleusMaterialQualityProfile3D.Quality.FULL,
		)

		if quality == resolved:
			return

		quality = resolved
		_apply_quality()

		if is_node_ready() and not Engine.is_editor_hint():
			quality_changed.emit(quality)

var _authored_material_override: Material
var _baseline_captured: bool = false
var _connected_profile: NucleusMaterialQualityProfile3D


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
		warnings.append("Assign a NucleusMaterialQualityProfile3D.")

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

	var override := profile.get_material_override(quality)
	target.material_override = (
		override
		if override != null
		else _authored_material_override
	)


func _capture_authored_state() -> void:
	if target == null or _baseline_captured:
		return

	_authored_material_override = target.material_override
	_baseline_captured = true


func _restore_authored_state() -> void:
	if target == null or not _baseline_captured:
		return

	target.material_override = _authored_material_override
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
