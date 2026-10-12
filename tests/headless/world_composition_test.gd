extends "res://tests/headless/test_case.gd"

class DensityOwner:
	extends Node
	func density(_xz: Vector2) -> float:
		return 0.0


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
	var material := NucleusTerrainMaterialProfile.new()
	material.base_color = Color.RED
	wet.terrain_material = material
	var mapped: Dictionary = NucleusBiomeMaterialMap3D.build(
		query, Vector2.ZERO, Vector2(8, 8), 4
	)
	expect_equal(mapped["error"], OK, "Biome colors bake through the shared surface query.")
	var texture: ImageTexture = mapped["texture"]
	expect_equal(texture.get_image().get_pixel(0, 0), Color.RED,
		"Map consumes the selected biome's existing material profile.")
	expect_equal(material.base_color, Color.RED, "Map generation never mutates shared profiles.")
	expect_equal(NucleusBiomeMaterialMap3D.build(
		query, Vector2.ZERO, Vector2(8, 8), 1024
	)["error"], ERR_INVALID_PARAMETER, "Unbounded material map is rejected.")
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
	var filter_owner := DensityOwner.new()
	var expired_filter: Callable = filter_owner.density
	filter_owner.free()
	var expired := _build(profile, surface, Vector2.ZERO, Vector2(8, 8), expired_filter)
	expect_equal(expired["accepted"], 0,
		"An expired density callback stays closed instead of populating every biome.")
	var poi := NucleusPOIType3D.new()
	poi.poi_id = &"landmark"
	var recipe := NucleusPOIDistributionProfile3D.new()
	recipe.types = [poi]
	var descriptors := NucleusPOIPlanner3D.plan(
		Vector2.ZERO, Vector2(32, 32), recipe, biomes, query.sample_poi
	)
	expect_equal(descriptors["error"], OK, "POIs use existing analytical surface.")
	free_test_node(root)
	_test_invalid_recipe_fails_explicitly()
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
	var terrain := lab.get("terrain") as NucleusTerrainGenerator3D
	expect_true(terrain != null and terrain.has_node("GeneratedTerrain"),
		"Lab uses the existing terrain generator, not placeholder tiles.")
	var sampler := lab.get("surface") as NucleusTerrainSurfaceSampler3D
	expect_true(sampler != null and sampler.terrain == terrain,
		"Scatter and POIs query the rendered terrain owner.")
	# Switching before queue completion must cancel obsolete work, then rebuild cleanly.
	lab.call("_toggle_region")
	expect_true(lab.get_node_or_null("Region_0_0") == null,
		"Pending old region is detached immediately on cancellation.")
	lab.call("_toggle_region")
	_finish_lab_build(lab)
	var active: Node = lab.get_node_or_null("Region_0_0")
	expect_true(active != null, "Initial region can reload after cancellation.")
	var instances: int = _check_lab_scatter(lab, active)
	lab.call("collect_pois")
	var world := lab.get("world_state") as NucleusWorldStateService
	var saved: Dictionary = world.capture_state()
	expect_false(saved.is_empty(), "Procedural POI identities capture persistent state.")
	expect_true(instances > 0, "Actual native MultiMesh batches contain biome decoration.")
	var lifecycle := lab.get("lifecycle") as NucleusWorldStreamLifecycle
	expect_true(lifecycle != null, "Lab owns the streaming lifecycle.")
	if lifecycle == null:
		free_test_node(lab)
		return
	expect_equal(lifecycle.get_region_state(&"0:0"),
		NucleusWorldStreamLifecycle.RegionState.LOADED,
		"Initial load admission is acknowledged.")
	lab.call("_toggle_region")
	_finish_lab_build(lab)
	expect_true(lab.get_node_or_null("Region_1_0") != null,
		"Next region materializes after switching.")
	expect_equal(lifecycle.get_region_state(&"0:0"),
		NucleusWorldStreamLifecycle.RegionState.UNLOADED,
		"Previous region is acknowledged as unloaded.")
	_check_lab_scatter(lab, lab.get_node_or_null("Region_1_0"))
	lab.call("_toggle_region")
	_finish_lab_build(lab)
	expect_equal(_check_lab_scatter(lab, lab.get_node_or_null("Region_0_0")), instances,
		"Unload/reload restores deterministic decoration count.")
	var persistent: Node = lab.get_node("Region_0_0/Persistent")
	for marker: Node3D in persistent.get_children():
		expect_false(marker.visible, "Collected POIs remain collected after streamed reload.")
	free_test_node(lab)


