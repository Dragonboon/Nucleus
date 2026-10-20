extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	expect_equal(NucleusSpritePathCase2D.canonical_path(""), "",
		"Empty source path is rejected.")
	expect_equal(NucleusSpritePathCase2D.canonical_path("res://../secret"), "",
		"Parent traversal is rejected.")
	var root := NucleusSpritePathCase2D.canonical_path("res://addons")
	expect_equal(root, "res://addons", "Existing folder resolves to actual spelling.")
	expect_equal(NucleusSpritePathCase2D.canonical_path("res://ADDONS"),
		"res://addons", "Case mismatch can be repaired without renaming files.")
	return finish()
