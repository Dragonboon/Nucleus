@tool
class_name NucleusBuoyancy3D
extends Node
## Scene-owned multi-point buoyancy for a native RigidBody3D.
##
## The component samples a NucleusSurfaceSampler3D and applies bounded forces to
## the body every physics tick. Surface shape/velocity and buoyancy tuning remain
## separate contracts.

const BuoyancyMath := preload(
	"res://addons/nucleus/components/world/buoyancy/buoyancy_math.gd"
)

@export_group("Dependencies")
@export var body: RigidBody3D
@export var surface_sampler: NucleusSurfaceSampler3D
@export var enabled: bool = true
@export var require_multiplayer_authority: bool = true

@export_group("Displacement")
@export_range(0.001, 100000.0, 0.001, "or_greater")
var displacement_volume: float = 1.0
@export_range(0.01, 1000.0, 0.01, "or_greater")
var column_height: float = 0.8
@export var sample_points: PackedVector3Array = PackedVector3Array([
	Vector3(-0.5, 0.0, -0.5),
	Vector3(0.5, 0.0, -0.5),
	Vector3(-0.5, 0.0, 0.5),
	Vector3(0.5, 0.0, 0.5),
])

@export_group("Medium")
@export_range(0.001, 100000.0, 0.001, "or_greater")
var fluid_density: float = 1000.0

@export_group("Response")
@export_range(0.0, 4.0, 0.01, "or_greater")
var buoyancy_damping_ratio: float = 0.9
@export_range(0.0, 100.0, 0.1, "or_greater")
var maximum_lift_acceleration: float = 4.0
@export_range(0.0, 100.0, 0.01, "or_greater")
var linear_drag: float = 2.0
@export_range(0.0, 100.0, 0.01, "or_greater")
var angular_drag: float = 1.5

var _surface_sample := NucleusSurfaceSample3D.new()
var _wet_fraction: float = 0.0
var _sampled_point_count: int = 0


func _ready() -> void:
	_resolve_body()
	update_configuration_warnings()
	set_physics_process(not Engine.is_editor_hint())


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var resolved_body := body

	if resolved_body == null or not is_instance_valid(resolved_body):
		resolved_body = _find_body_ancestor()

	if resolved_body == null:
		warnings.append(
			"Assign body or place NucleusBuoyancy3D below a RigidBody3D."
		)
	elif resolved_body.custom_integrator:
		warnings.append(
			"custom_integrator disables the standard force integration used by buoyancy."
		)

	if resolved_body != null and resolved_body.is_inside_tree():
		var body_scale := resolved_body.global_transform.basis.get_scale()
		if not body_scale.is_equal_approx(Vector3.ONE):
			warnings.append(
				"Buoyancy assumes unit body scale; author collider, volume, and points in metres."
			)

	if surface_sampler == null:
		warnings.append("Assign a NucleusSurfaceSampler3D.")

	if sample_points.is_empty():
		warnings.append("Add at least one local buoyancy sample point.")

	if displacement_volume <= 0.0:
		warnings.append("displacement_volume must be greater than zero.")

	if column_height <= 0.0:
		warnings.append("column_height must be greater than zero.")

	if fluid_density <= 0.0:
		warnings.append("fluid_density must be greater than zero.")

	return warnings


func _physics_process(delta: float) -> void:
	_simulate(maxf(delta, 0.0))


func get_wet_fraction() -> float:
	return _wet_fraction


func get_sampled_point_count() -> int:
	return _sampled_point_count


func get_displacement_capacity_kg() -> float:
	return maxf(fluid_density, 0.0) * maxf(displacement_volume, 0.0)


func _simulate(delta: float) -> void:
	var resolved_body := _resolve_body()

	if (
		not enabled
		or resolved_body == null
		or surface_sampler == null
		or sample_points.is_empty()
		or displacement_volume <= 0.0
		or column_height <= 0.0
		or fluid_density <= 0.0
		or not _has_simulation_authority(resolved_body)
	):
		_reset_diagnostics()
		return

	var gravity_magnitude := resolved_body.get_gravity().length()
	if gravity_magnitude <= 0.000001:
		_reset_diagnostics()
		return

	var point_count := sample_points.size()
	var volume_per_point := displacement_volume / float(point_count)
	var point_mass := resolved_body.mass / float(point_count)
	var damping := BuoyancyMath.damping_coefficient(
		fluid_density,
		gravity_magnitude,
		volume_per_point,
		column_height,
		point_mass,
		buoyancy_damping_ratio,
		delta,
	)
	var equilibrium := BuoyancyMath.equilibrium_submersion(
		resolved_body.mass,
		fluid_density,
		displacement_volume,
	)
	var body_basis := resolved_body.global_transform.basis.orthonormalized()
	var body_origin := resolved_body.global_position
	var wet_sum := 0.0
	var sampled_points := 0

	for local_point: Vector3 in sample_points:
		var offset := body_basis * local_point
		var world_point := body_origin + offset

		if not surface_sampler.sample_into(world_point, _surface_sample):
			continue

		sampled_points += 1
		var submerged := BuoyancyMath.submerged_fraction(
			_surface_sample.position.y,
			world_point.y,
			column_height,
		)
		wet_sum += submerged

		if submerged <= 0.0:
			continue

		var point_velocity := (
			resolved_body.linear_velocity
			+ resolved_body.angular_velocity.cross(offset)
		)
		var contact := BuoyancyMath.contact_factor(
			submerged,
			equilibrium,
		)
		var force := BuoyancyMath.point_force(
			point_velocity,
			_surface_sample.velocity,
			submerged,
			resolved_body.mass,
			point_count,
			fluid_density,
			volume_per_point,
			gravity_magnitude,
			damping,
			contact,
			maximum_lift_acceleration,
			linear_drag,
		)
		resolved_body.apply_force(force, offset)

	_wet_fraction = wet_sum / float(point_count)
	_sampled_point_count = sampled_points

	if angular_drag > 0.0 and _wet_fraction > 0.0:
		resolved_body.apply_torque(
			-resolved_body.angular_velocity
			* resolved_body.mass
			* angular_drag
			* _wet_fraction
		)


func _resolve_body() -> RigidBody3D:
	if body != null and is_instance_valid(body):
		return body

	body = _find_body_ancestor()
	return body


func _find_body_ancestor() -> RigidBody3D:
	var current := get_parent()

	while current != null:
		if current is RigidBody3D:
			return current as RigidBody3D
		current = current.get_parent()

	return null


func _has_simulation_authority(resolved_body: RigidBody3D) -> bool:
	if not require_multiplayer_authority:
		return true

	if not multiplayer.has_multiplayer_peer():
		return true

	return resolved_body.is_multiplayer_authority()


func _reset_diagnostics() -> void:
	_wet_fraction = 0.0
	_sampled_point_count = 0
