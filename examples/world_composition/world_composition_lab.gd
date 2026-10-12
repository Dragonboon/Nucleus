extends Node3D
## Terrain owns height; one analytical query feeds biomes, queued scatter and POIs.
## Terrain stays resident; Tab streams decoration with token-checked completion.
## Primitive trees/rocks and landmark markers are replaceable example content.

const REGION_SIZE: float = 24.0
var lifecycle: NucleusWorldStreamLifecycle
var surface: NucleusTerrainSurfaceSampler3D
var terrain: NucleusTerrainGenerator3D
var materialization: NucleusMaterializationQueue
var _pending: Dictionary = {}
var world_state: NucleusWorldStateService
var save_session: NucleusSaveSession
const CLEARING_RADIUS: float = 2.5
var composer: NucleusBiomeComposer3D
var query: NucleusBiomeSurfaceQuery3D
var recipe: NucleusPOIDistributionProfile3D
var _regions: Dictionary = {}
var _status: Label
var _camera: Camera3D

func _ready() -> void:
	_create_terrain()
	materialization = NucleusMaterializationQueue.new()
	materialization.name = "Materialization"
	add_child(materialization)
	composer = NucleusBiomeComposer3D.new()
	var grass := NucleusBiomeProfile3D.new()
	grass.biome_id = &"grass"
	grass.scatter_profile = _scatter_profile(false)
	grass.terrain_material = NucleusTerrainMaterialProfile.new()
	grass.terrain_material.base_color = Color(0.24, 0.42, 0.20)
	var dry := NucleusBiomeProfile3D.new()
	dry.biome_id = &"dry"
	dry.scatter_profile = _scatter_profile(true)
	dry.terrain_material = NucleusTerrainMaterialProfile.new()
	dry.terrain_material.base_color = Color(0.61, 0.48, 0.28)
	dry.moisture_range = Vector2(0.0, 0.49)
	dry.priority = 1
	composer.biomes = [grass, dry]
	var noise := FastNoiseLite.new()
	noise.seed = 45
	noise.frequency = 0.035
	composer.moisture_noise = noise
	query = NucleusBiomeSurfaceQuery3D.new(surface, composer)
	var colors: Dictionary = NucleusBiomeMaterialMap3D.build(
		query, Vector2(-12, -12), Vector2(72, 48)
	)
	if colors["error"] == OK:
		var ground := ShaderMaterial.new()
		ground.shader = preload("res://examples/world_composition/biome_ground.gdshader")
		ground.set_shader_parameter("biome_colors", colors["texture"])
		ground.set_shader_parameter("map_minimum", Vector2(-12, -12))
		ground.set_shader_parameter("map_size", Vector2(72, 48))
		terrain.material_profile.custom_material = ground
	else:
		_show_error("Biome material map failed", colors["error"])
	var terrain_error: Error = terrain.generate_terrain()
	if terrain_error != OK:
		_show_error("Terrain generation failed", terrain_error)
	save_session = NucleusSaveSession.new()
	save_session.slot_id = "nucleus_world_composition_lab"
	save_session.autosave_policy = NucleusAutosavePolicy.new()
	save_session.autosave_policy.enabled = false
	add_child(save_session)
	world_state = NucleusWorldStateService.new()
	world_state.save_session = save_session
	add_child(world_state)
	recipe = NucleusPOIDistributionProfile3D.new()
	recipe.grid_spacing = 12.0
	recipe.minimum_separation = 8.0
	recipe.density = 0.6
	var kind := NucleusPOIType3D.new()
	kind.poi_id = &"landmark"
	recipe.types = [kind]
	lifecycle = NucleusWorldStreamLifecycle.new()
	lifecycle.process_automatically = false
	add_child(lifecycle)
	lifecycle.load_requested.connect(_load_region)
	lifecycle.unload_requested.connect(_unload_region)
	lifecycle.request_cancelled.connect(_cancel_region)
	_camera = Camera3D.new()
	_camera.position = Vector3(20, 48, 56)
	add_child(_camera)
	_camera.look_at(Vector3(12, 0, 12))
	_camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	add_child(light)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	canvas.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var button := Button.new()
	button.text = "Tab: move active region"
	button.pressed.connect(_toggle_region)
	button.focus_mode = Control.FOCUS_NONE
	column.add_child(button)
	var legend := Label.new()
	legend.text = "Wet: green trees · Dry: ochre rocks · Orange: POI"
	column.add_child(legend)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	for action: Array in [
		["Collect POIs", collect_pois], ["Save", _save_world], ["Load", _load_world],
	]:
		var control := Button.new()
		control.text = action[0]
		control.focus_mode = Control.FOCUS_NONE
		control.pressed.connect(action[1])
		actions.add_child(control)
	_status = Label.new()
	column.add_child(_status)
	var admission: Error = lifecycle.set_desired_regions([&"0:0"])
	if admission == OK:
		lifecycle.pump()
	else:
		_show_error("Unable to set initial region", admission)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_toggle_region()

