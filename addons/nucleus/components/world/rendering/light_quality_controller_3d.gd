@tool
class_name NucleusLightQualityController3D
extends Node
## Applies native Godot Light3D quality controls while preserving authored state.
##
## By default this controller does not own shadow_enabled. This avoids competing
## with dynamic owners such as NucleusDaylightDriver3D. Opt into shadow-enabled
## ownership only when this controller is the sole runtime writer for that light.

signal quality_changed(quality: int)

@export var target: Light3D:
	set(value):
		if not Engine.is_editor_hint():
			_restore_authored_state()

		target = value
		_baseline_captured = false
		update_configuration_warnings()
		_apply_quality()

@export var profile: NucleusLightQualityProfile3D:
	set(value):
		_disconnect_profile()
		profile = value
		_connect_profile()
		update_configuration_warnings()
		_apply_quality()

@export_enum("Minimal", "Reduced", "Full")
var quality: int = NucleusLightQualityProfile3D.Quality.FULL:
	set(value):
		var resolved: int = clampi(
			value,
			NucleusLightQualityProfile3D.Quality.MINIMAL,
			NucleusLightQualityProfile3D.Quality.FULL,
		)

		if quality == resolved:
			return

		quality = resolved
		_apply_quality()

		if is_node_ready() and not Engine.is_editor_hint():
			quality_changed.emit(quality)

@export_group("Ownership")
@export var manage_shadow_enabled: bool = false:
	set(value):
		if manage_shadow_enabled == value:
			return

		if (
			not value
			and target != null
			and _baseline_captured
		):
			target.shadow_enabled = _authored_shadow_enabled

		manage_shadow_enabled = value
		_apply_quality()
		update_configuration_warnings()

@export var manage_distance_fade: bool = true:
	set(value):
		manage_distance_fade = value
		_apply_quality()

@export var manage_projector: bool = true:
	set(value):
		manage_projector = value
		_apply_quality()

@export var manage_volumetric_fog_energy: bool = true:
	set(value):
		manage_volumetric_fog_energy = value
		_apply_quality()

var _authored_shadow_enabled: bool = false
var _authored_shadow_blur: float = 1.0
var _authored_light_size: float = 0.0
var _authored_light_angular_distance: float = 0.0
var _authored_volumetric_fog_energy: float = 1.0
var _authored_projector: Texture2D

var _authored_distance_fade_enabled: bool = false
var _authored_distance_fade_begin: float = 40.0
var _authored_distance_fade_length: float = 10.0
var _authored_distance_fade_shadow: float = 50.0

var _authored_omni_shadow_mode: int = OmniLight3D.SHADOW_CUBE

var _authored_directional_shadow_mode: int = (
	DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
)
var _authored_directional_shadow_max_distance: float = 100.0
var _authored_directional_shadow_blend_splits: bool = false

var _baseline_captured: bool = false
var _connected_profile: NucleusLightQualityProfile3D


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if target == null:
		target = get_parent() as Light3D

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
	var parent_light: Light3D = get_parent() as Light3D

	if target == null and parent_light == null:
		warnings.append(
			"Assign a Light3D target or parent this controller under a Light3D."
		)

	if profile == null:
		warnings.append("Assign a NucleusLightQualityProfile3D.")

	if manage_shadow_enabled and target is DirectionalLight3D:
		warnings.append(
			"manage_shadow_enabled must have one runtime owner. Disable it when "
			+ "NucleusDaylightDriver3D or game code also controls this light."
		)

	return warnings


func set_quality(value: int) -> void:
	quality = value


func apply_now() -> Error:
	if target == null or profile == null:
		return ERR_UNCONFIGURED

	_apply_quality()
	return OK


func _apply_quality() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return

	if target == null or profile == null:
		return

	_capture_authored_state()
	_apply_common_quality()
	_apply_local_light_quality()
	_apply_omni_quality()
	_apply_directional_quality()


func _apply_common_quality() -> void:
	target.shadow_blur = (
		_authored_shadow_blur
		* profile.get_shadow_blur_scale(quality)
	)
	target.light_size = (
		_authored_light_size
		* profile.get_light_size_scale(quality)
	)

	if manage_volumetric_fog_energy:
		target.light_volumetric_fog_energy = (
			_authored_volumetric_fog_energy
			* profile.get_volumetric_fog_energy_scale(quality)
		)
	else:
		target.light_volumetric_fog_energy = (
			_authored_volumetric_fog_energy
		)

	if manage_shadow_enabled:
		target.shadow_enabled = (
			false
			if profile.should_disable_shadows(quality)
			else _authored_shadow_enabled
		)


