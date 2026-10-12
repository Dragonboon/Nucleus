extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_profile_and_variant_weights()
	_test_bounded_deterministic_generation()
	_test_seam_safe_minimum_separation()
	_test_density_volume_exclusion()
	_test_rejects_unbounded_regions()
	_test_scene_owned_rendering_lifecycle()
	return finish()


func _profile() -> NucleusScatterProfile3D:
	var result: NucleusScatterProfile3D = NucleusScatterProfile3D.new()
	var variant: NucleusScatterVariant3D = NucleusScatterVariant3D.new()
	variant.mesh = BoxMesh.new()
	result.variants.append(variant)
	return result


func _test_profile_and_variant_weights() -> void:
	var profile: NucleusScatterProfile3D = _profile()
	expect_true(
		profile.get_validation_errors().is_empty(),
		"A profile with one weighted mesh is valid.",
	)
	expect_equal(profile.choose_variant(0.5), 0, "One mesh always wins weighted choice.")
	profile.minimum_separation = profile.grid_spacing * 3.0
	expect_false(
		profile.get_validation_errors().is_empty(),
		"Unbounded neighbourhood searches are not accepted.",
	)


func _run_job(
	profile: NucleusScatterProfile3D,
	surface: NucleusSurfaceSampler3D,
	minimum: Vector2,
	size: Vector2,
	volumes: Array[NucleusScatterDensityVolume3D] = [],
) -> Dictionary:
	var job: NucleusScatterBuildJob3D = NucleusScatterBuildJob3D.new()
	var configured: Error = job.configure(
		profile, surface, minimum, size, &"test", volumes,
	)
	if configured != OK:
		return {"error": configured}
	job.cells_per_step = 7
	var safety: int = 0
	while not job.is_terminal() and safety < 2000:
		job.step()
		safety += 1
	if job.get_state() != NucleusMaterializationJob.State.COMPLETED:
		return {"error": job.get_error(), "steps": safety}
	var payload_value: Variant = job.get_result()
	if payload_value is Dictionary:
		return payload_value
	return {"error": ERR_INVALID_DATA}


func _positions(result: Dictionary) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var groups_value: Variant = result.get("groups", {})
	if not groups_value is Dictionary:
		return positions
	var groups: Dictionary = groups_value
	for group_value: Variant in groups.values():
		if not group_value is Array:
			continue
		var group: Array = group_value
		for value: Variant in group:
			if value is Transform3D:
				var transform: Transform3D = value
				positions.append(transform.origin)
	return positions


func _test_bounded_deterministic_generation() -> void:
	var surface: NucleusPlaneSurfaceSampler3D = NucleusPlaneSurfaceSampler3D.new()
	expect_true(attach_test_node(surface), "Surface must enter a SceneTree.")
	var profile: NucleusScatterProfile3D = _profile()
	profile.density = 1.0
	profile.jitter = 0.8
	profile.minimum_separation = 0.0
	var first: Dictionary = _run_job(profile, surface, Vector2.ZERO, Vector2(8.0, 8.0))
	var again: Dictionary = _run_job(profile, surface, Vector2.ZERO, Vector2(8.0, 8.0))
	expect_equal(first, again, "Generation is stable across runs with the same seed.")
	expect_equal(int(first.get("candidate_count", 0)), 16, "Grid has four by four cells.")
	expect_equal(int(first.get("accepted_count", 0)), 16, "Full density fills each cell.")
	var independent_jitter: bool = false
	for point: Vector3 in _positions(first):
		expect_true(
			point.x >= 0.0 and point.x < 8.0
			and point.z >= 0.0 and point.z < 8.0,
			"Points remain inside half-open region bounds.",
		)
		var offset_x: float = fposmod(point.x, profile.grid_spacing)
		var offset_z: float = fposmod(point.z, profile.grid_spacing)
		independent_jitter = independent_jitter or absf(offset_x - offset_z) > 0.2
	expect_true(independent_jitter,
		"Independent salts decorrelate X/Z jitter instead of aligning every offset diagonally.")
	free_test_node(surface)


