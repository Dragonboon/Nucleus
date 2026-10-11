extends Node3D
## Example-only painted grid. Native camera ray -> a reference XZ plane.
var board: NucleusSquareBoard3D
var camera: Camera3D
var status: Label
var _rules := NucleusModularRuleSet.new()

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
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 17)
	layer.add_child(label)
	status = label
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var hit := board.intersect_cursor(
			camera, get_viewport().get_mouse_position(), board.active_layer)
		if hit.is_empty():
			return
		var cell: Vector3i = hit["cell"]
		if event.button_index == MOUSE_BUTTON_LEFT:
			board.paint_cell(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			board.erase_cell(cell)
		_refresh()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_PAGEUP:
			board.active_layer = mini(8, board.active_layer + 1)
		elif event.keycode == KEY_PAGEDOWN:
			board.active_layer = maxi(-8, board.active_layer - 1)
		elif event.keycode == KEY_C:
			board.clear_tiles()
		_refresh()

func _refresh() -> void:
	if status != null:
		status.text = "SQUARE GRID 3D · NUCLEUS\n"
		status.text += "Left: paint | Right: erase | PageUp/Down: layer | C: clear\n"
		status.text += "Painted: %d · Active layer: %d" % [
			board.tile_count(), board.active_layer]
