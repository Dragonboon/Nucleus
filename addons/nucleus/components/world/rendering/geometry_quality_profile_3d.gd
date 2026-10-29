@tool
class_name NucleusGeometryQualityProfile3D
extends Resource
## Native GeometryInstance3D quality multipliers and optional distance caps.

enum Quality {
	MINIMAL,
	REDUCED,
	FULL,
}

@export_group("LOD bias multiplier")
@export_range(0.01, 4.0, 0.01, "or_greater")
var minimal_lod_bias_scale: float = 0.5:
	set(value):
		minimal_lod_bias_scale = maxf(value, 0.01)
		emit_changed()

@export_range(0.01, 4.0, 0.01, "or_greater")
var reduced_lod_bias_scale: float = 0.75:
	set(value):
		reduced_lod_bias_scale = maxf(value, 0.01)
		emit_changed()

@export_range(0.01, 4.0, 0.01, "or_greater")
var full_lod_bias_scale: float = 1.0:
	set(value):
		full_lod_bias_scale = maxf(value, 0.01)
		emit_changed()

@export_group("Optional visibility end caps")
## Zero preserves the authored range.
@export_range(0.0, 1000000.0, 0.1, "or_greater")
var minimal_visibility_end_cap: float = 0.0:
	set(value):
		minimal_visibility_end_cap = maxf(value, 0.0)
		emit_changed()

@export_range(0.0, 1000000.0, 0.1, "or_greater")
var reduced_visibility_end_cap: float = 0.0:
	set(value):
		reduced_visibility_end_cap = maxf(value, 0.0)
		emit_changed()

@export_group("Shadows")
@export var disable_shadows_in_minimal: bool = true:
	set(value):
		disable_shadows_in_minimal = value
		emit_changed()

@export var disable_shadows_in_reduced: bool = false:
	set(value):
		disable_shadows_in_reduced = value
		emit_changed()


func get_lod_bias_scale(quality: int) -> float:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return minimal_lod_bias_scale
		Quality.REDUCED:
			return reduced_lod_bias_scale
		_:
			return full_lod_bias_scale


func get_visibility_end_cap(quality: int) -> float:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return minimal_visibility_end_cap
		Quality.REDUCED:
			return reduced_visibility_end_cap
		_:
			return 0.0


func should_disable_shadows(quality: int) -> bool:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return disable_shadows_in_minimal
		Quality.REDUCED:
			return disable_shadows_in_reduced
		_:
			return false
