extends Node3D
## Small validation scene: native Path3D, Nucleus road and surface contracts.

var road: NucleusSplineRoad3D
var terrain: NucleusPlaneSurfaceSampler3D
var status: Label
var curved: bool = true
var follow_surface: bool = true
var camera: Camera3D
var _handles: Array[MeshInstance3D] = []
var _selected: int = -1
var _dragging: bool = false
var _panel: PanelContainer

func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.15, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.68, 0.74, 0.80)
	world.environment = env
	add_child(world)
	camera = Camera3D.new()
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
	_panel = PanelContainer.new()
	var panel: PanelContainer = _panel
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
	_button(column, "B Toggle roadbed volume", _toggle_roadbed)
	_button(column, "+ Raise selected point", func() -> void: _raise_point(0.5))
	_button(column, "- Lower selected point", func() -> void: _raise_point(-0.5))
	var instructions := Label.new()
	instructions.text = "Click: select/drag point | Shift+click: add point\\n"
	instructions.text += "Right click: remove selected | +/-: elevation"
	column.add_child(instructions)
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
	_selected = -1
	_rebuild()

func _change_width(delta: float) -> void:
	road.profile.width = clampf(road.profile.width + delta, 0.5, 10.0)
	_rebuild()

func _toggle_follow() -> void:
	follow_surface = not follow_surface
	road.surface_sampler = terrain if follow_surface else null
	_rebuild()

func _rebuild() -> void:
	_update_handles()
	var outcome: Error = road.rebuild()
	if outcome != OK:
		status.text = "Unable to rebuild: " + error_string(outcome)
		return
	status.text = "Width: %.1fm | %s | %s" % [
		road.profile.width,
		"Curved" if curved else "Straight",
		"Terrain surface" if follow_surface else "Elevated/free",
	]
	status.text += "\\nPoints: %d | Selection: %d | Roadbed: %s" % [
		road.path.curve.point_count, _selected + 1,
		"on" if road.profile.roadbed_enabled else "off",
	]

func _toggle_roadbed() -> void:
	road.profile.roadbed_enabled = not road.profile.roadbed_enabled
	_rebuild()


func _raise_point(amount: float) -> void:
	if _selected < 0 or _selected >= road.path.curve.point_count:
		return
	var point: Vector3 = road.path.curve.get_point_position(_selected)
	point.y = clampf(point.y + amount, -8.0, 8.0)
	road.path.curve.set_point_position(_selected, point)
	_rebuild()


func _pick_ground(screen: Vector2, height: float = 0.0) -> Dictionary:
	var ray_origin: Vector3 = camera.project_ray_origin(screen)
	var ray_direction: Vector3 = camera.project_ray_normal(screen)
	var point: Variant = Plane(Vector3.UP, height).intersects_ray(ray_origin, ray_direction)
	if point == null:
		return {}
	return {"position": point}


func _nearest_point(screen: Vector2) -> int:
	var best := -1
	var best_distance := 18.0
	for i in range(road.path.curve.point_count):
		var world: Vector3 = road.path.to_global(road.path.curve.get_point_position(i))
		if camera.is_position_behind(world):
			continue
		var distance: float = camera.unproject_position(world).distance_to(screen)
		if distance < best_distance:
			best = i
			best_distance = distance
	return best


func _edit_point(screen: Vector2) -> void:
	if _selected < 0:
		return
	var old: Vector3 = road.path.curve.get_point_position(_selected)
	var hit: Dictionary = _pick_ground(screen, old.y)
	if hit.is_empty():
		return
	var next: Vector3 = road.path.to_local(hit["position"])
	next.y = old.y
	road.path.curve.set_point_position(_selected, next)
	_rebuild()


func _update_handles() -> void:
	for handle: MeshInstance3D in _handles:
		if is_instance_valid(handle):
			handle.queue_free()
	_handles.clear()
	if road == null or road.path == null:
		return
	for i in range(road.path.curve.point_count):
		var sphere := SphereMesh.new()
		sphere.radius = 0.36 if i == _selected else 0.24
		sphere.height = sphere.radius * 2.0
		var handle := MeshInstance3D.new()
		handle.mesh = sphere
		var paint := StandardMaterial3D.new()
		paint.albedo_color = (
			Color(1.0, 0.78, 0.2) if i == _selected else Color(0.2, 0.83, 0.98)
		)
		handle.material_override = paint
		add_child(handle)
		handle.global_position = road.path.to_global(
			road.path.curve.get_point_position(i)
		)
		_handles.append(handle)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _dragging:
		_edit_point(event.position)
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
			_dragging = false
			return
		if not click.pressed or _panel.get_global_rect().has_point(click.position):
			return
		if click.button_index == MOUSE_BUTTON_LEFT:
			if click.shift_pressed:
				if road.path.curve.point_count >= 24:
					return
				var hit: Dictionary = _pick_ground(click.position)
				if hit.is_empty():
					return
				var next: Vector3 = road.path.to_local(hit["position"])
				road.path.curve.add_point(next)
				_selected = road.path.curve.point_count - 1
			else:
				_selected = _nearest_point(click.position)
				_dragging = _selected >= 0
			_rebuild()
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			var picked: int = _nearest_point(click.position)
			if picked >= 0 and road.path.curve.point_count > 2:
				road.path.curve.remove_point(picked)
				_selected = -1
				_rebuild()
		return
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
		KEY_B:
			_toggle_roadbed()
		KEY_EQUAL, KEY_KP_ADD:
			_raise_point(0.5)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_raise_point(-0.5)

func _button(parent: Control, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	button.pressed.connect(action)
