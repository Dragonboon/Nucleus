extends Node3D
## Validation-only modular assembly: logical occupancy -> rules -> visual presenter.

var board: NucleusSquareBoard3D
var binding: NucleusModularVariantBinding3D
var rules: NucleusModularRuleSet
var camera: Camera3D
var status: Label
var _hover: Vector3i
var _hover_valid := false
var _panel: PanelContainer


func _ready() -> void:
	board = NucleusSquareBoard3D.new()
	board.name = "SquareBoard3D"
	board.half_extent = 6
	board.show_ghost = true
	add_child(board)
	rules = _build_rules()
	binding = NucleusModularVariantBinding3D.new()
	binding.name = "ModularPresenter"
	binding.square_board = board
	binding.catalog = _build_catalog()
	add_child(binding)
	board.tile_painted.connect(func(cell: Vector3i) -> void: _update_neighbors(cell))
	board.tile_erased.connect(func(cell: Vector3i) -> void: _update_neighbors(cell))
	camera = Camera3D.new()
	camera.position = Vector3(14, 20, 22)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -20, 0)
	add_child(light)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_panel = PanelContainer.new()
	_panel.position = Vector2(16, 16)
	_panel.custom_minimum_size = Vector2(300, 0)
	canvas.add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	var header := Label.new()
	header.text = "MODULAR BUILDING · NUCLEUS"
	column.add_child(header)
	var help := Label.new()
	help.text = "Left: add · Right: remove\nZ/X: change layer · C: clear"
	column.add_child(help)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_button(buttons, "Z  Lower", func() -> void: _change_layer(-1))
	_button(buttons, "X  Higher", func() -> void: _change_layer(1))
	_button(column, "C  Clear all", _clear)
	status = Label.new()
	column.add_child(status)
	_refresh()


func _build_rules() -> NucleusModularRuleSet:
	var set := NucleusModularRuleSet.new()
	set.fallback_variant = &"isolated"
	for definition in [
		[1, &"end"], [5, &"straight"], [3, &"corner"],
		[7, &"junction"], [15, &"cross"],
	]:
		var rule := NucleusModularRule.new()
		rule.neighbor_mask = definition[0]
		rule.variant_id = definition[1]
		rule.allow_rotations = true
		set.rules.append(rule)
	return set


func _build_catalog() -> NucleusPlacementVariantSet3D:
	var catalog := NucleusPlacementVariantSet3D.new()
	for name: StringName in [&"isolated", &"end", &"straight", &"corner", &"junction", &"cross"]:
		var entry := NucleusPlacementVariant3D.new()
		entry.variant_id = name
		var visual := Node3D.new()
		visual.name = "Modular_" + str(name)
		var color := StandardMaterial3D.new()
		match name:
			&"isolated":
				color.albedo_color = Color(0.87, 0.55, 0.34)
			&"end":
				color.albedo_color = Color(0.29, 0.76, 0.58)
			&"straight":
				color.albedo_color = Color(0.35, 0.67, 0.95)
			&"corner":
				color.albedo_color = Color(0.93, 0.74, 0.35)
			&"junction":
				color.albedo_color = Color(0.73, 0.50, 0.92)
			&"cross":
				color.albedo_color = Color(0.80, 0.88, 0.95)
		var stem := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.55, 0.48, 0.55)
		stem.mesh = box
		stem.material_override = color
		visual.add_child(stem)
		stem.owner = visual
		# The N axis is the authored reference for rotatable rules.
		var sides: Array[int] = []
		match name:
			&"end":
				sides = [0]
			&"straight":
				sides = [0, 2]
			&"corner":
				sides = [0, 1]
			&"junction":
				sides = [0, 1, 2]
			&"cross":
				sides = [0, 1, 2, 3]
		for side: int in sides:
			var arm := MeshInstance3D.new()
			var arm_mesh := BoxMesh.new()
			arm_mesh.size = Vector3(0.26, 0.3, 0.72)
			arm.mesh = arm_mesh
			arm.position = Vector3(0.0, 0.0, -0.52).rotated(Vector3.UP, float(side) * PI * 0.5)
			arm.rotation.y = float(side) * PI * 0.5
			arm.material_override = color
			visual.add_child(arm)
			arm.owner = visual
		var packed := PackedScene.new()
		packed.pack(visual)
		visual.free()
		entry.scene = packed
		catalog.variants.append(entry)
	return catalog


func _process(_delta: float) -> void:
	_hover_valid = false
	if _panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
		board.set_hover(Vector3i.ZERO, false)
		return
	var hit: Dictionary = board.intersect_cursor(
		camera, get_viewport().get_mouse_position(), board.active_layer
	)
	if not hit.is_empty():
		_hover = hit["cell"]
		_hover_valid = true
	board.set_hover(_hover, _hover_valid)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _hover_valid:
		if event.button_index == MOUSE_BUTTON_LEFT:
			board.paint_cell(_hover)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			board.erase_cell(_hover)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Z:
				_change_layer(-1)
			KEY_X:
				_change_layer(1)
			KEY_C:
				_clear()


func _update_neighbors(changed: Vector3i) -> void:
	var occupied := func(cell: Vector3i) -> bool:
		return board.has_tile(cell)
	binding.apply_updates(NucleusModularNeighborhood.resolve_around(
		changed, occupied, rules
	))
	_refresh()


func _change_layer(direction: int) -> void:
	board.set_active_layer(board.active_layer + direction)
	camera.position.y = 20.0 + float(board.active_layer) * board.layer_step
	camera.look_at(Vector3.UP * float(board.active_layer) * board.layer_step)
	_refresh()


func _clear() -> void:
	board.clear_tiles()
	binding.clear_visuals()
	_refresh()


func _refresh() -> void:
	if status != null:
		status.text = "Tiles: %d · Layer: %d\n" % [board.tile_count(), board.active_layer]
		status.text += "End / straight / corner / junction / cross from neighbors"


func _button(parent: Node, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	button.pressed.connect(action)
