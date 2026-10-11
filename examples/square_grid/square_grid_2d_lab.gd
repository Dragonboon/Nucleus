extends Node2D
## Example-only world authoring: grid tiles and auto-neighbor classification.
var board: NucleusSquareBoard2D
var status: Label
var isometric := false
var _rules := NucleusModularRuleSet.new()

func _ready() -> void:
	board = NucleusSquareBoard2D.new()
	board.name = "SquareBoard2D"
	board.position = Vector2(590, 330)
	add_child(board)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(280, 160)
	layer.add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	var title := Label.new()
	title.text = "SQUARE GRID 2D · NUCLEUS"
	col.add_child(title)
	var toggle := CheckButton.new()
	toggle.text = "Isometric projection"
	toggle.toggled.connect(func(enabled: bool) -> void:
		isometric = enabled
		board.isometric = enabled
		board.queue_redraw()
	)
	col.add_child(toggle)
	var clear := Button.new()
	clear.text = "Clear all"
	clear.pressed.connect(func() -> void: board.clear_tiles(); _refresh())
	col.add_child(clear)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var cell := board.world_to_cell(get_global_mouse_position())
		if not board.is_valid_cell(cell):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			board.paint_cell(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			board.erase_cell(cell)
		else:
			return
		_refresh()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			var cell := board.world_to_cell(get_global_mouse_position())
			board.rotate_tile(cell)
			_refresh()

func _refresh() -> void:
	if status == null:
		return
	var total: int = 0
	for cell: Vector2i in board.painted_cells():
		var mask := NucleusModularRuleSet.neighbor_mask(cell, board.has_tile)
		total += mask
	status.text = "Left click: paint | Right click: erase | R: rotate\n"
	status.text += "Occupied: %d · shared corners: %d · connection score: %d" % [
		board.tile_count(), board.shared_corner_count(), total]
