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
var _controls: VBoxContainer
var _tools_button: Button

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
	camera.position = Vector3(0, 21, 26)
	add_child(camera)
	camera.look_at(Vector3(-1, 0, 0))
	camera.fov = 64.0
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
	road.profile.roadbed_enabled = true
	road.auto_build_on_ready = false
	add_child(road)

	# Compact viewport HUD: collapsed by default so the editable road stays visible.
	var layer := CanvasLayer.new()
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.name = "SplineControlsPanel"
	layer.add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var heading := Label.new()
	heading.text = "SPLINE PATHS"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_tools_button = Button.new()
	_tools_button.name = "SplineToolsButton"
	_tools_button.text = "Tools (H) +"
	_tools_button.pressed.connect(_toggle_controls)
	header.add_child(_tools_button)

	status = Label.new()
	status.name = "SplineCompactStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)

	_controls = VBoxContainer.new()
	_controls.name = "SplineAdvancedControls"
	_controls.visible = false
	column.add_child(_controls)
	var shapes := HBoxContainer.new()
	_controls.add_child(shapes)
	_button(shapes, "1 Straight", func() -> void: _set_curved(false))
	_button(shapes, "2 Curved", func() -> void: _set_curved(true))
	var widths := HBoxContainer.new()
	_controls.add_child(widths)
	_button(widths, "Q Narrow", func() -> void: _change_width(-0.5))
	_button(widths, "R Widen", func() -> void: _change_width(0.5))
	_button(_controls, "T Follow surface", _toggle_follow)
	_button(_controls, "B Toggle roadbed", _toggle_roadbed)
	var elevation := HBoxContainer.new()
	_controls.add_child(elevation)
	_button(elevation, "+ Raise point", func() -> void: _raise_point(0.5))
	_button(elevation, "- Lower point", func() -> void: _raise_point(-0.5))
	var instructions := Label.new()
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.text = "Click / drag points · Shift+click to add"
	instructions.text += "\nRight click to remove · +/- for elevation"
	_controls.add_child(instructions)

	get_viewport().size_changed.connect(_layout_controls)
	_layout_controls()
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
	status.text = "%.1fm wide · %d points · %s" % [
		road.profile.width, road.path.curve.point_count,
		"roadbed" if road.profile.roadbed_enabled else "flat",
	]
	if _controls.visible:
		status.text += "\n%s · %s · selected: %d" % [
			"Curved" if curved else "Straight",
			"Surface" if follow_surface else "Free",
			_selected + 1,
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
		if not click.pressed or _pointer_on_ui(click.position):
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
		KEY_H:
			_toggle_controls()
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

## Only the compact panel intercepts mouse input, never the CanvasLayer.
func _pointer_on_ui(screen_position: Vector2) -> bool:
	return _panel != null and _panel.get_global_rect().has_point(screen_position)


func _layout_controls() -> void:
	if _panel == null:
		return
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var panel_width: float = clampf(viewport_width * 0.31, 190.0, 290.0)
	_panel.custom_minimum_size.x = panel_width
	_panel.size.x = panel_width
	_panel.position = Vector2(maxf(8.0, viewport_width - panel_width - 12.0), 12.0)


func _toggle_controls() -> void:
	_controls.visible = not _controls.visible
	_tools_button.text = "Hide (H) -" if _controls.visible else "Tools (H) +"
	_panel.reset_size()
	_layout_controls()
	_rebuild()


func _button(parent: Control, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	button.pressed.connect(action)