func _apply_local_light_quality() -> void:
	if not target is OmniLight3D and not target is SpotLight3D:
		return

	if manage_distance_fade:
		target.distance_fade_enabled = _authored_distance_fade_enabled

		if _authored_distance_fade_enabled:
			target.distance_fade_begin = (
				_authored_distance_fade_begin
				* profile.get_distance_fade_begin_scale(quality)
			)
			target.distance_fade_length = (
				_authored_distance_fade_length
				* profile.get_distance_fade_length_scale(quality)
			)
			target.distance_fade_shadow = (
				_authored_distance_fade_shadow
				* profile.get_shadow_distance_scale(quality)
			)
	else:
		_restore_authored_distance_fade()

	if manage_projector:
		target.light_projector = (
			null
			if profile.should_disable_projector(quality)
			else _authored_projector
		)
	else:
		target.light_projector = _authored_projector


func _apply_omni_quality() -> void:
	if not target is OmniLight3D:
		return

	var omni_light: OmniLight3D = target as OmniLight3D
	var shadow_mode: int = profile.get_omni_shadow_mode(quality)

	omni_light.omni_shadow_mode = (
		_authored_omni_shadow_mode
		if shadow_mode < 0
		else shadow_mode
	)


func _apply_directional_quality() -> void:
	if not target is DirectionalLight3D:
		return

	var directional_light: DirectionalLight3D = (
		target as DirectionalLight3D
	)
	var shadow_mode: int = profile.get_directional_shadow_mode(
		quality
	)

	directional_light.directional_shadow_mode = (
		_authored_directional_shadow_mode
		if shadow_mode < 0
		else shadow_mode
	)
	directional_light.directional_shadow_max_distance = (
		_authored_directional_shadow_max_distance
		* profile.get_directional_shadow_distance_scale(quality)
	)
	directional_light.light_angular_distance = (
		_authored_light_angular_distance
		* profile.get_directional_angular_distance_scale(quality)
	)
	directional_light.directional_shadow_blend_splits = (
		false
		if profile.should_disable_directional_blend_splits(quality)
		else _authored_directional_shadow_blend_splits
	)


func _capture_authored_state() -> void:
	if target == null or _baseline_captured:
		return

	_authored_shadow_enabled = target.shadow_enabled
	_authored_shadow_blur = target.shadow_blur
	_authored_light_size = target.light_size
	_authored_light_angular_distance = target.light_angular_distance
	_authored_volumetric_fog_energy = (
		target.light_volumetric_fog_energy
	)
	_authored_projector = target.light_projector

	_authored_distance_fade_enabled = target.distance_fade_enabled
	_authored_distance_fade_begin = target.distance_fade_begin
	_authored_distance_fade_length = target.distance_fade_length
	_authored_distance_fade_shadow = target.distance_fade_shadow

	if target is OmniLight3D:
		var omni_light: OmniLight3D = target as OmniLight3D
		_authored_omni_shadow_mode = omni_light.omni_shadow_mode

	if target is DirectionalLight3D:
		var directional_light: DirectionalLight3D = (
			target as DirectionalLight3D
		)
		_authored_directional_shadow_mode = (
			directional_light.directional_shadow_mode
		)
		_authored_directional_shadow_max_distance = (
			directional_light.directional_shadow_max_distance
		)
		_authored_directional_shadow_blend_splits = (
			directional_light.directional_shadow_blend_splits
		)

	_baseline_captured = true


func _restore_authored_state() -> void:
	if target == null or not _baseline_captured:
		return

	target.shadow_blur = _authored_shadow_blur
	target.light_size = _authored_light_size
	target.light_angular_distance = _authored_light_angular_distance
	target.light_volumetric_fog_energy = (
		_authored_volumetric_fog_energy
	)
	target.light_projector = _authored_projector
	_restore_authored_distance_fade()

	if manage_shadow_enabled:
		target.shadow_enabled = _authored_shadow_enabled

	if target is OmniLight3D:
		var omni_light: OmniLight3D = target as OmniLight3D
		omni_light.omni_shadow_mode = _authored_omni_shadow_mode

	if target is DirectionalLight3D:
		var directional_light: DirectionalLight3D = (
			target as DirectionalLight3D
		)
		directional_light.directional_shadow_mode = (
			_authored_directional_shadow_mode
		)
		directional_light.directional_shadow_max_distance = (
			_authored_directional_shadow_max_distance
		)
		directional_light.directional_shadow_blend_splits = (
			_authored_directional_shadow_blend_splits
		)

	_baseline_captured = false


func _restore_authored_distance_fade() -> void:
	target.distance_fade_enabled = _authored_distance_fade_enabled
	target.distance_fade_begin = _authored_distance_fade_begin
	target.distance_fade_length = _authored_distance_fade_length
	target.distance_fade_shadow = _authored_distance_fade_shadow


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
