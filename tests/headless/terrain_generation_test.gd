extends "res://tests/headless/test_case.gd"

const MeshBuilder := preload(
	"res://addons/nucleus/modules/terrain/terrain_mesh_builder.gd"
)
const PatchBuilder := preload(
	"res://addons/nucleus/modules/terrain/terrain_patch_builder.gd"
)
const TerrainStreamerScript := preload(
	"res://addons/nucleus/modules/terrain/terrain_streamer_3d.gd"
)

const EXAMPLE_SCENES: Array[String] = [
	"res://examples/terrain/terrain_preview.tscn",
	"res://examples/terrain/terrain_preview_presets.tscn",
	"res://examples/terrain/terrain_single.tscn",
	"res://examples/terrain/terrain_grid.tscn",
	"res://examples/terrain/terrain_linear.tscn",
	"res://examples/terrain/terrain_islands.tscn",
	"res://examples/terrain/terrain_streaming.tscn",
	"res://examples/terrain/terrain_material_layers.tscn",
	"res://examples/terrain/terrain_debug_lab.tscn",
]


func run() -> Dictionary:
	_test_profile_validation()
	_test_layouts_are_deterministic()
	_test_direct_array_mesh_generation()
	_test_front_face_winding()
	_test_heightmap_collision_generation()
	_test_uniform_heightmap_collision_scale()
	_test_heightmap_collision_holes()
	_test_material_debug_modes()
	_test_streamer_contract()
	_test_exported_node_references_resolve()
	_test_example_scenes_load()
	return finish()


func _test_profile_validation() -> void:
	var profile := NucleusTerrainProfile.new()
	expect_true(
		not profile.get_validation_errors().is_empty(),
		"Noise terrain should require a FastNoiseLite source.",
	)

	profile.noise = FastNoiseLite.new()
	expect_true(
		profile.get_validation_errors().is_empty(),
		"A basic noise terrain profile should validate.",
	)


func _test_layouts_are_deterministic() -> void:
	var layout := NucleusTerrainLayout.new()
	layout.mode = NucleusTerrainLayout.Mode.ISLANDS
	layout.island_count = 4
	layout.island_spread = Vector2(1200.0, 1200.0)
	layout.island_min_separation = 10.0
	layout.seed = 90210
	var first := layout.build_descriptors(Vector2(128.0, 128.0))
	var second := layout.build_descriptors(Vector2(128.0, 128.0))

	expect_equal(first, second, "Island layouts should be deterministic by seed.")
	expect_equal(first.size(), 4, "The requested island count should fit this layout.")


func _test_direct_array_mesh_generation() -> void:
	var profile := _make_profile()
	profile.resolution = 8
	profile.lod_levels = 2
	var result := MeshBuilder.build_mesh(
		profile,
		Vector3.ZERO,
		1.0,
		0,
		false,
		true,
	)

	expect_equal(result.get("error"), OK, "Terrain mesh generation should succeed.")
	var mesh: ArrayMesh = result["mesh"]
	expect_equal(mesh.get_surface_count(), 1, "Terrain should use one mesh surface.")
	expect_equal(
		mesh.surface_get_array_len(0),
		81,
		"An 8-cell terrain should create a 9x9 vertex grid.",
	)
	expect_equal(
		mesh.surface_get_array_index_len(0),
		384,
		"An 8x8 cell grid should create two triangles per cell.",
	)


func _test_front_face_winding() -> void:
	var profile := _make_profile()
	profile.resolution = 2
	profile.lod_levels = 0
	var result := MeshBuilder.build_mesh(
		profile,
		Vector3.ZERO,
		1.0,
		0,
		false,
		false,
	)

	expect_equal(result.get("error"), OK, "Winding test mesh should build.")
	var mesh: ArrayMesh = result["mesh"]
	var arrays: Array = mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	expect_equal(indices[0], 0, "First terrain triangle starts at the top-left vertex.")
	expect_equal(indices[1], 1, "First terrain triangle advances along +X.")
	expect_equal(indices[2], 3, "First terrain triangle then advances along +Z.")


func _test_heightmap_collision_generation() -> void:
	var profile := _make_profile()
	profile.collision_resolution = 8
	var result := MeshBuilder.build_heightmap_shape(
		profile,
		Vector3.ZERO,
		1.0,
		false,
	)

	expect_equal(result.get("error"), OK, "Heightmap collision generation should succeed.")
	var shape: HeightMapShape3D = result["shape"]
	expect_equal(shape.map_width, 9, "Square collision width should match resolution + 1.")
	expect_equal(shape.map_depth, 9, "Square collision depth should match resolution + 1.")
	expect_float(
		result["uniform_scale"],
		8.0,
		"A 64m/8-cell collision should use an 8m uniform cell scale.",
	)


