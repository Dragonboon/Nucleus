extends Node3D
## Minimal runtime authoring laboratory. No input map, plugin or Autoload required.
## Cells are native MeshInstance3D nodes owned by a NucleusHexBoard3D.

var board: NucleusHexBoard3D
var _camera: Camera3D
var _tool: String = "paint"
var _hover_cell: Vector3i = Vector3i.ZERO
var _hover_valid: bool = false
var _selected: Vector3i = Vector3i.ZERO
var _has_selection: bool = false
var _move_source: Vector3i = Vector3i.ZERO
var _moving: bool = false
var _orbiting: bool = false
var _painting_stroke: bool = false
var _last_stroke_cell: Vector3i = Vector3i.ZERO
var _camera_yaw: float = 0.56
var _camera_pitch: float = 0.87
var _camera_distance: float = 28.0
var _panel: Control
var _status: Label
var _details: Label
var _events: Label
var _recent_events: Array[String] = []


func _ready() -> void:
	_make_environment()
	board = NucleusHexBoard3D.new()
	board.name = "HexBoard"
	add_child(board)
	board.corner_connected.connect(_on_corner_connected)
	board.corner_disconnected.connect(_on_corner_disconnected)
	board.tile_painted.connect(_on_tile_changed)
	board.tile_erased.connect(_on_tile_erased)
	board.tile_moved.connect(_on_tile_moved)
	_camera = Camera3D.new()
	_camera.name = "OrbitCamera"
	_camera.current = true
	_camera.fov = 55.0
	add_child(_camera)
	_refresh_camera()
	_make_ui()
	_sync_ui()


func _make_environment() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "ReferenceGround_NoCollision"
	var plane := PlaneMesh.new()
	plane.size = Vector2(100, 100)
	ground.mesh = plane
	ground.position.y = -0.10
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.23, 0.27)
	ground.material_override = material
	add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 24, 0)
	sun.light_energy = 1.3
	add_child(sun)
	var ambient := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.075, 0.11, 0.15)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.63, 0.70, 0.79)
	environment.ambient_light_energy = 0.65
	ambient.environment = environment
	add_child(ambient)


func _process(_delta: float) -> void:
	if not is_instance_valid(board) or not is_instance_valid(_camera):
		return
	var previous_hover_valid: bool = _hover_valid
	var previous_hover_cell: Vector3i = _hover_cell
	_hover_valid = false
	if not _is_pointer_on_ui():
		var hit: Dictionary = board.intersect_cursor(
			_camera, get_viewport().get_mouse_position(), board.active_layer,
		)
		if not hit.is_empty():
			_hover_cell = hit["cell"]
			_hover_valid = true
	board.set_hover(_hover_cell, _hover_valid)
	if _tool == "paint" and _hover_valid and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not _painting_stroke or _last_stroke_cell.z != _hover_cell.z:
			_painting_stroke = true
			_last_stroke_cell = _hover_cell
		for cell_2d: Vector2i in NucleusHexLayout3D.stroke_cells(
			Vector2i(_last_stroke_cell.x, _last_stroke_cell.y),
			Vector2i(_hover_cell.x, _hover_cell.y),
		):
			board.paint_cell(Vector3i(cell_2d.x, cell_2d.y, _hover_cell.z))
		_last_stroke_cell = _hover_cell
	else:
		_painting_stroke = false
	if _hover_valid != previous_hover_valid or _hover_cell != previous_hover_cell:
		_sync_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = mouse.pressed
			get_viewport().set_input_as_handled()
			return
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(7.0, _camera_distance - 2.0)
			_refresh_camera()
			return
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(65.0, _camera_distance + 2.0)
			_refresh_camera()
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed and _hover_valid:
			_click_cell(_hover_cell)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _orbiting:
		var motion := event as InputEventMouseMotion
		_camera_yaw -= motion.relative.x * 0.006
		_camera_pitch = clampf(_camera_pitch - motion.relative.y * 0.006, 0.22, 1.48)
		_refresh_camera()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_P:
				_set_tool("paint")
			KEY_X:
				_set_tool("erase")
			KEY_M:
				_set_tool("move")
			KEY_I:
				_set_tool("select")
			KEY_Q:
				_rotate_selected(-1)
			KEY_R:
				_rotate_selected(1)
			KEY_BRACKETLEFT:
				board.rotation.y -= PI / 3.0
			KEY_BRACKETRIGHT:
				board.rotation.y += PI / 3.0
			KEY_UP:
				board.position.z -= board.cell_radius
			KEY_DOWN:
				board.position.z += board.cell_radius
			KEY_LEFT:
				board.position.x -= board.cell_radius
			KEY_RIGHT:
				board.position.x += board.cell_radius
			KEY_ESCAPE:
				_moving = false
				_has_selection = false
				board.highlight_selection(Vector3i.ZERO, false)
			KEY_DELETE:
				if _has_selection and board.erase_cell(_selected):
						_has_selection = false
			KEY_PAGEUP:
				board.set_active_layer(board.active_layer + 1)
			KEY_PAGEDOWN:
				board.set_active_layer(board.active_layer - 1)
		_refresh_camera()
		_sync_ui()


