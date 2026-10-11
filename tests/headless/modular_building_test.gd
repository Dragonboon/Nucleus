extends "res://tests/headless/test_case.gd"

func run() -> Dictionary:
	var rules := NucleusModularRuleSet.new()
	rules.fallback_variant = &"isolated"
	var end_rule := NucleusModularRule.new()
	end_rule.neighbor_mask = 1
	end_rule.variant_id = &"end"
	end_rule.allow_rotations = true
	var corner_rule := NucleusModularRule.new()
	corner_rule.neighbor_mask = 3
	corner_rule.variant_id = &"corner"
	corner_rule.allow_rotations = true
	rules.rules = [end_rule, corner_rule]
	expect_true(rules.validate().is_empty(), "Authored rules valid.")
	expect_equal(rules.resolve_variant(2)["variant_id"], &"end", "Rotated end.")
	expect_equal(rules.resolve_variant(2)["rotation_steps"], 1, "End rotated once.")
	expect_equal(rules.resolve_variant(6)["variant_id"], &"corner", "Rotated corner.")
	expect_equal(rules.resolve_variant(6)["rotation_steps"], 1, "Corner rotation.")
	expect_equal(rules.resolve(0), &"isolated", "Old resolve API preserved.")
	expect_equal(NucleusModularRuleSet.rotate_mask(1, 4), 1, "Full turn invariant.")
	expect_true(rules.resolve_variant(-1).is_empty(), "Invalid mask rejected.")
	var occupied: Dictionary = {
		Vector3i(0, 0, 0): true,
		Vector3i(1, 0, 0): true,
		Vector3i(1, 0, 1): true,
	}
	var query := func(cell: Vector3i) -> bool: return occupied.has(cell)
	var changes := NucleusModularNeighborhood.resolve_around(
		Vector3i.ZERO, query, rules
	)
	expect_equal(changes.size(), 5, "Exactly five cells reassessed.")
	expect_equal(changes[0]["variant_id"], &"end", "East neighbor resolved.")
	expect_equal(changes[0]["rotation_steps"], 1, "Orientation stored.")
	occupied.erase(Vector3i.ZERO)
	changes = NucleusModularNeighborhood.resolve_around(Vector3i.ZERO, query, rules)
	expect_false(changes[0]["occupied"], "Removed cell has clear descriptor.")
	expect_equal(changes[2]["variant_id"], &"isolated", "Remaining cell updated.")
	_test_visual_binding()
	return finish()

func _test_visual_binding() -> void:
	var root := Node3D.new()
	expect_true(attach_test_node(root), "Modular presenter needs SceneTree.")
	var board := NucleusSquareBoard3D.new()
	root.add_child(board)
	var presenter := NucleusModularVariantBinding3D.new()
	presenter.square_board = board
	root.add_child(presenter)
	var catalog := NucleusPlacementVariantSet3D.new()
	var variant := NucleusPlacementVariant3D.new()
	variant.variant_id = &"end"
	var scene_root := Node3D.new()
	scene_root.name = "CosmeticEnd"
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	scene_root.add_child(mesh)
	mesh.owner = scene_root
	var packed := PackedScene.new()
	expect_equal(packed.pack(scene_root), OK, "Cosmetic scene packs.")
	scene_root.free()
	variant.scene = packed
	catalog.variants = [variant]
	presenter.catalog = catalog
	var cell := Vector3i(2, -1, 1)
	expect_true(board.paint_cell(cell), "Board owns the occupied cell.")
	var descriptors: Array[Dictionary] = [{
		"cell": cell, "occupied": true, "variant_id": &"end",
		"rotation_steps": 1,
	}]
	presenter.apply_updates(descriptors)
	expect_equal(presenter._visuals.size(), 1, "A known visual is instantiated.")
	var visual: Node3D = presenter._visuals[cell]["node"]
	expect_equal(visual.global_position, board.cell_to_world(cell),
		"Cosmetic mesh aligns with board center.")
	expect_float(visual.rotation.y, PI * 0.5, "Variant is rotated.")
	descriptors[0]["rotation_steps"] = 2
	presenter.apply_updates(descriptors)
	expect_true(visual == presenter._visuals[cell]["node"],
		"Changing a rule orientation reuses the same visual.")
	expect_float(visual.rotation.y, PI, "Existing visual updates rotation.")
	descriptors[0]["occupied"] = false
	presenter.apply_updates(descriptors)
	expect_equal(presenter._visuals.size(), 0, "Erasure removes cosmetic visuals.")
	expect_true(board.has_tile(cell), "Cosmetic updates never mutate occupancy.")
	free_test_node(root)