func _toggle_region() -> void:
	var current: Array[StringName] = lifecycle.get_desired_regions()
	var next: StringName = &"1:0" if current.has(&"0:0") else &"0:0"
	var admission: Error = lifecycle.set_desired_regions([next])
	if admission == OK:
		for region_id: StringName in _pending.keys():
			if not lifecycle.is_desired(region_id):
				lifecycle.cancel_request(region_id, _pending[region_id]["token"])
		lifecycle.pump()
	else:
		_show_error("Unable to switch regions", admission)

func _bounds(region_id: StringName) -> Vector2:
	return Vector2(0, 0) if region_id == &"0:0" else Vector2(REGION_SIZE, 0)

func _load_region(region_id: StringName, token: int) -> void:
	var minimum: Vector2 = _bounds(region_id)
	var plan: Dictionary = NucleusPOIPlanner3D.plan(
		minimum - Vector2.ONE * CLEARING_RADIUS,
		Vector2.ONE * (REGION_SIZE + CLEARING_RADIUS * 2.0), recipe, composer, query.sample_poi
	)
	if plan["error"] != OK:
		var failure: Error = plan["error"]
		_show_error("Cannot load region %s" % region_id, failure)
		lifecycle.mark_request_failed(
			region_id, token, NucleusWorldStreamLifecycle.Operation.LOAD, failure
		)
		return
	var region := Node3D.new()
	region.name = "Region_" + str(region_id).replace(":", "_")
	add_child(region)
	var persistent := NucleusWorldRegion.new()
	persistent.name = "Persistent"
	persistent.region_id = region_id
	region.add_child(persistent)
	var exclusions: Array[NucleusScatterDensityVolume3D] = []
	for descriptor: Dictionary in plan["points"]:
		var point: Vector3 = descriptor["position"]
		var exclusion := NucleusScatterDensityVolume3D.new()
		exclusion.size = Vector2.ONE * CLEARING_RADIUS * 2.0
		exclusion.position = Vector3(point.x, 0.0, point.z)
		region.add_child(exclusion)
		exclusions.append(exclusion)
		if not Rect2(minimum, Vector2.ONE * REGION_SIZE).has_point(Vector2(point.x, point.z)):
			continue
		var marker := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.4
		mesh.bottom_radius = 0.6
		mesh.height = 2.0
		marker.mesh = mesh
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color(0.93, 0.39, 0.23)
		marker.material_override = paint
		marker.position = descriptor["position"] + Vector3.UP
		persistent.add_child(marker)
		var identity := NucleusWorldEntity.new()
		identity.persistent_id = descriptor["id"]
		marker.add_child(identity)
		var adapter := NucleusPropertyStateAdapter.new()
		adapter.adapter_id = &"presentation"
		adapter.target = marker
		adapter.properties = [&"visible"]
		identity.add_child(adapter)
	var registration: Error = world_state.register_region(persistent)
	if registration != OK:
		region.queue_free()
		lifecycle.mark_request_failed(
			region_id, token, NucleusWorldStreamLifecycle.Operation.LOAD, registration
		)
		_show_error("World state registration failed", registration)
		return
	_regions[region_id] = region
	_pending[region_id] = {"token": token, "remaining": composer.biomes.size(), "count": 0}
	for biome: NucleusBiomeProfile3D in composer.biomes:
		var scatter := NucleusScatterRegion3D.new()
		scatter.name = "Scatter_" + str(biome.biome_id)
		scatter.profile = biome.scatter_profile
		scatter.surface = surface
		scatter.region_id = region_id
		scatter.region_size = Vector2.ONE * REGION_SIZE
		scatter.position = Vector3(minimum.x, 0, minimum.y)
		scatter.density_volumes = exclusions
		scatter.density_filter = query.density_for_biome.bind(biome.biome_id)
		scatter.region_ready.connect(_scatter_ready.bind(token))
		scatter.region_failed.connect(_scatter_failed.bind(token))
		region.add_child(scatter)
		var error: Error = scatter.start_build(materialization)
		if error != OK:
			_scatter_failed(region_id, error, token)
			return
	var center: Vector2 = minimum + Vector2.ONE * REGION_SIZE * 0.5
	_camera.position = Vector3(center.x + 14.0, 34.0, center.y + 34.0)
	_camera.look_at(Vector3(center.x, 2.0, center.y))
	_status.text = "Loading %s · POIs: %d" % [region_id, (plan["points"] as Array).size()]


