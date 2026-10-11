extends Node3D
## Example-only authoring controls; the reusable board owns visuals and cells.

var board: NucleusSquareBoard3D
var camera: Camera3D
var status: Label
var _hover: Vector3i
var _hover_valid: bool = false
var _panel: PanelContainer

func _ready() -> void:
	board = NucleusSquareBoard3D.new()
	board.name = "SquareBoard3D"
	add_child(board)
	camera = Camera3D.new()
	camera.position = Vector3(15, 20, 23)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -20, 0)
	add_child(light)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.08, 0.12, 0.17)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.65, 0.75, 0.85)
	environment.environment = settings
	add_child(environment)
	_build_ui()
	_refresh()

func _process(_delta: float) -> void:
	var valid_before: bool = _hover_valid
	var cell_before: Vector3i = _hover
	_hover_valid = false
	if not _pointer_on_ui():
		var hit: Dictionary = board.intersect_cursor(
			camera, get_viewport().get_mouse_position(), board.active_layer
		)
		if not hit.is_empty():
			_hover = hit["cell"]
			_hover_valid = true
	board.set_hover(_hover, _hover_valid)
	if valid_before != _hover_valid or cell_before != _hover:
		_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse := event as InputEventMouseButton
		if not _hover_valid or _pointer_on_ui():
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.shift_pressed:
				_select(_hover)
			else:
				board.paint_cell(_hover)
		elif mouse.button_index == MOUSE_BUTTON_RIGHT:
			board.erase_cell(_hover)
		else:
			return
		_refresh()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_Z:
				_change_layer(-1)
			KEY_X:
				_change_layer(1)
			KEY_Q:
				_rotate(-1)
			KEY_R:
				_rotate(1)
			KEY_C:
				board.clear_tiles()
			KEY_ESCAPE:
				board.highlight_selection(Vector3i.ZERO, false)
		_refresh()

func _change_layer(delta: int) -> void:
	board.set_active_layer(board.active_layer + delta)
	# Keep higher/lower active planes inside the camera view.
	camera.position.y = 20.0 + float(board.active_layer) * board.layer_step
	camera.look_at(Vector3.UP * float(board.active_layer) * board.layer_step)
	_hover_valid = false
	board.set_hover(Vector3i.ZERO, false)
	_refresh()

func _select(cell: Vector3i) -> void:
	board.highlight_selection(cell)
	_refresh()

func _rotate(direction: int) -> void:
	if board.has_selection():
		board.rotate_tile(board.get_selected_cell(), direction)
	_refresh()

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_panel = PanelContainer.new()
	_panel.position = Vector2(16, 16)
	_panel.custom_minimum_size = Vector2(318, 0)
	canvas.add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	var header := Label.new()
	header.text = "SQUARE GRID 3D · NUCLEUS"
	column.add_child(header)
	var hints := Label.new()
	hints.text = "Left: paint · Right: erase · Shift+click: select"
	column.add_child(hints)
	var rotations := HBoxContainer.new()
	column.add_child(rotations)
	_button(rotations, "Q  ↶ 90°", func() -> void: _rotate(-1))
	_button(rotations, "R  ↷ 90°", func() -> void: _rotate(1))
	var layers := HBoxContainer.new()
	column.add_child(layers)
	_button(layers, "Z  Layer −", func() -> void: _change_layer(-1))
	_button(layers, "X  Layer +", func() -> void: _change_layer(1))
	var ghost := CheckButton.new()
	ghost.text = "Ghost grid"
	ghost.button_pressed = board.show_ghost
	ghost.toggled.connect(board.set_ghost_visible)
	column.add_child(ghost)
	var orientation := CheckButton.new()
	orientation.text = "Selected tile direction"
	orientation.button_pressed = board.show_selected_orientation
	orientation.toggled.connect(board.set_show_selected_orientation)
	column.add_child(orientation)
	_button(column, "C  Clear tiles", func() -> void:
		board.clear_tiles()
		_refresh()
	)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = "Esc: deselect · Shift+left click: select tile\n"
	help.text += "Z/X: lower/higher layer · Q/R: rotate selected tile"
	column.add_child(help)

func _button(parent: Node, label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	button.pressed.connect(action)

func _pointer_on_ui() -> bool:
	return _panel != null and _panel.get_global_rect().has_point(
		get_viewport().get_mouse_position()
	)

func _refresh() -> void:
	if status == null:
		return
	status.text = "Tiles: %d · Active layer: %d" % [
		board.tile_count(), board.active_layer
	]
	if board.has_selection():
		var cell: Vector3i = board.get_selected_cell()
		status.text += "\nSelected: %s · Orientation: %d°" % [
			str(cell), board.get_rotation_steps(cell) * 90
		]
