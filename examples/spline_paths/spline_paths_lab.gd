extends Node3D
## Small validation scene: native Path3D, Nucleus road and surface contracts.

var road: NucleusSplineRoad3D
var terrain: NucleusPlaneSurfaceSampler3D
var status: Label
var curved: bool = true
var follow_surface: bool = true

func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.15, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.68, 0.74, 0.80)
	world.environment = env
	add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(17, 16, 23)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	add_child(sun)

	terrain = NucleusPlaneSurfaceSampler3D.new()
	terrain.name = "NativeSurfaceSampler"
	terrain.rotation_degrees.z = -9.0
	add_child(terrain)
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(32, 30)
	ground.mesh = ground_mesh
	ground.rotation = terrain.rotation
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color(0.18, 0.38, 0.27)
	ground.material_override = earth
	add_child(ground)

	var path := Path3D.new()
	path.name = "EditableCurve"
	path.curve = _create_curve()
	add_child(path)
	var mesh := MeshInstance3D.new()
	mesh.name = "GeneratedRoad"
	var road_material := StandardMaterial3D.new()
	road_material.albedo_color = Color(0.77, 0.65, 0.46)
	road_material.roughness = 0.95
	road_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = road_material
	add_child(mesh)

	road = NucleusSplineRoad3D.new()
	road.name = "SplineRoad"
	road.path = path
	road.target_mesh = mesh
	road.surface_sampler = terrain
	road.profile = NucleusSplinePathProfile3D.new()
	road.profile.width = 3.0
	road.auto_build_on_ready = false
	add_child(road)

	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(290, 0)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "SPLINE ROADS · NUCLEUS"
	column.add_child(heading)
	var shapes := HBoxContainer.new()
	column.add_child(shapes)
	_button(shapes, "1 Straight", func() -> void: _set_curved(false))
	_button(shapes, "2 Curved", func() -> void: _set_curved(true))
	var widths := HBoxContainer.new()
	column.add_child(widths)
	_button(widths, "Q Narrow", func() -> void: _change_width(-0.5))
	_button(widths, "R Widen", func() -> void: _change_width(0.5))
	_button(column, "T Toggle terrain following", _toggle_follow)
	status = Label.new()
	column.add_child(status)
	_rebuild()

func _create_curve() -> Curve3D:
	var curve := Curve3D.new()
	var points: Array = (
		[Vector3(-10, 0, -4), Vector3(-2, 0, 6),
			Vector3(4, 0, -3), Vector3(10, 0, 4)]
		if curved else
		[Vector3(-10, 0, 0), Vector3(10, 0, 0)]
	)
	for point in points:
		curve.add_point(point)
	if curved:
		for i in range(curve.point_count):
			var before: Vector3 = curve.get_point_position(maxi(i - 1, 0))
			var after: Vector3 = curve.get_point_position(
				mini(i + 1, curve.point_count - 1)
			)
			var handle: Vector3 = (after - before) * 0.19
			curve.set_point_in(i, -handle)
			curve.set_point_out(i, handle)
	return curve

func _set_curved(value: bool) -> void:
	curved = value
	road.path.curve = _create_curve()
	_rebuild()

func _change_width(delta: float) -> void:
	road.profile.width = clampf(road.profile.width + delta, 0.5, 10.0)
	_rebuild()

func _toggle_follow() -> void:
	follow_surface = not follow_surface
	road.surface_sampler = terrain if follow_surface else null
	_rebuild()

func _rebuild() -> void:
	var outcome: Error = road.rebuild()
	if outcome != OK:
		status.text = "Unable to rebuild: " + error_string(outcome)
		return
	status.text = "Width: %.1fm | %s | %s" % [
		road.profile.width,
		"Curved" if curved else "Straight",
		"Terrain surface" if follow_surface else "Elevated/free",
	]

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_set_curved(false)
		KEY_2:
			_set_curved(true)
		KEY_Q:
			_change_width(-0.5)
		KEY_R:
			_change_width(0.5)
		KEY_T:
			_toggle_follow()

func _button(parent: Control, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	button.pressed.connect(action)
