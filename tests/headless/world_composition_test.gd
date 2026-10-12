extends "res://tests/headless/test_case.gd"

func run() -> Dictionary:
	var root := Node3D.new()
	var surface := NucleusPlaneSurfaceSampler3D.new()
	var queue := NucleusMaterializationQueue.new()
	root.add_child(surface)
	root.add_child(queue)
	expect_true(attach_test_node(root), "Composition owns surface and queue.")
	queue.set_automatic_processing(false)
	var wet := NucleusBiomeProfile3D.new()
	wet.biome_id = &"wet"
	wet.moisture_range = Vector2(0.5, 1.0)
	var dry := NucleusBiomeProfile3D.new()
	dry.biome_id = &"dry"
	dry.moisture_range = Vector2(0.0, 0.499)
	var biomes := NucleusBiomeComposer3D.new()
	biomes.biomes = [wet, dry]
	var query := NucleusBiomeSurfaceQuery3D.new(surface, biomes)
	expect_equal(query.sample_poi(Vector2.ZERO)["height"], 0.0,
		"Existing surface sampler supplies POI height.")
	expect_equal(query.sample_poi(Vector2.ZERO)["slope"], 0.0,
		"Existing surface sampler supplies POI slope.")
	var profile := NucleusScatterProfile3D.new()
	profile.grid_spacing = 2.0
	profile.density = 1.0
	profile.jitter = 0.0
	profile.minimum_separation = 0.0
	var variant := NucleusScatterVariant3D.new()
	variant.mesh = BoxMesh.new()
	profile.variants.append(variant)
	var left_filter := func(xz: Vector2) -> float:
		return 1.0 if xz.x < 8.0 else 0.0
	var whole := _build(profile, surface, Vector2.ZERO, Vector2(16, 8), left_filter)
	var left := _build(profile, surface, Vector2.ZERO, Vector2(8, 8), left_filter)
	var right := _build(profile, surface, Vector2(8, 0), Vector2(8, 8), left_filter)
	expect_equal(whole["error"], OK, "Filtered scatter succeeds.")
	expect_equal(left["error"], OK, "First region succeeds.")
	expect_equal(right["error"], OK, "Second region succeeds.")
	expect_equal(whole["accepted"], left["accepted"] + right["accepted"],
		"Filtered scatter is stable across seams.")
	expect_equal(right["accepted"], 0, "Filter excludes other region.")
	var poi := NucleusPOIType3D.new()
	poi.poi_id = &"landmark"
	var recipe := NucleusPOIDistributionProfile3D.new()
	recipe.types = [poi]
	var descriptors := NucleusPOIPlanner3D.plan(
		Vector2.ZERO, Vector2(32, 32), recipe, biomes, query.sample_poi
	)
	expect_equal(descriptors["error"], OK, "POIs use existing analytical surface.")
	free_test_node(root)
	_test_actual_lab_scene()
	return finish()


func _build(
	profile: NucleusScatterProfile3D,
	surface: NucleusSurfaceSampler3D,
	minimum: Vector2,
	size: Vector2,
	filter: Callable,
) -> Dictionary:
	var job := NucleusScatterBuildJob3D.new()
	var admitted: Error = job.configure(
		profile, surface, minimum, size, &"composition", [], filter
	)
	if admitted != OK:
		return {"error": admitted}
	while not job.is_terminal():
		job.step()
	var result: Variant = job.get_result()
	if not result is Dictionary:
		return {"error": ERR_INVALID_DATA}
	return {"error": OK, "accepted": int(result["accepted_count"])}

## Regression: admission must result in actual rendered region children, not only data.
func _test_actual_lab_scene() -> void:
	var scene := load("res://examples/world_composition/world_composition_lab.tscn") as PackedScene
	expect_true(scene != null, "Composition lab PackedScene loads.")
	if scene == null:
		return
	var lab := scene.instantiate() as Node3D
	expect_true(attach_test_node(lab), "Composition lab enters SceneTree.")
	if not lab.is_inside_tree():
		lab.free()
		return
	var active: Node = lab.get_node_or_null("Region_0_0")
	expect_true(active != null, "First region is created on ready.")
	if active != null:
		var mesh_count: int = 0
		for child: Node in active.get_children():
			if child is MeshInstance3D:
				mesh_count += 1
		expect_true(mesh_count >= 64, "Initial region has at least 64 visual tiles.")
	expect_equal(lab.lifecycle.get_region_state(&"0:0"),
		NucleusWorldStreamLifecycle.RegionState.LOADED,
		"Initial load admission is acknowledged.")
	lab._toggle_region()
	expect_true(lab.get_node_or_null("Region_1_0") != null,
		"Next region materializes after switching.")
	expect_equal(lab.lifecycle.get_region_state(&"0:0"),
		NucleusWorldStreamLifecycle.RegionState.UNLOADED,
		"Previous region is acknowledged as unloaded.")
	free_test_node(lab)
