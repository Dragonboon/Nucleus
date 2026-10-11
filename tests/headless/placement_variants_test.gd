extends "res://tests/headless/test_case.gd"

func run() -> Dictionary:
	var first := _scene(&"roof", Vector3.ONE)
	var second := _scene(&"roof", Vector3(2, 1, 1))
	var a := NucleusPlacementVariant3D.new()
	a.variant_id = &"roof_flat"
	a.scene = first
	var b := NucleusPlacementVariant3D.new()
	b.variant_id = &"roof_gable"
	b.scene = second
	var catalog := NucleusPlacementVariantSet3D.new()
	catalog.variants = [a, b]
	catalog.default_variant_id = &"roof_flat"
	expect_true(catalog.validate().is_empty(), "Linked roof variants validate.")
	b.variant_id = a.variant_id
	expect_false(catalog.validate().is_empty(), "Duplicate IDs reject.")
	b.variant_id = &"roof_gable"
	var world := Node3D.new()
	var session := NucleusPlacementSession3D.new()
	world.add_child(session)
	expect_true(attach_test_node(world), "Variant preview needs a SceneTree.")
	expect_equal(session.begin_variants(catalog), OK, "Catalog starts initial preview.")
	expect_equal(session.get_variant_id(), &"roof_flat", "Default ID selected.")
	var initial: Node3D = session._roots[0]
	initial.global_position = Vector3(4, 2, 3)
	expect_equal(session.cycle_variant(), OK, "Cycles to the next asset.")
	expect_equal(session.get_variant_id(), &"roof_gable", "Stable ID changes.")
	expect_true(session._roots[0] != initial, "New mesh scene replaces preview.")
	expect_equal(session._roots[0].global_position, Vector3(4, 2, 3),
		"Preview position is retained.")
	expect_equal(session.cycle_variant(-1), OK, "Reverse cycling works.")
	expect_equal(session.get_variant_id(), &"roof_flat", "Previous option restored.")
	expect_equal(session.select_variant(&"unknown"), ERR_DOES_NOT_EXIST,
		"Unknown ID cannot change preview.")
	expect_equal(session.get_variant_id(), &"roof_flat", "Rejected ID leaves selection.")
	session.cancel()
	expect_equal(session.mode, NucleusPlacementSession3D.Mode.IDLE,
		"Cancel clears preview mode.")
	expect_equal(session.get_variant_id(), &"", "Cancel clears active variant.")
	free_test_node(world)
	return finish()


func _scene(kind: StringName, size: Vector3) -> PackedScene:
	var root := NucleusPlaceable3D.new()
	root.name = "Placeable"
	root.profile = NucleusPlacementProfile3D.new()
	root.profile.kind = kind
	var clearance := BoxShape3D.new()
	clearance.size = size
	root.profile.clearance_shape = clearance
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	root.add_child(visual)
	visual.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed
