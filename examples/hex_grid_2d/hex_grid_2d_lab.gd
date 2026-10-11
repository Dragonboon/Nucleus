extends Node2D
## Small 2D proof of the shared grid contract. Input and visual UX are lab-owned.

var board: NucleusHexBoard2D
var _camera: Camera2D
var _tool: String = "paint"
var _selected: Vector2i = Vector2i.ZERO
var _has_selection: bool = false
var _move_source: Vector2i = Vector2i.ZERO
var _moving: bool = false
var _path_source: Vector2i = Vector2i.ZERO
var _finding_path: bool = false
var _path_line: Line2D
var _dragging: bool = false
var _panning: bool = false
var _last_cell: Vector2i = Vector2i.ZERO
var _panel: Control
var _status: Label
var _log: Label
var _recent: Array[String] = []


func _ready() -> void:
	board = NucleusHexBoard2D.new()
	board.name = "HexBoard2D"
	add_child(board)
	board.tile_painted.connect(func(cell: Vector2i) -> void: _event("PAINT " + str(cell)))
	board.tile_erased.connect(func(cell: Vector2i) -> void: _event("ERASE " + str(cell)))
	board.edge_connected.connect(_on_edge_connected)
	board.corner_connected.connect(_on_corner_connected)
	_camera = Camera2D.new()
	_camera.name = "MapCamera"
	_camera.position = Vector2(-145.0, 0.0)
	add_child(_camera)
	_camera.make_current()
	_path_line = Line2D.new()
	_path_line.width = 4.0
	_path_line.default_color = Color(1.0, 0.54, 0.17)
	_path_line.z_index = 10
	board.add_child(_path_line)
	_build_ui()
	_refresh()


func _process(_delta: float) -> void:
	if board == null:
		return
	var hover: Vector2i = board.world_to_cell(get_global_mouse_position())
	var on_grid: bool = board.is_valid_cell(hover) and not _pointer_on_ui()
	board.set_hover(hover, on_grid)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dragging = false
	if _tool != "paint" or not _dragging or not on_grid:
		return
	for cell: Vector2i in NucleusHexLayout.line(_last_cell, hover):
		board.paint_cell(cell)
	_last_cell = hover
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mouse.pressed
			return
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom = (_camera.zoom * 1.12).clamp(Vector2(0.35, 0.35), Vector2(3, 3))
			return
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom = (_camera.zoom / 1.12).clamp(Vector2(0.35, 0.35), Vector2(3, 3))
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if not mouse.pressed:
				_dragging = false
				return
			if _pointer_on_ui():
				return
			var cell: Vector2i = board.world_to_cell(get_global_mouse_position())
			if not board.is_valid_cell(cell):
				return
			if mouse.shift_pressed:
				_select(cell)
			else:
				_click(cell)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _panning:
		var motion := event as InputEventMouseMotion
		_camera.position -= motion.relative / _camera.zoom
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_P:
				_tool = "paint"
			KEY_X:
				_tool = "erase"
			KEY_I:
				_tool = "select"
			KEY_M:
				_tool = "move"
				_moving = false
			KEY_T:
				_tool = "path"
				_finding_path = false
			KEY_Q:
				_rotate_selected(-1)
			KEY_R:
				_rotate_selected(1)
			KEY_BRACKETLEFT:
				board.rotation -= PI / 3.0
			KEY_BRACKETRIGHT:
				board.rotation += PI / 3.0
			KEY_ESCAPE:
				_moving = false
				_finding_path = false
				_has_selection = false
				board.highlight_selection(Vector2i.ZERO, false)
				_path_line.clear_points()
			KEY_DELETE:
				if _has_selection:
					board.erase_cell(_selected)
					_has_selection = false
		_refresh()


func _click(cell: Vector2i) -> void:
	match _tool:
		"paint":
			board.paint_cell(cell)
			_dragging = true
			_last_cell = cell
		"erase":
			board.erase_cell(cell)
		"select":
			_select(cell)
		"move":
			if not _moving:
				if board.has_tile(cell):
					_move_source = cell
					_moving = true
					_select(cell)
			elif board.move_tile(_move_source, cell):
				_selected = cell
				_moving = false
		"path":
			if not board.has_tile(cell):
				return
			if not _finding_path:
				_path_source = cell
				_finding_path = true
			else:
				_finding_path = false
				var path: Array[Vector2i] = NucleusHexLayout.shortest_path(
					_path_source, cell, func(candidate: Vector2i) -> bool:
						return board.has_tile(candidate),
				)
				_path_line.clear_points()
				for step: Vector2i in path:
					_path_line.add_point(NucleusHexLayout.axial_to_pixel(
						step, board.cell_radius, board.flat_top,
					))
				_event("PATH %d cells" % path.size())
	_refresh()


func _select(cell: Vector2i) -> void:
	_has_selection = board.has_tile(cell)
	if _has_selection:
		_selected = cell
	board.highlight_selection(cell, _has_selection)
	_refresh()