func _test_seam_safe_minimum_separation() -> void:
	var surface: NucleusPlaneSurfaceSampler3D = NucleusPlaneSurfaceSampler3D.new()
	attach_test_node(surface)
	var profile: NucleusScatterProfile3D = _profile()
	profile.density = 1.0
	profile.grid_spacing = 2.0
	profile.minimum_separation = 1.5
	var first: Dictionary = _run_job(profile, surface, Vector2.ZERO, Vector2(8.0, 8.0))
	var second: Dictionary = _run_job(
		profile, surface, Vector2(8.0, 0.0), Vector2(8.0, 8.0),
	)
	var combined: Dictionary = _run_job(profile, surface, Vector2.ZERO, Vector2(16.0, 8.0))
	var left: Array[Vector3] = _positions(first)
	var right: Array[Vector3] = _positions(second)
	expect_equal(
		left.size() + right.size(), _positions(combined).size(),
		"Adjacent regions match one equivalent contiguous region.",
	)
	for a: Vector3 in left:
		for b: Vector3 in right:
			expect_true(
				a.distance_to(b) >= profile.minimum_separation - 0.0001,
				"Minimum separation is respected across region seams.",
			)
	free_test_node(surface)


func _test_density_volume_exclusion() -> void:
	var scene_root: Node3D = Node3D.new()
	var surface: NucleusPlaneSurfaceSampler3D = NucleusPlaneSurfaceSampler3D.new()
	var mask: NucleusScatterDensityVolume3D = NucleusScatterDensityVolume3D.new()
	scene_root.add_child(surface)
	scene_root.add_child(mask)
	attach_test_node(scene_root)
	mask.position = Vector3(4.0, 0.0, 4.0)
	mask.size = Vector2(8.0, 8.0)
	mask.density_multiplier = 0.0
	var masks: Array[NucleusScatterDensityVolume3D] = [mask]
	var profile: NucleusScatterProfile3D = _profile()
	profile.density = 1.0
	var result: Dictionary = _run_job(
		profile, surface, Vector2.ZERO, Vector2(8.0, 8.0), masks,
	)
	expect_equal(
		int(result.get("accepted_count", -1)), 0,
		"Local density volume can exclude a whole region without physics.",
	)
	free_test_node(scene_root)


func _test_rejects_unbounded_regions() -> void:
	var job: NucleusScatterBuildJob3D = NucleusScatterBuildJob3D.new()
	var surface := NucleusPlaneSurfaceSampler3D.new()
	var result: Error = job.configure(
		_profile(), surface,
		Vector2.ZERO, Vector2(10000.0, 10000.0), &"too_big",
	)
	expect_equal(result, ERR_OUT_OF_MEMORY, "Large jobs must be split into smaller regions.")
	surface.free()


func _test_scene_owned_rendering_lifecycle() -> void:
	var root: Node3D = Node3D.new()
	var surface: NucleusPlaneSurfaceSampler3D = NucleusPlaneSurfaceSampler3D.new()
	var queue: NucleusMaterializationQueue = NucleusMaterializationQueue.new()
	var region: NucleusScatterRegion3D = NucleusScatterRegion3D.new()
	root.add_child(surface)
	root.add_child(queue)
	root.add_child(region)
	attach_test_node(root)
	queue.set_automatic_processing(false)
	region.profile = _profile()
	region.profile.density = 1.0
	region.profile.grid_spacing = 2.0
	region.surface = surface
	region.region_size = Vector2(8.0, 8.0)
	region.candidates_per_step = 3
	region.batch_size_limit = 4
	region.batches_per_frame = 1
	expect_equal(region.start_build(queue), OK, "Region accepts native materialization queue.")
	var steps: int = 0
	while queue.get_pending_count() > 0 and steps < 100:
		queue.pump()
		steps += 1
	expect_true(steps > 1, "Candidate generation is spread over bounded job steps.")
	var batch_steps: int = 0
	while region.is_building() and batch_steps < 100:
		region._process(0.0)
		batch_steps += 1
	expect_equal(region.get_instance_count(), 16, "Region builds all scatter instances.")
	expect_true(region.get_batch_count() > 1, "Rendering splits into bounded batches.")
	region.unload()
	expect_equal(region.get_instance_count(), 0, "Region unload clears instance ownership.")
	expect_equal(region.get_batch_count(), 0, "Region unload clears render batches.")
	free_test_node(root)
