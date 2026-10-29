@tool
class_name NucleusLocalFxVolume3D
extends Node3D
## Scene-owned localized world FX state and follow policy.
##
## The volume owns transform, smoothed intensity, and quality selection. It does
## not own particle materials, weather rules, raycasts, audio, or surface hits.

signal follow_target_changed(
	target: Node3D,
	previous_target: Node3D,
)
signal recentered(world_position: Vector3)
signal intensity_target_changed(target_intensity: float)
signal intensity_changed(current_intensity: float)
signal quality_changed(quality: int)
signal enabled_changed(enabled: bool)

const FOLLOW_X: int = 1
const FOLLOW_Y: int = 2
const FOLLOW_Z: int = 4

@export_group("Following")
@export var follow_target: Node3D
@export_flags("X:1", "Y:2", "Z:4")
var follow_axes: int = FOLLOW_X | FOLLOW_Z
@export var follow_offset: Vector3 = Vector3.ZERO

@export_group("Intensity")
@export_range(0.0, 1.0, 0.01)
var intensity: float = 0.0:
	set(value):
		var resolved := clampf(value, 0.0, 1.0)

		if is_equal_approx(intensity, resolved):
			return

		intensity = resolved

		if is_node_ready():
			intensity_target_changed.emit(intensity)

@export_range(0.0, 100.0, 0.01, "or_greater")
var transition_speed: float = 1.0
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return

		enabled = value

		if is_node_ready():
			enabled_changed.emit(enabled)
			_emit_intensity_if_changed()

@export_group("Quality")
@export var quality_profile: NucleusFxQualityProfile:
	set(value):
		if quality_profile == value:
			return

		_disconnect_quality_profile()
		quality_profile = value
		_connect_quality_profile()
		update_configuration_warnings()

		if is_node_ready():
			quality_changed.emit(quality)

@export_enum("Low", "Medium", "High")
var quality: int = NucleusFxQualityProfile.Quality.MEDIUM:
	set(value):
		var resolved := clampi(
			value,
			NucleusFxQualityProfile.Quality.LOW,
			NucleusFxQualityProfile.Quality.HIGH,
		)

		if quality == resolved:
			return

		quality = resolved

		if is_node_ready():
			quality_changed.emit(quality)

var _current_intensity: float = 0.0
var _last_emitted_intensity: float = -1.0
var _connected_quality_profile: NucleusFxQualityProfile


func _ready() -> void:
	_connect_quality_profile()

	if Engine.is_editor_hint():
		return

	_current_intensity = clampf(intensity, 0.0, 1.0)
	recenter_now()
	_emit_intensity_if_changed()
	quality_changed.emit(quality)


func _exit_tree() -> void:
	_disconnect_quality_profile()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	recenter_now()
	_advance_intensity(delta)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if follow_axes != 0 and follow_target == null:
		warnings.append(
			"Assign follow_target or set follow_axes to zero for a static FX volume."
		)

	if quality_profile != null:
		for error: String in quality_profile.get_validation_errors():
			warnings.append("Quality profile: %s" % error)

	return warnings


func set_follow_target(
	target: Node3D,
	snap: bool = true,
) -> void:
	if follow_target == target:
		return

	var previous := follow_target
	follow_target = target
	update_configuration_warnings()

	if snap and not Engine.is_editor_hint():
		recenter_now()

	follow_target_changed.emit(
		follow_target,
		previous,
	)


func set_intensity(
	value: float,
	instant: bool = false,
) -> void:
	intensity = value

	if instant or transition_speed <= 0.0:
		_current_intensity = intensity
		_emit_intensity_if_changed()


func set_enabled(active: bool) -> void:
	enabled = active


func set_quality(value: int) -> void:
	quality = value


func set_quality_profile(
	profile: NucleusFxQualityProfile,
) -> void:
	quality_profile = profile


func get_current_intensity() -> float:
	return _current_intensity if enabled else 0.0


func get_target_intensity() -> float:
	return clampf(intensity, 0.0, 1.0)


func get_particle_capacity_scale() -> float:
	if quality_profile == null:
		return 1.0

	return quality_profile.get_particle_capacity_scale(quality)


func get_event_rate_scale() -> float:
	if quality_profile == null:
		return 1.0

	return quality_profile.get_event_rate_scale(quality)


func recenter_now() -> bool:
	if (
		follow_axes == 0
		or follow_target == null
		or not is_instance_valid(follow_target)
	):
		return false

	var next_position := global_position
	var target_position := follow_target.global_position + follow_offset

	if (follow_axes & FOLLOW_X) != 0:
		next_position.x = target_position.x

	if (follow_axes & FOLLOW_Y) != 0:
		next_position.y = target_position.y

	if (follow_axes & FOLLOW_Z) != 0:
		next_position.z = target_position.z

	if next_position.is_equal_approx(global_position):
		return false

	global_position = next_position
	recentered.emit(global_position)
	return true


func _advance_intensity(delta: float) -> void:
	var target_value := clampf(intensity, 0.0, 1.0)

	if is_equal_approx(_current_intensity, target_value):
		return

	if transition_speed <= 0.0:
		_current_intensity = target_value
	else:
		_current_intensity = move_toward(
			_current_intensity,
			target_value,
			transition_speed * maxf(delta, 0.0),
		)

	_emit_intensity_if_changed()


func _emit_intensity_if_changed() -> void:
	var effective := get_current_intensity()

	if is_equal_approx(
		effective,
		_last_emitted_intensity,
	):
		return

	_last_emitted_intensity = effective
	intensity_changed.emit(effective)


func _connect_quality_profile() -> void:
	if quality_profile == null:
		return

	if _connected_quality_profile == quality_profile:
		return

	_connected_quality_profile = quality_profile

	if not quality_profile.changed.is_connected(_on_quality_profile_changed):
		quality_profile.changed.connect(_on_quality_profile_changed)


func _disconnect_quality_profile() -> void:
	if _connected_quality_profile == null:
		return

	if _connected_quality_profile.changed.is_connected(_on_quality_profile_changed):
		_connected_quality_profile.changed.disconnect(_on_quality_profile_changed)

	_connected_quality_profile = null


func _on_quality_profile_changed() -> void:
	update_configuration_warnings()
	quality_changed.emit(quality)
