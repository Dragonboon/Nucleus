extends "res://tests/headless/test_case.gd"

func run() -> Dictionary:
	_test_geometry()
	_test_limits()
	_test_roadbed()
	_test_surface_and_component()
	_test_lab_layout()
	return finish()

func _line() -> Curve3D:
	var curve := Curve3D.new()
	curve.add_point(Vector3(0, 0, 0))
	curve.add_point(Vector3(10, 0, 0))
	return curve

func _test_geometry() -> void:
	var curve := _line()
	var profile := NucleusSplinePathProfile3D.new()
	profile.sample_spacing = 1.0
	profile.width = 2.0
	profile.surface_offset = 0.0
	var result := NucleusSplinePathMeshBuilder3D.build(curve, profile)
	expect_equal(result["error"], OK, "Straight ribbon generates.")
	if result["error"] != OK:
		return
	var mesh: ArrayMesh = result["mesh"]
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	expect_equal(result["sections"], 11, "Section count includes endpoints.")
	expect_equal(verts.size(), 22, "Two vertices per section.")
	expect_equal(verts[0], Vector3(0, 0, -1), "Left edge of path.")
	expect_equal(verts[1], Vector3(0, 0, 1), "Right edge of path.")
	expect_true(normals[0].dot(Vector3.UP) > 0.99, "Road faces upward.")
	expect_equal(uv[0], Vector2(0, 0), "Start UV is zero.")
	expect_float(uv[uv.size() - 1].y, 2.5, "UV distance never resets.")
	var mirrored: Transform3D = Transform3D(Basis.IDENTITY, Vector3(5, 2, 0))
	var moved := NucleusSplinePathMeshBuilder3D.build(
		curve, profile, mirrored, mirrored
	)
	expect_equal(moved["error"], OK, "Matching transforms preserve geometry.")

func _test_limits() -> void:
	var curve := _line()
	var profile := NucleusSplinePathProfile3D.new()
	profile.max_sections = 3
	profile.sample_spacing = 0.1
	var failed := NucleusSplinePathMeshBuilder3D.build(curve, profile)
	expect_equal(failed["error"], ERR_OUT_OF_MEMORY, "Work budget is enforced.")
	profile.max_sections = 512
	profile.width = 0.0
	expect_false(profile.validate().is_empty(), "Invalid width rejected.")
	profile.width = 2.0
	expect_equal(NucleusSplinePathMeshBuilder3D.build(null, profile)["error"],
		ERR_INVALID_PARAMETER, "Null curve rejected.")
	var empty := Curve3D.new()
	expect_equal(NucleusSplinePathMeshBuilder3D.build(empty, profile)["error"],
		ERR_INVALID_DATA, "Empty curve rejected.")

func _test_surface_and_component() -> void:
	var root := Node3D.new()
	expect_true(attach_test_node(root), "Road test requires SceneTree.")
	var path := Path3D.new()
	path.curve = _line()
	root.add_child(path)
	var output := MeshInstance3D.new()
	root.add_child(output)
	var surface := NucleusPlaneSurfaceSampler3D.new()
	surface.position.y = 2.0
	root.add_child(surface)
	var profile := NucleusSplinePathProfile3D.new()
	var binding := NucleusSplineRoad3D.new()
	binding.path = path
	binding.target_mesh = output
	binding.surface_sampler = surface
	binding.profile = profile
	binding.auto_build_on_ready = false
	root.add_child(binding)
	expect_equal(binding.rebuild(), OK, "Component builds with a surface.")
	var previous: Mesh = output.mesh
	expect_true(previous != null, "Generated output attached.")
	profile.max_sections = 2
	expect_equal(binding.rebuild(), ERR_OUT_OF_MEMORY,
		"Failed rebuild propagates the work limit.")
	expect_true(output.mesh == previous, "Failed rebuild preserves old geometry.")
	profile.max_sections = 512
	expect_equal(binding.rebuild(), OK, "Road can be rebuilt after failure.")
	binding.clear_generated()
	expect_true(output.mesh == null, "Clearing removes generated geometry.")
	free_test_node(root)

func _test_roadbed() -> void:
	var profile := NucleusSplinePathProfile3D.new()
	profile.roadbed_enabled = true
	profile.width = 2.0
	profile.shoulder_width = 0.5
	profile.crown_height = 0.18
	profile.shoulder_drop = 0.08
	profile.roadbed_thickness = 0.3
	profile.sample_spacing = 1.0
	profile.surface_offset = 0.0
	var result: Dictionary = NucleusSplinePathMeshBuilder3D.build(_line(), profile)
	expect_equal(result["error"], OK, "Extruded roadbed builds successfully.")
	if result["error"] != OK:
		return
	var mesh: ArrayMesh = result["mesh"]
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var texcoords: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var faces: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	expect_equal(vertices.size(), int(result["sections"]) * 7,
		"Seven vertices per roadbed section.")
	expect_equal(faces.size(), (int(result["sections"]) - 1) * 7 * 6,
		"Four road lanes and three lower surfaces are indexed.")
	expect_float(vertices[2].y, 0.18, "Road crown is raised.")
	expect_float(vertices[0].y, -0.08, "Left shoulder is lowered.")
	expect_float(vertices[5].y, -0.38, "Roadbed lower skirt has depth.")
	expect_float(texcoords[vertices.size() - 1].y, 2.5,
		"Extruded road preserves world-distance UVs.")
	profile.roadbed_thickness = 0.0
	expect_false(profile.validate().is_empty(), "Zero thickness is rejected.")

## The actual lab must open without a large blocking control panel.
func _test_lab_layout() -> void:
	var scene := load("res://examples/spline_paths/spline_paths_lab.tscn") as PackedScene
	expect_true(scene != null, "Spline lab scene loads.")
	if scene == null:
		return
	var lab := scene.instantiate() as Node3D
	expect_true(attach_test_node(lab), "Spline lab enters SceneTree.")
	var panel := lab.find_child("SplineControlsPanel", true, false) as PanelContainer
	var controls := lab.find_child("SplineAdvancedControls", true, false) as VBoxContainer
	var road := lab.find_child("SplineRoad", true, false) as NucleusSplineRoad3D
	expect_true(panel != null, "Viewport HUD is present.")
	expect_true(controls != null and not controls.visible,
		"Advanced controls start collapsed.")
	expect_true(road != null and road.target_mesh.mesh != null,
		"Collapsing controls does not stop road generation.")
	if panel != null:
		var bounds: Rect2 = panel.get_global_rect()
		expect_true(bounds.position.x > 0.0, "Panel is no longer left-anchored.")
		expect_true(bounds.size.x <= 300.0, "Compact HUD has bounded width.")
	free_test_node(lab)
