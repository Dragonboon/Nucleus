@tool
class_name NucleusPlacementProfile3D
extends Resource
## Authored, mechanics-neutral placement constraints for one scene instance.
## A profile describes spatial admission, not build costs or player permissions.

@export_group("Identity / support")
@export var kind: StringName = &"object"
## Existing placeable kinds this kind may rest on; empty means ground only.
@export var supported_by_kinds: Array[StringName] = []
## Incoming kinds that may use this placeable as a supporting surface.
@export var accepts_on_top_kinds: Array[StringName] = []
@export var allow_unowned_ground: bool = true
## Off by default: dynamic bodies are not considered stable ground.
@export var allow_nonstatic_support: bool = false
## Optional semantic tags; requires a NucleusSurfaceSource3D on the collider.
@export var required_surface_tags: Array[StringName] = []

@export_group("Support")
@export_flags_3d_physics var support_mask: int = 1
@export_range(0.0, 89.9, 0.1) var max_slope_degrees: float = 35.0
@export var align_to_surface: bool = false
@export var surface_offset: float = 0.01
## Corner sampling half-widths in local X/Z. Zero tests only the pivot.
@export var support_half_extents: Vector2 = Vector2(0.35, 0.35)
@export_range(0.0, 10.0, 0.01, "or_greater") var max_height_spread: float = 0.25
@export_range(0.1, 100.0, 0.1, "or_greater") var support_cast_above: float = 2.0
@export_range(0.1, 100.0, 0.1, "or_greater") var support_cast_below: float = 3.0

@export_group("Occupancy")
## Required collision envelope, positioned relative to the target's origin.
@export var clearance_shape: Shape3D
@export var clearance_offset: Vector3 = Vector3(0.0, 0.5, 0.0)
@export_flags_3d_physics var obstacle_mask: int = 1
@export var check_areas: bool = false
@export_range(0.0, 0.25, 0.001) var collision_margin: float = 0.0

@export_group("Position / rotation")
@export var snap_to_grid: bool = false
@export var grid_step: Vector2 = Vector2.ONE
@export var grid_origin: Vector2 = Vector2.ZERO
@export var can_move: bool = true
@export var can_rotate: bool = true
@export var can_remove: bool = true
@export_range(0.0, 180.0, 1.0) var rotation_increment_degrees: float = 15.0

@export_group("Linear chains")
@export var allow_chains: bool = false
## Local -Z points along the chain tangent (e.g. a fence segment).
@export_range(0.01, 100.0, 0.01, "or_greater") var chain_spacing: float = 2.0
@export_range(1, 256, 1) var chain_max_count: int = 32
## Control-point limit for curved chains (at least start + end).
@export_range(2, 32, 1) var chain_max_control_points: int = 12
@export_range(2, 32, 1) var chain_curve_subdivisions: int = 12


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if kind == &"":
		errors.append("kind must be nonempty.")
	for number: float in [
		surface_offset, max_slope_degrees, max_height_spread,
		support_cast_above, support_cast_below, collision_margin,
		support_half_extents.x, support_half_extents.y,
		clearance_offset.x, clearance_offset.y, clearance_offset.z,
		grid_step.x, grid_step.y, grid_origin.x, grid_origin.y,
		chain_spacing, rotation_increment_degrees,
	]:
		if not is_finite(number):
			errors.append("Placement numeric settings must be finite.")
			break
	if clearance_shape == null:
		errors.append("A clearance_shape is required to check occupancy.")
	if support_mask == 0:
		errors.append("support_mask cannot be zero.")
	if obstacle_mask == 0:
		errors.append("obstacle_mask cannot be zero (placement must fail closed).")
	if support_half_extents.x < 0.0 or support_half_extents.y < 0.0:
		errors.append("support_half_extents must be nonnegative.")
	if snap_to_grid and (grid_step.x <= 0.0 or grid_step.y <= 0.0):
		errors.append("Both grid steps must be positive when snapping.")
	if chain_spacing <= 0.0 or chain_max_count < 1:
		errors.append("Chain spacing and count must be positive.")
	if chain_max_control_points < 2 or chain_max_control_points > 32:
		errors.append("Curve control-point limit must be in 2..32.")
	if chain_curve_subdivisions < 2 or chain_curve_subdivisions > 32:
		errors.append("Curve subdivisions must be in 2..32.")
	if allow_chains and chain_spacing < 2.0 * support_half_extents.y:
		errors.append("Chain spacing is shorter than the authored forward footprint.")
	if support_cast_above <= 0.0 or support_cast_below <= 0.0:
		errors.append("Support cast reach must be positive.")
	return errors
