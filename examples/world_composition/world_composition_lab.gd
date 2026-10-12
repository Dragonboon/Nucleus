extends Node3D
## Small integration proof: stream admissions own visuals, one surface feeds biomes,
## scatter and POI planning. Markers are non-authoritative visualization.

const REGION_SIZE: float = 24.0
var lifecycle: NucleusWorldStreamLifecycle
var surface: NucleusPlaneSurfaceSampler3D
var composer: NucleusBiomeComposer3D
var query: NucleusBiomeSurfaceQuery3D
var recipe: NucleusPOIDistributionProfile3D
var _regions: Dictionary = {}
var _status: Label
var _camera: Camera3D

func _ready() -> void:
	surface = NucleusPlaneSurfaceSampler3D.new()
	add_child(surface)
	composer = NucleusBiomeComposer3D.new()
	var grass := NucleusBiomeProfile3D.new()
	grass.biome_id = &"grass"
	var dry := NucleusBiomeProfile3D.new()
	dry.biome_id = &"dry"
	dry.moisture_range = Vector2(0.0, 0.49)
	dry.priority = 1
	composer.biomes = [grass, dry]
	var noise := FastNoiseLite.new()
	noise.seed = 45
	noise.frequency = 0.035
	composer.moisture_noise = noise
	query = NucleusBiomeSurfaceQuery3D.new(surface, composer)
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
	column.add_child(button)
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
		lifecycle.pump()
	else:
		_show_error("Unable to switch regions", admission)

func _bounds(region_id: StringName) -> Vector2:
	return Vector2(0, 0) if region_id == &"0:0" else Vector2(REGION_SIZE, 0)

func _load_region(region_id: StringName, token: int) -> void:
	var minimum: Vector2 = _bounds(region_id)
	var plan: Dictionary = NucleusPOIPlanner3D.plan(
		minimum, Vector2.ONE * REGION_SIZE, recipe, composer, query.sample_poi
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
	for z in range(8):
		for x in range(8):
			var world_xz: Vector2 = minimum + Vector2(x + 0.5, z + 0.5) * 3.0
			var biome: Dictionary = query.sample_biome(world_xz)
			var tile := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(2.9, 0.2, 2.9)
			tile.mesh = box
			var material := StandardMaterial3D.new()
			material.albedo_color = (
				Color(0.67, 0.55, 0.32) if biome.get("biome_id") == &"dry"
				else Color(0.23, 0.54, 0.36)
			)
			tile.material_override = material
			tile.position = Vector3(world_xz.x, 0, world_xz.y)
			region.add_child(tile)
	for descriptor: Dictionary in plan["points"]:
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
		region.add_child(marker)
	_regions[region_id] = region
	var acknowledgement: Error = lifecycle.mark_loaded(region_id, token)
	if acknowledgement != OK:
		_show_error("Region acknowledgement failed", acknowledgement)
		region.queue_free()
		_regions.erase(region_id)
		return
	var center: Vector2 = minimum + Vector2.ONE * REGION_SIZE * 0.5
	_camera.position = Vector3(center.x + 14.0, 42.0, center.y + 43.0)
	_camera.look_at(Vector3(center.x, 0.0, center.y))
	_status.text = "Resident region: %s · POIs: %d" % [
		region_id, (plan["points"] as Array).size()
	]

func _unload_region(region_id: StringName, token: int) -> void:
	var region: Node = _regions.get(region_id)
	if is_instance_valid(region):
		region.queue_free()
	_regions.erase(region_id)
	lifecycle.mark_unloaded(region_id, token)

func _show_error(context: String, error: Error) -> void:
	var message: String = "%s (%s)" % [context, error_string(error)]
	push_error(message)
	if _status != null:
		_status.text = message
