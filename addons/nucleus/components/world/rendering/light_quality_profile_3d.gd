@tool
class_name NucleusLightQualityProfile3D
extends Resource
## Native Light3D quality policy.
##
## The profile scales or caps authored presentation state. It never owns light
## color, energy, transform, bake mode, masks, or gameplay semantics.

enum Quality {
	MINIMAL,
	REDUCED,
	FULL,
}

@export_group("Common shadow quality")
@export_range(0.0, 2.0, 0.01, "or_greater")
var minimal_shadow_blur_scale: float = 0.5:
	set(value):
		minimal_shadow_blur_scale = maxf(value, 0.0)
		emit_changed()

@export_range(0.0, 2.0, 0.01, "or_greater")
var reduced_shadow_blur_scale: float = 0.75:
	set(value):
		reduced_shadow_blur_scale = maxf(value, 0.0)
		emit_changed()

@export_range(0.0, 2.0, 0.01, "or_greater")
var minimal_light_size_scale: float = 0.0:
	set(value):
		minimal_light_size_scale = maxf(value, 0.0)
		emit_changed()

@export_range(0.0, 2.0, 0.01, "or_greater")
var reduced_light_size_scale: float = 0.5:
	set(value):
		reduced_light_size_scale = maxf(value, 0.0)
		emit_changed()

@export var disable_shadows_in_minimal: bool = true:
	set(value):
		disable_shadows_in_minimal = value
		emit_changed()

@export var disable_shadows_in_reduced: bool = false:
	set(value):
		disable_shadows_in_reduced = value
		emit_changed()

@export_group("Volumetric fog")
@export_range(0.0, 2.0, 0.01, "or_greater")
var minimal_volumetric_fog_energy_scale: float = 0.0:
	set(value):
		minimal_volumetric_fog_energy_scale = maxf(value, 0.0)
		emit_changed()

@export_range(0.0, 2.0, 0.01, "or_greater")
var reduced_volumetric_fog_energy_scale: float = 0.5:
	set(value):
		reduced_volumetric_fog_energy_scale = maxf(value, 0.0)
		emit_changed()

@export_group("Local light distance fade")
## Distance fade is only scaled when it is already enabled on the authored light.
@export_range(0.01, 1.0, 0.01)
var minimal_distance_fade_begin_scale: float = 0.5:
	set(value):
		minimal_distance_fade_begin_scale = clampf(value, 0.01, 1.0)
		emit_changed()

@export_range(0.01, 1.0, 0.01)
var reduced_distance_fade_begin_scale: float = 0.75:
	set(value):
		reduced_distance_fade_begin_scale = clampf(value, 0.01, 1.0)
		emit_changed()

@export_range(0.01, 1.0, 0.01)
var minimal_distance_fade_length_scale: float = 0.5:
	set(value):
		minimal_distance_fade_length_scale = clampf(value, 0.01, 1.0)
		emit_changed()

@export_range(0.01, 1.0, 0.01)
var reduced_distance_fade_length_scale: float = 0.75:
	set(value):
		reduced_distance_fade_length_scale = clampf(value, 0.01, 1.0)
		emit_changed()

@export_range(0.01, 1.0, 0.01)
var minimal_shadow_distance_scale: float = 0.35:
	set(value):
		minimal_shadow_distance_scale = clampf(value, 0.01, 1.0)
		emit_changed()

@export_range(0.01, 1.0, 0.01)
var reduced_shadow_distance_scale: float = 0.65:
	set(value):
		reduced_shadow_distance_scale = clampf(value, 0.01, 1.0)
		emit_changed()

@export_group("Projectors")
@export var disable_projector_in_minimal: bool = true:
	set(value):
		disable_projector_in_minimal = value
		emit_changed()

@export var disable_projector_in_reduced: bool = false:
	set(value):
		disable_projector_in_reduced = value
		emit_changed()

@export_group("Omni shadows")
@export_enum("Preserve:-1", "Dual Paraboloid:0", "Cube:1")
var minimal_omni_shadow_mode: int = OmniLight3D.SHADOW_DUAL_PARABOLOID:
	set(value):
		minimal_omni_shadow_mode = clampi(value, -1, 1)
		emit_changed()

@export_enum("Preserve:-1", "Dual Paraboloid:0", "Cube:1")
var reduced_omni_shadow_mode: int = OmniLight3D.SHADOW_DUAL_PARABOLOID:
	set(value):
		reduced_omni_shadow_mode = clampi(value, -1, 1)
		emit_changed()

