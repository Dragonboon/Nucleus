@tool
class_name NucleusViewportShadowQualityProfile3D
extends Resource
## Native Viewport positional shadow-atlas quality policy.
##
## Full quality always restores the Viewport's authored atlas settings.

enum Quality {
	MINIMAL,
	REDUCED,
	FULL,
}

@export_group("Atlas size")
## Set to 0 to intentionally disable Omni/Spot positional shadows.
@export_range(0, 16384, 1, "or_greater")
var minimal_atlas_size: int = 1024:
	set(value):
		minimal_atlas_size = maxi(value, 0)
		emit_changed()

@export_range(0, 16384, 1, "or_greater")
var reduced_atlas_size: int = 2048:
	set(value):
		reduced_atlas_size = maxi(value, 0)
		emit_changed()

@export_group("Depth precision")
@export var minimal_use_16_bits: bool = true:
	set(value):
		minimal_use_16_bits = value
		emit_changed()

@export var reduced_use_16_bits: bool = true:
	set(value):
		reduced_use_16_bits = value
		emit_changed()

@export_group("Minimal quadrants")
@export_enum("Disabled:0", "1:1", "4:2", "16:3", "64:4", "256:5", "1024:6")
var minimal_quad_0: int = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_16:
	set(value):
		minimal_quad_0 = clampi(value, 0, 6)
		emit_changed()

@export_enum("Disabled:0", "1:1", "4:2", "16:3", "64:4", "256:5", "1024:6")
var minimal_quad_1: int = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_64:
	set(value):
		minimal_quad_1 = clampi(value, 0, 6)
		emit_changed()

@export_enum("Disabled:0", "1:1", "4:2", "16:3", "64:4", "256:5", "1024:6")
var minimal_quad_2: int = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_64:
	set(value):
		minimal_quad_2 = clampi(value, 0, 6)
		emit_changed()

@export_enum("Disabled:0", "1:1", "4:2", "16:3", "64:4", "256:5", "1024:6")
var minimal_quad_3: int = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_256:
	set(value):
		minimal_quad_3 = clampi(value, 0, 6)
		emit_changed()

@export_group("Reduced quadrants")
@export_enum("Disabled:0", "1:1", "4:2", "16:3", "64:4", "256:5", "1024:6")
var reduced_quad_0: int = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4:
	set(value):
		reduced_quad_0 = clampi(value, 0, 6)
		emit_changed()

@export_enum("Disabled:0", "1:1", "4:2", "16:3", "64:4", "256:5", "1024:6")
var reduced_quad_1: int = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4:
	set(value):
		reduced_quad_1 = clampi(value, 0, 6)
		emit_changed()

@export_enum("Disabled:0", "1:1", "4:2", "16:3", "64:4", "256:5", "1024:6")
var reduced_quad_2: int = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_16:
	set(value):
		reduced_quad_2 = clampi(value, 0, 6)
		emit_changed()

@export_enum("Disabled:0", "1:1", "4:2", "16:3", "64:4", "256:5", "1024:6")
var reduced_quad_3: int = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_64:
	set(value):
		reduced_quad_3 = clampi(value, 0, 6)
		emit_changed()


func get_atlas_size(quality: int) -> int:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return minimal_atlas_size
		Quality.REDUCED:
			return reduced_atlas_size
		_:
			return -1


func get_use_16_bits(
	quality: int,
	authored_value: bool,
) -> bool:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return minimal_use_16_bits
		Quality.REDUCED:
			return reduced_use_16_bits
		_:
			return authored_value


func get_quadrant_subdivision(
	quality: int,
	quadrant: int,
	authored_value: int,
) -> int:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return _minimal_quadrant(quadrant)
		Quality.REDUCED:
			return _reduced_quadrant(quadrant)
		_:
			return authored_value


func _minimal_quadrant(quadrant: int) -> int:
	match clampi(quadrant, 0, 3):
		0:
			return minimal_quad_0
		1:
			return minimal_quad_1
		2:
			return minimal_quad_2
		_:
			return minimal_quad_3


func _reduced_quadrant(quadrant: int) -> int:
	match clampi(quadrant, 0, 3):
		0:
			return reduced_quad_0
		1:
			return reduced_quad_1
		2:
			return reduced_quad_2
		_:
			return reduced_quad_3
