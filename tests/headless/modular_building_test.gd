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
	return finish()