func _test_uniform_heightmap_collision_scale() -> void:
	var profile := _make_profile()
	profile.size = Vector2(128.0, 64.0)
	profile.collision_resolution = 16
	var result := PatchBuilder.build_patch(
		profile,
		null,
		Vector3.ZERO,
		1.0,
		false,
		0,
		true,
		false,
	)

	expect_equal(result.get("error"), OK, "Rectangular collision patch should build.")
	var patch: Node3D = result["node"]
	var collision := patch.get_node(
		"TerrainCollision/CollisionShape3D"
	) as CollisionShape3D

	expect_float(collision.scale.x, collision.scale.y, "Collision X/Y scale is uniform.")
	expect_float(collision.scale.y, collision.scale.z, "Collision Y/Z scale is uniform.")
	expect_true(
		collision.scale.x > 0.0,
		"Generated heightmap collision should use a positive uniform scale.",
	)
	patch.free()


func _test_heightmap_collision_holes() -> void:
	var profile := _make_profile()
	profile.shape_mode = NucleusTerrainProfile.ShapeMode.ISLAND
	profile.edge_floor_height = -20.0
	profile.collision_resolution = 6
	profile.collision_holes_below_height = true
	profile.collision_hole_height = -10.0
	var result := MeshBuilder.build_heightmap_shape(
		profile,
		Vector3.ZERO,
		1.0,
		false,
	)

	expect_equal(result.get("error"), OK, "Collision-hole generation should succeed.")
	var shape: HeightMapShape3D = result["shape"]
	var has_hole := false

	for height: float in shape.map_data:
		if is_nan(height):
			has_hole = true
			break

	expect_true(has_hole, "Island collision can omit samples below the configured height.")


func _test_material_debug_modes() -> void:
	var material_profile := NucleusTerrainMaterialProfile.new()
	var layer := NucleusTerrainTextureLayer.new()
	layer.tint = Color.RED
	material_profile.layers.append(layer)

	var material := material_profile.create_material(
		-10.0,
		40.0,
		NucleusTerrainMaterialProfile.DebugView.LAYER_WEIGHTS,
		7,
		20.0,
	) as ShaderMaterial

	expect_true(material != null, "Debug terrain material should be a ShaderMaterial.")
	expect_equal(
		material.get_shader_parameter("debug_view"),
		NucleusTerrainMaterialProfile.DebugView.LAYER_WEIGHTS,
		"Debug view should reach the built-in shader.",
	)
	expect_equal(
		material_profile.get_active_layer_count(),
		1,
		"Material profile should expose active layer count.",
	)


func _make_profile() -> NucleusTerrainProfile:
	var profile := NucleusTerrainProfile.new()
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.01
	profile.noise = noise
	profile.size = Vector2(64.0, 64.0)
	return profile


func _test_streamer_contract() -> void:
	var streamer: NucleusTerrainStreamer3D = TerrainStreamerScript.new()
	expect_equal(streamer.chunks_behind, 2, "Streamer keeps two chunks behind by default.")
	expect_equal(streamer.chunks_ahead, 4, "Streamer keeps four chunks ahead by default.")
	expect_equal(
		streamer.max_new_chunks_per_update,
		1,
		"Streamer builds one new chunk per update by default.",
	)
	expect_equal(
		streamer.get_loaded_chunk_count(),
		0,
		"New streamer starts with no loaded chunks.",
	)
	streamer.free()


func _test_example_scenes_load() -> void:
	for scene_path: String in EXAMPLE_SCENES:
		var packed: PackedScene = load(scene_path) as PackedScene
		expect_true(
			packed != null,
			"Terrain example should load: %s" % scene_path,
		)


func _test_exported_node_references_resolve() -> void:
	var stream_scene := load(
		"res://examples/terrain/terrain_streaming.tscn"
	) as PackedScene
	expect_true(stream_scene != null, "Streaming example should load.")

	if stream_scene != null:
		var instance := stream_scene.instantiate()
		var streamer := instance.get_node("TerrainStream") as NucleusTerrainStreamer3D
		var hud := instance.get_node("StreamingHUD")

		expect_true(
			streamer.tracked_node != null,
			"Streaming example tracked_node should resolve from its saved NodePath.",
		)
		expect_true(
			hud.get("streamer") != null,
			"Streaming HUD streamer reference should resolve.",
		)
		expect_true(
			hud.get("tracked_node") != null,
			"Streaming HUD tracked_node reference should resolve.",
		)
		instance.free()

	var debug_scene := load(
		"res://examples/terrain/terrain_debug_lab.tscn"
	) as PackedScene
	expect_true(debug_scene != null, "Terrain debug lab should load.")

	if debug_scene != null:
		var instance := debug_scene.instantiate()
		var debug_ui := instance.get_node("DebugUI")
		var terrain_ref := debug_ui.get("terrain") as NucleusTerrainGenerator3D

		expect_true(
			terrain_ref != null,
			"Debug lab terrain reference should resolve from its saved NodePath.",
		)
		instance.free()