func _finish_lab_build(lab: Node3D) -> void:
	var queue := lab.get("materialization") as NucleusMaterializationQueue
	queue.set_automatic_processing(false)
	var lifecycle := lab.get("lifecycle") as NucleusWorldStreamLifecycle
	for frame in range(100):
		queue.pump()
		for region: Node in lab.get_children():
			for child: Node in region.get_children():
				if child is NucleusScatterRegion3D and child.is_processing():
					child.call("_process", 0.016)
		if lifecycle.is_settled():
			break
	expect_true(lifecycle.is_settled(), "Bounded queue and staging complete the load.")


func _check_lab_scatter(lab: Node3D, region: Node) -> int:
	if region == null:
		return 0
	var query := lab.get("query") as NucleusBiomeSurfaceQuery3D
	var count: int = 0
	for child: Node in region.get_children():
		if not child is NucleusScatterRegion3D:
			continue
		count += child.get_instance_count()
		var biome_id := StringName(str(child.name).trim_prefix("Scatter_"))
		# Headless uses the dummy renderer, which cannot read back MultiMesh transforms.
		# Verify the exact configured job output and compare its size to native batches.
		var job := NucleusScatterBuildJob3D.new()
		var error: Error = job.configure(child.profile, child.surface,
			Vector2(child.global_position.x, child.global_position.z), child.region_size,
			child.region_id, child.density_volumes, child.density_filter)
		expect_equal(error, OK, "Scene wiring configures the real Scatter job.")
		while not job.is_terminal():
			job.step()
		var result: Dictionary = job.get_result()
		expect_equal(result["accepted_count"], child.get_instance_count(),
			"Native batches contain every accepted transform.")
		for group: Array in result["groups"].values():
			for placement: Transform3D in group:
				var world: Vector3 = placement.origin
				var xz := Vector2(world.x, world.z)
				expect_equal(query.sample_biome(xz).get("biome_id"), biome_id,
					"Every accepted instance belongs to its assigned biome.")
				for volume: NucleusScatterDensityVolume3D in child.density_volumes:
					expect_false(volume.contains_world_xz(Vector3(world.x, 0, world.z)),
						"Scatter respects POI clearings, including neighboring region sites.")
				var expected: float = query.sample_poi(xz)["height"] + child.profile.vertical_offset
				expect_true(absf(world.y - expected) < 0.001,
					"Decoration follows terrain height even in translated regions.")

	return count

func _test_invalid_recipe_fails_explicitly() -> void:
	var biome := NucleusBiomeProfile3D.new()
	biome.biome_id = &"sample"
	var composer := NucleusBiomeComposer3D.new()
	composer.biomes = [biome]
	var kind := NucleusPOIType3D.new()
	kind.poi_id = &"sample_poi"
	var recipe := NucleusPOIDistributionProfile3D.new()
	recipe.grid_spacing = 12.0
	recipe.minimum_separation = 18.0
	recipe.types = [kind]
	expect_false(recipe.validate().is_empty(),
		"Separation greater than grid spacing is rejected.")
	var surface := func(_position: Vector2) -> Dictionary:
		return {"height": 0.0, "slope": 0.0}
	var result: Dictionary = NucleusPOIPlanner3D.plan(
		Vector2.ZERO, Vector2(24, 24), recipe, composer, surface
	)
	expect_equal(result["error"], ERR_INVALID_PARAMETER,
		"Invalid POI configuration cannot silently produce empty regions.")
