extends Node
## Runs the real scene and asynchronous queue across load, cancel, unload and reload.
## Graphical runs also verify the renderer's final world-space instance transforms.

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := preload("res://examples/world_composition/world_composition_lab.tscn")
	var lab := packed.instantiate() as Node3D
	add_child(lab)
	var lifecycle := lab.get("lifecycle") as NucleusWorldStreamLifecycle
	lab.call("_toggle_region")
	lab.call("_toggle_region")
	await _settle(lifecycle)
	_check(lifecycle.get_resident_regions() == [&"0:0"], "Only the latest request is resident.")
	var first: int = _inspect(lab, "Region_0_0")
	lab.call("_toggle_region")
	await _settle(lifecycle)
	_check(lab.get_node_or_null("Region_0_0") == null, "Unloaded content is freed.")
	_check(_inspect(lab, "Region_1_0") > 0, "Translated region contains native batches.")
	lab.call("_toggle_region")
	await _settle(lifecycle)
	_check(_inspect(lab, "Region_0_0") == first, "Returning restores the same instance count.")
	var queue := lab.get("materialization") as NucleusMaterializationQueue
	_check(queue.get_pending_count() == 0, "No orphan materialization jobs remain.")
	lab.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if _failures == 0:
		print("WORLD_COMPOSITION_SMOKE: PASS")
	get_tree().quit(0 if _failures == 0 else 1)


func _settle(lifecycle: NucleusWorldStreamLifecycle) -> void:
	for frame in range(180):
		await get_tree().process_frame
		if lifecycle.is_settled():
			return
	_check(false, "Streaming did not finish within 180 frames.")


func _inspect(lab: Node3D, region_name: String) -> int:
	var region: Node = lab.get_node_or_null(region_name)
	_check(region != null, "Requested region exists.")
	if region == null:
		return 0
	var query := lab.get("query") as NucleusBiomeSurfaceQuery3D
	var count: int = 0
	for child: Node in region.get_children():
		if not child is NucleusScatterRegion3D:
			continue
		var biome_id := StringName(str(child.name).trim_prefix("Scatter_"))
		for batch: Node in child.get_children():
			if not batch is NucleusScatterBatch3D:
				continue
			count += batch.multimesh.instance_count
			if DisplayServer.get_name() == "headless":
				continue # Dummy renderer cannot read back per-instance transforms.
			for index in range(batch.multimesh.instance_count):
				var placement: Transform3D = (
					batch.global_transform * batch.multimesh.get_instance_transform(index)
				)
				var xz := Vector2(placement.origin.x, placement.origin.z)
				_check(query.sample_biome(xz).get("biome_id") == biome_id,
					"Rendered transform belongs to its biome.")
				var expected: float = query.sample_poi(xz)["height"] + child.profile.vertical_offset
				_check(absf(expected - placement.origin.y) < 0.001,
					"Rendered transform follows terrain height.")
	_check(count > 0, "Region has visible scatter instances.")
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("WORLD_COMPOSITION_SMOKE: FAIL: " + message)