func _scatter_ready(region_id: StringName, count: int, token: int) -> void:
	if not _pending.has(region_id) or _pending[region_id]["token"] != token:
		return
	var progress: Dictionary = _pending[region_id]
	progress["count"] += count
	progress["remaining"] -= 1
	if progress["remaining"] > 0:
		return
	_pending.erase(region_id)
	var error: Error = lifecycle.mark_loaded(region_id, token)
	if error != OK:
		_dispose_region(region_id)
		_show_error("Region acknowledgement failed", error)
		return
	_status.text = "Resident %s · Scatter instances: %d" % [region_id, progress["count"]]


func _scatter_failed(region_id: StringName, error: Error, token: int) -> void:
	if not _pending.has(region_id) or _pending[region_id]["token"] != token:
		return
	_dispose_region(region_id)
	lifecycle.mark_request_failed(
		region_id, token, NucleusWorldStreamLifecycle.Operation.LOAD, error
	)
	_show_error("Scatter failed for %s" % region_id, error)


func _cancel_region(region_id: StringName, _token: int, _operation: int) -> void:
	_dispose_region(region_id)


func _dispose_region(region_id: StringName) -> void:
	_pending.erase(region_id)
	var region: Node = _regions.get(region_id)
	if is_instance_valid(region):
		var persistent := region.get_node("Persistent") as NucleusWorldRegion
		persistent.commit_all()
		world_state.unregister_region(persistent)
		# Exiting the tree immediately cancels each region's queued job and batches.
		remove_child(region)
		region.queue_free()
	_regions.erase(region_id)

func _unload_region(region_id: StringName, token: int) -> void:
	_dispose_region(region_id)
	lifecycle.mark_unloaded(region_id, token)

func _show_error(context: String, error: Error) -> void:
	var message: String = "%s (%s)" % [context, error_string(error)]
	push_error(message)
	if _status != null:
		_status.text = message


func _create_terrain() -> void:
	terrain = NucleusTerrainGenerator3D.new()
	terrain.name = "Terrain"
	terrain.position = Vector3(24, 0, 12)
	var settings := NucleusTerrainProfile.new()
	settings.size = Vector2(72, 48)
	settings.sampling_offset = Vector2(24, 12)
	settings.resolution = 72
	settings.lod_levels = 1
	settings.height_scale = 7.0
	settings.collision_mode = NucleusTerrainProfile.CollisionMode.DISABLED
	settings.noise = FastNoiseLite.new()
	settings.noise.seed = 82
	settings.noise.frequency = 0.035
	terrain.profile = settings
	terrain.material_profile = NucleusTerrainMaterialProfile.new()
	terrain.material_profile.base_color = Color(0.38, 0.43, 0.24)
	add_child(terrain)
	surface = NucleusTerrainSurfaceSampler3D.new()
	surface.name = "Surface"
	surface.terrain = terrain
	add_child(surface)


func _scatter_profile(dry: bool) -> NucleusScatterProfile3D:
	var profile := NucleusScatterProfile3D.new()
	profile.grid_spacing = 2.0
	profile.minimum_separation = 1.5
	profile.density = 0.8
	profile.maximum_slope = deg_to_rad(40.0)
	var variant := NucleusScatterVariant3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0 if not dry else 0.45
	mesh.bottom_radius = 0.85
	mesh.height = 3.0 if not dry else 0.8
	mesh.radial_segments = 6
	variant.mesh = mesh
	profile.vertical_offset = mesh.height * 0.5
	profile.scale_min = 1.0
	profile.scale_max = 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.48, 0.23) if dry else Color(0.12, 0.4, 0.22)
	variant.material_override = material
	profile.variants = [variant]
	return profile


## Example policy: collected landmarks stay hidden while their sites stay reserved.
func collect_pois() -> void:
	for region: Node in _regions.values():
		var persistent := region.get_node("Persistent") as NucleusWorldRegion
		for marker: Node3D in persistent.get_children():
			marker.visible = false
		persistent.commit_all()
	_status.text = "POIs collected. Switch away and return, or Save then Load."


func _save_world() -> void:
	var result: NucleusSaveResult = save_session.save_manual()
	_status.text = "Saved lab slot." if result.succeeded() else error_string(result.error)


func _load_world() -> void:
	var result: NucleusSaveResult = save_session.load_manual()
	_status.text = "Loaded lab slot." if result.succeeded() else error_string(result.error)