func _click_cell(cell: Vector3i) -> void:
	match _tool:
		"paint":
			board.paint_cell(cell)
		"erase":
			if board.erase_cell(cell) and _has_selection and _selected == cell:
				_has_selection = false
		"select":
			_has_selection = board.has_tile(cell)
			board.highlight_selection(cell, _has_selection)
			if _has_selection:
				_selected = cell
		"move":
			if not _moving:
				if board.has_tile(cell):
					_move_source = cell
					_moving = true
					_selected = cell
					_has_selection = true
					board.highlight_selection(cell)
			else:
				if board.move_tile(_move_source, cell):
					_selected = cell
					_moving = false


func _set_tool(name: String) -> void:
	_painting_stroke = false
	_tool = name
	_moving = false
	_sync_ui()


func _rotate_selected(delta_steps: int) -> void:
	if _has_selection:
		board.rotate_tile(_selected, delta_steps)


func _refresh_camera() -> void:
	if _camera == null or board == null:
		return
	var center: Vector3 = board.global_position
	var offset := Vector3(
		sin(_camera_yaw) * cos(_camera_pitch),
		sin(_camera_pitch),
		cos(_camera_yaw) * cos(_camera_pitch),
	) * _camera_distance
	_camera.global_position = center + offset
	_camera.look_at(center, Vector3.UP)


func _on_corner_connected(
	cell: Vector3i, corner: int, other: Vector3i, other_corner: int, _point: Vector3,
) -> void:
	_add_event("CONNECT %s[%d] ↔ %s[%d]" % [str(cell), corner, str(other), other_corner])


func _on_corner_disconnected(
	cell: Vector3i, corner: int, other: Vector3i, other_corner: int, _point: Vector3,
) -> void:
	_add_event("DISCONNECT %s[%d] ↔ %s[%d]" % [str(cell), corner, str(other), other_corner])


func _on_tile_changed(cell: Vector3i, _tile: Node3D) -> void:
	_add_event("PAINT " + str(cell))


func _on_tile_erased(cell: Vector3i) -> void:
	_add_event("ERASE " + str(cell))


func _on_tile_moved(from_cell: Vector3i, to_cell: Vector3i) -> void:
	_add_event("MOVE %s → %s" % [str(from_cell), str(to_cell)])


func _add_event(message: String) -> void:
	_recent_events.push_front(message)
	if _recent_events.size() > 5:
		_recent_events.pop_back()
	_sync_ui()


func _is_pointer_on_ui() -> bool:
	return _panel != null and _panel.get_global_rect().has_point(get_viewport().get_mouse_position())


