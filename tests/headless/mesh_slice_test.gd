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
		for half: ArrayMesh in [first, second]:
			var cap: Array = half.surface_get_arrays(half.get_surface_count() - 1)
			var vertices: PackedVector3Array = cap[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = cap[Mesh.ARRAY_NORMAL]
			var cross_product: Vector3 = (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0])
			expect_true(cross_product.dot(normals[0]) < 0.0,
				"Cap winding faces outward using Godot's clockwise convention.")
			expect_false((cap[Mesh.ARRAY_TANGENT] as PackedFloat32Array).is_empty(),
				"Cut surfaces regenerate tangents for normal mapping.")
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
	var unshaded := ArrayMesh.new()
	var source: Array = box.get_mesh_arrays()
	source[Mesh.ARRAY_NORMAL] = null
	source[Mesh.ARRAY_TANGENT] = null
	unshaded.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source)
	var rebuilt: Dictionary = NucleusMeshSliceBackend3D.slice(
		unshaded, Vector3.ZERO, Vector3.RIGHT
	)
	expect_equal(rebuilt.get("reason"), &"ok", "ArrayMesh without authored normals cuts.")
	if rebuilt.get("reason") == &"ok":
		var rebuilt_mesh: ArrayMesh = rebuilt["positive"]
		var face: Array = rebuilt_mesh.surface_get_arrays(0)
		var positions: PackedVector3Array = face[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = face[Mesh.ARRAY_NORMAL]
		var winding: Vector3 = (positions[1] - positions[0]).cross(positions[2] - positions[0])
		expect_true(winding.dot(normals[0]) < 0.0,
			"Rebuilt face normals follow native clockwise winding.")
	return finish()
