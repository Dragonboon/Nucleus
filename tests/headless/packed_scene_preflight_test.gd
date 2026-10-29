extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_missing_and_empty()
	_test_markers_and_collision_policy()
	_test_script_and_budget_policy()
	return finish()


func _test_missing_and_empty() -> void:
	var report := NucleusPackedScenePreflight.inspect(null)
	expect_false(bool(report["ok"]), "Null PackedScene is invalid.")
	report = NucleusPackedScenePreflight.inspect(PackedScene.new())
	expect_false(bool(report["ok"]), "Empty PackedScene is invalid.")


func _build_fixture(with_script: bool = false) -> PackedScene:
	var root := Node3D.new()
	root.name = "Fixture"
	var marker := Marker3D.new()
	marker.name = "Socket"
	root.add_child(marker)
	marker.owner = root
	var nested := Node3D.new()
	nested.name = "Nested"
	root.add_child(nested)
	nested.owner = root
	var deep := Marker3D.new()
	deep.name = "DeepSocket"
	nested.add_child(deep)
	deep.owner = root
	var collider := CollisionShape3D.new()
	collider.name = "Collision"
	root.add_child(collider)
	collider.owner = root
	if with_script:
		root.set_script(preload("res://addons/nucleus/components/world/fields/world_mask_3d.gd"))
	var scene := PackedScene.new()
	var error := scene.pack(root)
	expect_equal(error, OK, "Fixture can be packed without entering SceneTree.")
	root.free()
	return scene


func _test_markers_and_collision_policy() -> void:
	var scene := _build_fixture()
	var required := PackedStringArray(["Socket"])
	var report := NucleusPackedScenePreflight.inspect(scene, required, true, false, false)
	expect_true(bool(report["ok"]), "Valid direct marker and 3D root accepted.")
	expect_equal(report["node_count"], 5, "Packed nodes counted without instancing.")
	expect_true((report["direct_markers"] as PackedStringArray).has("Socket"),
		"Direct socket discovered.")
	var wrong := NucleusPackedScenePreflight.inspect(
		scene, PackedStringArray(["DeepSocket"]), true
	)
	expect_false(bool(wrong["ok"]), "Nested markers cannot satisfy direct contracts.")
	var no_collision := NucleusPackedScenePreflight.inspect(
		scene, required, true, false, true
	)
	expect_false(bool(no_collision["ok"]), "Collision policy checks SceneState types.")


func _test_script_and_budget_policy() -> void:
	var scene := _build_fixture(true)
	var blocked := NucleusPackedScenePreflight.inspect(
		scene, PackedStringArray(), true, true, false
	)
	expect_false(bool(blocked["ok"]), "Script policy rejects scripted PackedScene.")
	var limited := NucleusPackedScenePreflight.inspect(
		scene, PackedStringArray(), false, false, false, 2
	)
	expect_false(bool(limited["ok"]), "Node limit bounds large inspections.")
