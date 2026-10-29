@tool
class_name NucleusMaterialQualityProfile3D
extends Resource
## Material override choices for reusable 3D presentation quality tiers.
##
## A null material means "preserve the target's authored material_override".

enum Quality {
	MINIMAL,
	REDUCED,
	FULL,
}

@export_group("Material overrides")
@export var minimal_material_override: Material:
	set(value):
		minimal_material_override = value
		emit_changed()

@export var reduced_material_override: Material:
	set(value):
		reduced_material_override = value
		emit_changed()

@export var full_material_override: Material:
	set(value):
		full_material_override = value
		emit_changed()


func get_material_override(quality: int) -> Material:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return minimal_material_override
		Quality.REDUCED:
			return reduced_material_override
		_:
			return full_material_override
