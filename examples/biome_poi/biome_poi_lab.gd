extends Node3D
## Visual-only validation of global biome classification and POI descriptors.

const EXTENT: int = 11
const SPACING: float = 3.0
var composer: NucleusBiomeComposer3D
var recipe: NucleusPOIDistributionProfile3D
var _content: Node3D
var _status: Label
var _seed: int = 42

func _ready() -> void:
	composer = _build_composer()
	recipe = _build_recipe()
	_content = Node3D.new()
	_content.name = "GeneratedPreview"
	add_child(_content)
	var camera := Camera3D.new()
	camera.position = Vector3(31, 41, 48)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -20, 0)
	add_child(sun)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.11, 0.15, 0.20)
	world.environment = environment
	add_child(world)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var button := Button.new()
	button.text = "R  Change world seed"
	button.pressed.connect(_change_seed)
	column.add_child(button)
	_status = Label.new()
	column.add_child(_status)
	_rebuild()

func _build_composer() -> NucleusBiomeComposer3D:
	var result := NucleusBiomeComposer3D.new()
	var climate := FastNoiseLite.new()
	climate.seed = _seed
	climate.frequency = 0.025
	result.moisture_noise = climate
	result.base_moisture = 0.5
	result.moisture_amplitude = 0.5
	for entry: Dictionary in [
		{"id": &"arid", "range": Vector2(0.0, 0.35)},
		{"id": &"grassland", "range": Vector2(0.35, 0.65)},
		{"id": &"forest", "range": Vector2(0.65, 1.0)},
	]:
		var biome := NucleusBiomeProfile3D.new()
		biome.biome_id = entry["id"]
		biome.moisture_range = entry["range"]
		result.biomes.append(biome)
	return result

func _build_recipe() -> NucleusPOIDistributionProfile3D:
	var result := NucleusPOIDistributionProfile3D.new()
	result.seed = _seed
	result.grid_spacing = 11.0
	result.density = 0.75
	result.minimum_separation = 8.0
	result.max_cells_per_region = 1024
	for id in [&"camp", &"ruin"]:
		var kind := NucleusPOIType3D.new()
		kind.poi_id = id
		result.types.append(kind)
	return result

func _change_seed() -> void:
	_seed += 1
	composer.moisture_noise.seed = _seed
	recipe.seed = _seed
	_rebuild()

func _surface(_xz: Vector2) -> Dictionary:
	return {"height": 0.0, "slope": 0.0}

func _rebuild() -> void:
	for child: Node in _content.get_children():
		child.queue_free()
	var biome_count: Dictionary = {}
	for z in range(-EXTENT, EXTENT + 1):
		for x in range(-EXTENT, EXTENT + 1):
			var position := Vector2(float(x), float(z)) * SPACING
			var result: Dictionary = composer.resolve_at(position, 0.0, 0.0)
			if result.is_empty():
				continue
			var id: StringName = result["biome_id"]
			biome_count[id] = int(biome_count.get(id, 0)) + 1
			var tile := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(SPACING * 0.96, 0.24, SPACING * 0.96)
			tile.mesh = box
			var material := StandardMaterial3D.new()
			match id:
				&"arid":
					material.albedo_color = Color(0.82, 0.66, 0.38)
				&"grassland":
					material.albedo_color = Color(0.34, 0.62, 0.35)
				_:
					material.albedo_color = Color(0.17, 0.40, 0.31)
			tile.material_override = material
			tile.position = Vector3(position.x, 0, position.y)
			_content.add_child(tile)
	var extent: float = float(EXTENT) * SPACING + SPACING * 0.5
	var plan: Dictionary = NucleusPOIPlanner3D.plan(
		Vector2(-extent, -extent),
		Vector2(extent * 2.0, extent * 2.0),
		recipe, composer, _surface
	)
	if plan["error"] != OK:
		_status.text = "POI generation error: " + error_string(plan["error"])
		return
	for item: Dictionary in plan["points"]:
		var marker := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.5
		cylinder.bottom_radius = 0.7
		cylinder.height = 2.0
		marker.mesh = cylinder
		var material := StandardMaterial3D.new()
		material.albedo_color = (
			Color(0.98, 0.30, 0.26)
			if item["poi_id"] == &"camp" else Color(0.48, 0.59, 0.95)
		)
		marker.material_override = material
		marker.position = item["position"] + Vector3.UP
		_content.add_child(marker)
	_status.text = "Seed %d · POIs %d · 3 biome types" % [
		_seed, (plan["points"] as Array).size()
	]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_change_seed()
