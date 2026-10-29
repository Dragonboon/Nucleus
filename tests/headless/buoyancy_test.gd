extends "res://tests/headless/test_case.gd"

const BuoyancyMath := preload(
	"res://addons/nucleus/components/world/buoyancy/buoyancy_math.gd"
)


func run() -> Dictionary:
	_test_submerged_fraction()
	_test_capacity_and_equilibrium()
	_test_damping_is_bounded_by_timestep()
	_test_point_force_uses_surface_velocity()
	_test_component_contract()
	return finish()


func _test_submerged_fraction() -> void:
	expect_float(
		BuoyancyMath.submerged_fraction(0.0, 1.0, 2.0),
		0.0,
		"Column fully above the surface should be dry.",
	)
	expect_float(
		BuoyancyMath.submerged_fraction(0.0, 0.0, 2.0),
		0.5,
		"A centered surface crossing should half-submerge the column.",
	)
	expect_float(
		BuoyancyMath.submerged_fraction(0.0, -1.0, 2.0),
		1.0,
		"Column fully below the surface should be saturated.",
	)


func _test_capacity_and_equilibrium() -> void:
	expect_float(
		BuoyancyMath.equilibrium_submersion(500.0, 1000.0, 1.0),
		0.5,
		"Half-capacity mass should require half of the displacement volume.",
	)
	expect_true(
		is_inf(BuoyancyMath.equilibrium_submersion(500.0, 0.0, 1.0)),
		"Zero-density media should expose no finite displacement capacity.",
	)


func _test_damping_is_bounded_by_timestep() -> void:
	var damping := BuoyancyMath.damping_coefficient(
		1000.0,
		9.8,
		0.25,
		0.8,
		0.01,
		4.0,
		0.02,
	)

	expect_true(damping > 0.0, "Valid columns should produce positive damping.")
	expect_true(
		damping <= 0.5,
		"Damping should be bounded by point_mass / physics_step.",
	)


func _test_point_force_uses_surface_velocity() -> void:
	var force := BuoyancyMath.point_force(
		Vector3.ZERO,
		Vector3(2.0, 0.0, 0.0),
		1.0,
		1000.0,
		4,
		1000.0,
		0.25,
		9.8,
		0.0,
		1.0,
		4.0,
		2.0,
	)

	expect_float(force.x, 1000.0, "Horizontal drag should follow medium velocity.")
	expect_float(force.y, 2450.0, "Full displacement should apply Archimedes lift.")
	expect_float(force.z, 0.0, "Unused horizontal axis should remain force-free.")


func _test_component_contract() -> void:
	var root := Node3D.new()
	var body := RigidBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	body.add_child(collision)
	root.add_child(body)

	var surface := NucleusPlaneSurfaceSampler3D.new()
	root.add_child(surface)

	var buoyancy := NucleusBuoyancy3D.new()
	buoyancy.surface_sampler = surface
	body.add_child(buoyancy)

	expect_true(
		attach_test_node(root),
		"Buoyancy dependency resolution requires a live SceneTree.",
	)
	expect_true(
		buoyancy.body == body,
		"Buoyancy should resolve the nearest RigidBody3D ancestor.",
	)
	expect_float(
		buoyancy.get_displacement_capacity_kg(),
		1000.0,
		"Default density and volume should support 1000 kg at full displacement.",
	)
	expect_true(
		buoyancy._get_configuration_warnings().is_empty(),
		"A normally wired buoyancy component should have no configuration warnings.",
	)

	free_test_node(root)
