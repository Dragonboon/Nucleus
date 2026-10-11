extends "res://tests/headless/test_case.gd"

func run() -> Dictionary:
	var invalid := NucleusBoxFractureBuilder3D.build(Vector3.ZERO, Vector3i(2, 2, 2))
	expect_false(invalid.is_usable(), "Invalid dimensions have no fracture.")
	var pattern := NucleusBoxFractureBuilder3D.build(Vector3(2, 2, 2), Vector3i(2, 1, 1))
	expect_true(pattern.is_usable(), "Two fragments form a valid pattern.")
	expect_equal(pattern.shards.size(), 2, "Builder creates the requested fragments.")
	expect_true(pattern.shards[0].mesh is BoxMesh, "Fragments contain real mesh geometry.")
	expect_true(pattern.shards[0].collision_shape is BoxShape3D, "Fragments have collision.")

	var root := Node3D.new()
	expect_true(attach_test_node(root), "Destruction test has a SceneTree.")
	var source := StaticBody3D.new()
	root.add_child(source)
	var visual := MeshInstance3D.new()
	visual.mesh = BoxMesh.new()
	source.add_child(visual)
	var component := NucleusDestructibleMesh3D.new()
	component.source_mesh = visual
	component.pattern = pattern
	component.profile = NucleusFractureProfile3D.new()
	component.profile.impulse_threshold = 10.0
	source.add_child(component)
	expect_false(component.fracture(Vector3.ZERO, Vector3.ONE), "Weak impacts do not fracture.")
	expect_true(visual.visible, "Rejected hits leave the source intact.")
	expect_true(component.fracture(Vector3.ZERO, Vector3(0, 20, 0)), "Valid impact fractures.")
	expect_equal(component.get_fragments().size(), 2, "Fragments become rigid bodies.")
	expect_false(visual.visible, "The original visual is hidden.")
	expect_false(component.fracture(Vector3.ZERO, Vector3(0, 20, 0)),
		"One fracture cannot duplicate generated bodies.")
	component.restore()
	expect_true(visual.visible, "Restore re-enables visual.")
	expect_false(component.is_broken, "Restore resets the broken state.")
	free_test_node(root)
	return finish()
