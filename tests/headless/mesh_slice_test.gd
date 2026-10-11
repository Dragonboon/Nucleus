extends "res://tests/headless/test_case.gd"

func run() -> Dictionary:
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 2.0, 2.0)
	var material := StandardMaterial3D.new()
	var result: Dictionary = NucleusMeshSliceBackend3D.slice(
		box, Vector3.ZERO, Vector3.RIGHT, material
	)
	expect_equal(result.get("reason"), &"ok", "Central box cut succeeds.")
	if result.get("reason") == &"ok":
		var first: ArrayMesh = result["positive"]
		var second: ArrayMesh = result["negative"]
		expect_true(first.get_surface_count() >= 2, "Positive mesh has a cap.")
		expect_true(second.get_surface_count() >= 2, "Negative mesh has a cap.")
		expect_true(first.get_aabb().position.x >= -0.0001, "Positive half is bounded.")
		expect_true(second.get_aabb().end.x <= 0.0001, "Negative half is bounded.")
		var pattern := NucleusMeshSliceBackend3D.to_pattern(result)
		expect_true(pattern.is_usable(), "Cut result builds fracture pattern.")
	var miss: Dictionary = NucleusMeshSliceBackend3D.slice(
		box, Vector3(10.0, 0.0, 0.0), Vector3.RIGHT
	)
	expect_equal(miss.get("reason"), &"no_intersection", "Miss leaves geometry untouched.")
	var invalid: Dictionary = NucleusMeshSliceBackend3D.slice(
		box, Vector3.ZERO, Vector3.ZERO
	)
	expect_equal(invalid.get("reason"), &"invalid_plane", "Invalid normal rejected.")
	return finish()