@export_group("Directional shadows")
@export_enum("Preserve:-1", "Orthogonal:0", "2 Splits:1", "4 Splits:2")
var minimal_directional_shadow_mode: int = (
	DirectionalLight3D.SHADOW_ORTHOGONAL
):
	set(value):
		minimal_directional_shadow_mode = clampi(value, -1, 2)
		emit_changed()

@export_enum("Preserve:-1", "Orthogonal:0", "2 Splits:1", "4 Splits:2")
var reduced_directional_shadow_mode: int = (
	DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
):
	set(value):
		reduced_directional_shadow_mode = clampi(value, -1, 2)
		emit_changed()

@export_range(0.01, 1.0, 0.01)
var minimal_directional_shadow_distance_scale: float = 0.35:
	set(value):
		minimal_directional_shadow_distance_scale = clampf(
			value,
			0.01,
			1.0,
		)
		emit_changed()

@export_range(0.01, 1.0, 0.01)
var reduced_directional_shadow_distance_scale: float = 0.65:
	set(value):
		reduced_directional_shadow_distance_scale = clampf(
			value,
			0.01,
			1.0,
		)
		emit_changed()

@export_range(0.0, 1.0, 0.01)
var minimal_directional_angular_distance_scale: float = 0.0:
	set(value):
		minimal_directional_angular_distance_scale = clampf(
			value,
			0.0,
			1.0,
		)
		emit_changed()

@export_range(0.0, 1.0, 0.01)
var reduced_directional_angular_distance_scale: float = 0.5:
	set(value):
		reduced_directional_angular_distance_scale = clampf(
			value,
			0.0,
			1.0,
		)
		emit_changed()

@export var disable_directional_blend_splits_in_minimal: bool = true:
	set(value):
		disable_directional_blend_splits_in_minimal = value
		emit_changed()

@export var disable_directional_blend_splits_in_reduced: bool = false:
	set(value):
		disable_directional_blend_splits_in_reduced = value
		emit_changed()


func get_shadow_blur_scale(quality: int) -> float:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return minimal_shadow_blur_scale
		Quality.REDUCED:
			return reduced_shadow_blur_scale
		_:
			return 1.0


func get_light_size_scale(quality: int) -> float:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return minimal_light_size_scale
		Quality.REDUCED:
			return reduced_light_size_scale
		_:
			return 1.0


func should_disable_shadows(quality: int) -> bool:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return disable_shadows_in_minimal
		Quality.REDUCED:
			return disable_shadows_in_reduced
		_:
			return false


func get_volumetric_fog_energy_scale(quality: int) -> float:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return minimal_volumetric_fog_energy_scale
		Quality.REDUCED:
			return reduced_volumetric_fog_energy_scale
		_:
			return 1.0


func get_distance_fade_begin_scale(quality: int) -> float:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return minimal_distance_fade_begin_scale
		Quality.REDUCED:
			return reduced_distance_fade_begin_scale
		_:
			return 1.0


func get_distance_fade_length_scale(quality: int) -> float:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return minimal_distance_fade_length_scale
		Quality.REDUCED:
			return reduced_distance_fade_length_scale
		_:
			return 1.0


func get_shadow_distance_scale(quality: int) -> float:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return minimal_shadow_distance_scale
		Quality.REDUCED:
			return reduced_shadow_distance_scale
		_:
			return 1.0


func should_disable_projector(quality: int) -> bool:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return disable_projector_in_minimal
		Quality.REDUCED:
			return disable_projector_in_reduced
		_:
			return false


func get_omni_shadow_mode(quality: int) -> int:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return minimal_omni_shadow_mode
		Quality.REDUCED:
			return reduced_omni_shadow_mode
		_:
			return -1


func get_directional_shadow_mode(quality: int) -> int:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return minimal_directional_shadow_mode
		Quality.REDUCED:
			return reduced_directional_shadow_mode
		_:
			return -1


func get_directional_shadow_distance_scale(quality: int) -> float:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return minimal_directional_shadow_distance_scale
		Quality.REDUCED:
			return reduced_directional_shadow_distance_scale
		_:
			return 1.0


func get_directional_angular_distance_scale(quality: int) -> float:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return minimal_directional_angular_distance_scale
		Quality.REDUCED:
			return reduced_directional_angular_distance_scale
		_:
			return 1.0


func should_disable_directional_blend_splits(quality: int) -> bool:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return disable_directional_blend_splits_in_minimal
		Quality.REDUCED:
			return disable_directional_blend_splits_in_reduced
		_:
			return false