func _set_tool(tool: String) -> void:
	_tool = tool
	_moving = false
	_finding_path = false
	_dragging = false
	_refresh()


func _rotate_selected(delta: int) -> void:
	if _has_selection:
		board.rotate_tile(_selected, delta)
	_refresh()


func _adjust(setting: String, amount: float) -> void:
	match setting:
		"radius":
			board.set_cell_radius(board.cell_radius + amount)
		"rings":
			board.set_ring_count(board.ring_count + roundi(amount))
		"rotation":
			board.rotation += amount
		"move_x":
			board.position.x += amount * board.cell_radius
		"move_y":
			board.position.y += amount * board.cell_radius
	_path_line.clear_points()
	_refresh()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var scroll := ScrollContainer.new()
	scroll.offset_left = 12
	scroll.offset_top = 12
	scroll.offset_right = 318
	scroll.offset_bottom = -12
	scroll.anchor_bottom = 1.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(scroll)
	_panel = scroll
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 285
	scroll.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	var title := Label.new()
	title.text = "HEX GRID 2D · NUCLEUS"
	column.add_child(title)
	var tools := HBoxContainer.new()
	column.add_child(tools)
	_button(tools, "P Pintar", Callable(self, "_set_tool").bind("paint"))
	_button(tools, "X Borrar", Callable(self, "_set_tool").bind("erase"))
	var more := HBoxContainer.new()
	column.add_child(more)
	_button(more, "I Sel.", Callable(self, "_set_tool").bind("select"))
	_button(more, "M Mover", Callable(self, "_set_tool").bind("move"))
	_button(more, "T Ruta", Callable(self, "_set_tool").bind("path"))
	for settings: Array in [
		["Radio", "radius", 3.0],
		["Anillos", "rings", 1.0],
		["Giro tablero", "rotation", PI / 3.0],
		["Mover X", "move_x", 1.0],
		["Mover Y", "move_y", 1.0],
	]:
		var row := HBoxContainer.new()
		column.add_child(row)
		var label := Label.new()
		label.text = String(settings[0])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_button(row, "−", Callable(self, "_adjust").bind(
			String(settings[1]), -float(settings[2]),
		))
		_button(row, "+", Callable(self, "_adjust").bind(
			String(settings[1]), float(settings[2]),
		))
	var rotate_row := HBoxContainer.new()
	column.add_child(rotate_row)
	_button(rotate_row, "Pieza −60°", func() -> void: _rotate_selected(-1))
	_button(rotate_row, "Pieza +60°", func() -> void: _rotate_selected(1))
	var flat := CheckBox.new()
	flat.text = "Orientación flat-top"
	flat.toggled.connect(func(value: bool) -> void:
		board.set_flat_top(value)
		_path_line.clear_points()
		_refresh()
	)
	column.add_child(flat)
	var ghost := CheckBox.new()
	ghost.text = "Cuadrícula fantasma"
	ghost.button_pressed = true
	ghost.toggled.connect(func(value: bool) -> void:
		board.show_ghost = value
		board.queue_redraw()
	)
	column.add_child(ghost)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = (
		"P pintar/arrastrar · X borrar · I seleccionar · M mover\n"
		+ "Mayús+clic seleccionar · Q/R girar PIEZA · [/] girar tablero\n"
		+ "T elegir inicio y fin de ruta por celdas pintadas\n"
		+ "Rueda zoom · Ratón central arrastrar mapa · Esc cancelar"
	)
	column.add_child(help)
	_log = Label.new()
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_log)


func _button(parent: Node, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	parent.add_child(button)
	button.pressed.connect(callback)


func _pointer_on_ui() -> bool:
	return _panel != null and _panel.get_global_rect().has_point(
		get_viewport().get_mouse_position()
	)


func _on_edge_connected(cell: Vector2i, side: int, other: Vector2i) -> void:
	_event("EDGE %s[%d] ↔ %s" % [str(cell), side, str(other)])


func _on_corner_connected(
	cell: Vector2i, corner: int, other: Vector2i, other_corner: int, _point: Vector2,
) -> void:
	_event("CORNER %s[%d] ↔ %s[%d]" % [str(cell), corner, str(other), other_corner])


func _event(message: String) -> void:
	_recent.push_front(message)
	if _recent.size() > 4:
		_recent.pop_back()
	_refresh()


func _refresh() -> void:
	if _status == null or _log == null or board == null:
		return
	var info := "Modo: %s | Celdas %d | Contactos %d\n" % [
		_tool, board.tile_count(), board.shared_corner_count(),
	]
	info += "Radio %.1f | Anillos %d | %s" % [
		board.cell_radius, board.ring_count,
		"FLAT" if board.flat_top else "POINTY",
	]
	if _has_selection:
		info += "\nSelección %s | Giro %d°" % [
			str(_selected), board.get_rotation_steps(_selected) * 60,
		]
	_status.text = info
	_log.text = "\n".join(_recent)