func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var scroll := ScrollContainer.new()
	scroll.name = "HexTools"
	scroll.offset_left = 15
	scroll.offset_top = 15
	scroll.offset_right = 352
	scroll.offset_bottom = -15
	scroll.anchor_bottom = 1.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(scroll)
	_panel = scroll
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 320
	scroll.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	var title := Label.new()
	title.text = "HEX GRID · NUCLEUS LAB"
	title.add_theme_font_size_override("font_size", 19)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = (
		"Cuadrícula fantasma y construcción axial.\n"
		+ "Clic/arrastrar para pintar, X borrar, M mover, I seleccionar."
	)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)
	var toolbar := HBoxContainer.new()
	column.add_child(toolbar)
	_button(toolbar, "P Pintar", func() -> void: _set_tool("paint"))
	_button(toolbar, "X Borrar", func() -> void: _set_tool("erase"))
	var toolbar2 := HBoxContainer.new()
	column.add_child(toolbar2)
	_button(toolbar2, "M Mover", func() -> void: _set_tool("move"))
	_button(toolbar2, "I Selección", func() -> void: _set_tool("select"))
	_details = Label.new()
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_details)
	for setting: Array in [
		["Radio hex", "radius", 0.25],
		["Anillos", "rings", 1.0],
		["Altura tile", "height", 0.1],
		["Altura capa", "layer_step", 0.25],
		["Capa activa", "active_layer", 1.0],
		["Girar grid 60°", "rotate", PI / 3.0],
		["Desplazar X", "move_x", 1.0],
		["Desplazar Z", "move_z", 1.0],
	]:
		_setting_row(
			column, String(setting[0]),
			Callable(self, "_adjust").bind(String(setting[1]), -float(setting[2])),
			Callable(self, "_adjust").bind(String(setting[1]), float(setting[2])),
		)
	var visibility := CheckBox.new()
	visibility.text = "Cuadrícula fantasma"
	visibility.button_pressed = true
	visibility.toggled.connect(func(active: bool) -> void: board.set_ghost_visible(active))
	column.add_child(visibility)
	_button(column, "Vaciar celdas", func() -> void: _clear_board())
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = (
		"Q/R rotar tile seleccionado · Supr borrar\n"
		+ "[ / ] girar grid · Flechas mover grid\n"
		+ "RePág/AvPág: capas · Botón derecho: orbitar · Rueda: zoom\n"
		+ "M: clic origen → clic destino · Esc: cancelar mover"
	)
	column.add_child(help)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var event_title := Label.new()
	event_title.text = "EVENTOS DE VÉRTICES"
	column.add_child(event_title)
	_events = Label.new()
	_events.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_events)


func _adjust(setting: String, delta: float) -> void:
	match setting:
		"radius":
			board.set_cell_radius(board.cell_radius + delta)
		"rings":
			board.set_ring_count(board.ring_count + roundi(delta))
		"height":
			board.set_tile_height(board.tile_height + delta)
		"layer_step":
			board.set_layer_step(board.layer_step + delta)
		"active_layer":
			board.set_active_layer(board.active_layer + roundi(delta))
		"rotate":
			board.rotation.y += delta
		"move_x":
			board.position.x += delta * board.cell_radius
		"move_z":
			board.position.z += delta * board.cell_radius
	_refresh_camera()
	_sync_ui()


func _clear_board() -> void:
	board.highlight_selection(Vector3i.ZERO, false)
	board.clear_tiles()
	_has_selection = false
	_moving = false


func _setting_row(parent: VBoxContainer, name: String, minus: Callable, plus: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_button(row, "−", minus)
	_button(row, "+", plus)


func _button(parent: Node, label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	parent.add_child(button)


func _sync_ui() -> void:
	if _details == null or _status == null or _events == null or board == null:
		return
	_details.text = (
		"Radio %.2f m | Anillos %d | Altura %.2f m\n"
		+ "Paso vertical %.2f m | Capa %d | Giro %.0f°"
	) % [
		board.cell_radius, board.ring_count, board.tile_height,
		board.layer_step, board.active_layer, rad_to_deg(board.rotation.y),
	]
	var info := "Tool: %s | Piezas: %d | Contactos de esquina: %d" % [
		_tool.to_upper(), board.tile_count(), board.shared_corner_count(),
	]
	if _hover_valid:
		info += "\nCursor: " + str(_hover_cell)
	if _has_selection:
		info += "\nSeleccionada: " + str(_selected)
	if _moving:
		info += "\nDestino: clic en una celda vacía"
	_status.text = info
	_events.text = (
		"\n".join(_recent_events)
		if not _recent_events.is_empty()
		else "Pinta dos hexágonos vecinos para generar conexiones."
	)
