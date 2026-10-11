extends Node3D
## Executable, game-owned integration lab for Nucleus runtime placement.
## Deliberately lives in examples/: Nucleus only owns the placement mechanics.

const HOUSE: PackedScene = preload("res://examples/placement/assets/house.tscn")
const FENCE: PackedScene = preload("res://examples/placement/assets/fence.tscn")
const PILLAR: PackedScene = preload("res://examples/placement/assets/pillar.tscn")
const PLATFORM: PackedScene = preload("res://examples/placement/assets/platform.tscn")
const CRATE: PackedScene = preload("res://examples/placement/assets/crate.tscn")

const SCENES: Array[PackedScene] = [HOUSE, FENCE, PILLAR, PLATFORM, CRATE]
const NAMES: Array[String] = ["Casa", "Valla", "Columna", "Plataforma", "Caja"]

const REASONS := {
	&"no_surface": "No hay una superficie de apoyo.",
	&"invalid_profile": "El perfil del objeto no es valido.",
	&"forbidden_support": "Este objeto no puede apoyarse aqui.",
	&"surface_tags": "La superficie no tiene las etiquetas necesarias.",
	&"steep_surface": "La pendiente supera el limite del objeto.",
	&"unsupported_footprint": "Parte de la base queda sin soporte.",
	&"mixed_support": "La base se apoya sobre objetos distintos.",
	&"invalid_normal": "La orientacion del suelo no es valida.",
	&"uneven_surface": "La superficie es demasiado irregular.",
	&"occupied": "Hay un obstaculo u otro objeto en ese volumen.",
	&"chain_limit": "Cadena demasiado larga o no valida.",
	&"invalid_scene": "No se puede instanciar la pieza.",
	&"game_policy": "La regla del juego ha rechazado el cambio.",
}

@onready var _world: Node3D = $World
@onready var _camera: Camera3D = $LabCamera

var _session: NucleusPlacementSession3D
var _selected: NucleusPlaceable3D
var _selected_marker: MeshInstance3D
var _chain_waiting_for_anchor: PackedScene
var _placed: Array[Node3D] = []
var _status_label: Label
var _mode_label: Label
var _selection_label: Label
var _info_label: Label
var _toast_label: Label

var _camera_target := Vector3(0.0, 0.0, 0.0)
var _orbit_yaw: float = 0.7
var _orbit_pitch: float = 0.85
var _camera_distance: float = 31.0
var _orbiting: bool = false
var _panning: bool = false


func _ready() -> void:
	_build_world()
	_build_selection_marker()
	_build_ui()
	_session = NucleusPlacementSession3D.new()
	_session.name = "RuntimePlacementSession"
	add_child(_session)
	_session.world_parent = _world
	_session.camera = _camera
	_session.ray_distance = 120.0
	_session.valid_preview_material = _ghost_material(Color(0.26, 0.95, 0.64, 0.52))
	_session.invalid_preview_material = _ghost_material(Color(1.0, 0.32, 0.30, 0.53))
	_session.preview_updated.connect(_on_preview_updated)
	_session.placement_confirmed.connect(_on_placement_confirmed)
	_session.placement_cancelled.connect(_on_placement_cancelled)
	_session.placement_rejected.connect(_on_placement_rejected)
	_session.removal_requested.connect(_on_removal_requested)
	_update_camera()
	_update_panels()
	_set_toast("Elige una pieza. Clic izquierdo para colocar; E para editar.")


func _process(delta: float) -> void:
	var horizontal := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		horizontal.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		horizontal.x += 1.0
	if Input.is_key_pressed(KEY_W):
		horizontal.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		horizontal.y += 1.0
	if not horizontal.is_zero_approx():
		var basis := Basis(Vector3.UP, _orbit_yaw)
		var offset: Vector3 = basis * Vector3(horizontal.x, 0.0, horizontal.y)
		_camera_target += offset.normalized() * 8.0 * delta
		_update_camera()
	_update_marker()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = button.pressed
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = button.pressed
			get_viewport().set_input_as_handled()
			return
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(8.0, _camera_distance - 2.0)
			_update_camera()
			return
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(70.0, _camera_distance + 2.0)
			_update_camera()
			return
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			_world_click(button.position)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _orbiting:
			_orbit_yaw -= motion.relative.x * 0.008
			_orbit_pitch = clampf(_orbit_pitch + motion.relative.y * 0.008, 0.30, 1.47)
			_update_camera()
		elif _panning:
			var right := _camera.global_basis.x
			var forward := -_camera.global_basis.z
			forward.y = 0.0
			_camera_target += (
				-right * motion.relative.x + forward.normalized() * motion.relative.y
			) * _camera_distance * 0.0018
			_update_camera()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				_select_asset(0)
			KEY_2, KEY_KP_2:
				_select_asset(1)
			KEY_3, KEY_KP_3:
				_select_asset(2)
			KEY_4, KEY_KP_4:
				_select_asset(3)
			KEY_5, KEY_KP_5:
				_select_asset(4)
			KEY_F:
				_select_chain()
			KEY_Q:
				_rotate(-1)
			KEY_R:
				_rotate(1)
			KEY_E:
				_edit_selection()
			KEY_DELETE, KEY_BACKSPACE:
				_remove_selection()
			KEY_ESCAPE:
				_cancel_operation()
			KEY_H:
				_focus_zone(Vector3(-10.0, 0.0, -1.0))
			KEY_J:
				_focus_zone(Vector3(0.0, 0.0, 0.0))
			KEY_K:
				_focus_zone(Vector3(10.0, 0.0, -1.0))


func _world_click(screen_position: Vector2) -> void:
	if _chain_waiting_for_anchor != null:
		var hit := _raycast(screen_position, 1)
		if hit.is_empty():
			_set_toast("El inicio de la valla necesita un terreno valido.")
			return
		var first: PackedScene = _chain_waiting_for_anchor
		_chain_waiting_for_anchor = null
		var result := _session.begin_chain(first, hit["position"])
		if result != OK:
			_set_toast("No se pudo iniciar la cadena: " + error_string(result))
		else:
			_session.update_from_screen(screen_position)
			_set_toast("Mueve el raton para ampliar la valla; otro clic confirma toda la cadena.")
		_update_panels()
		return
	if _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		var error := _session.confirm()
		if error != OK:
			_set_toast("No se puede confirmar: " + _reason_text(_session.last_reason))
		return
	var hit := _raycast(screen_position, 2)
	if hit.is_empty():
		_set_selected(null)
		return
	_set_selected(NucleusPlaceable3D.find_for_collider(hit.get("collider")))


func _select_asset(index: int) -> void:
	if index < 0 or index >= SCENES.size():
		return
	_chain_waiting_for_anchor = null
	_set_selected(null)
	var error := _session.begin_new(SCENES[index])
	if error != OK:
		_set_toast("No se pudo cargar: " + error_string(error))
		return
	_session.update_from_screen(get_viewport().get_mouse_position())
	_set_toast("Colocando " + NAMES[index] + ". Q/R rota; clic confirma; Esc cancela.")
	_update_panels()


func _select_chain() -> void:
	_session.cancel()
	_set_selected(null)
	_chain_waiting_for_anchor = FENCE
	_set_toast("Valla en cadena: haz clic sobre el suelo para fijar el inicio.")
	_update_panels()


func _edit_selection() -> void:
	if _selected == null or not is_instance_valid(_selected):
		_set_toast("Haz clic sobre una pieza colocada para seleccionarla.")
		return
	if _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		_set_toast("Confirma o cancela la operacion actual primero.")
		return
	var error := _session.begin_edit(_selected)
	if error != OK:
		_set_toast("La pieza no admite edicion: " + error_string(error))
		return
	_set_toast("Editando pieza. Mueve el raton, Q/R para rotar, clic confirma, Esc restaura.")
	_update_panels()


func _remove_selection() -> void:
	if _selected == null or not is_instance_valid(_selected):
		_set_toast("Selecciona primero un objeto colocado.")
		return
	var error := _session.request_removal(_selected)
	if error != OK:
		_set_toast("No se pudo retirar: " + error_string(error))


func _rotate(direction: int) -> void:
	if _session.mode == NucleusPlacementSession3D.Mode.IDLE:
		_set_toast("Empieza a colocar o editar un objeto para rotarlo.")
		return
	var error := _session.rotate_step(direction)
	if error != OK:
		_set_toast("Este objeto no se puede rotar.")


func _cancel_operation() -> void:
	if _chain_waiting_for_anchor != null:
		_chain_waiting_for_anchor = null
		_set_toast("Inicio de cadena cancelado.")
	elif _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		_session.cancel()
	else:
		_set_selected(null)
		_set_toast("Seleccion borrada.")
	_update_panels()


func _on_preview_updated(valid: bool, reason: StringName, transforms: Array[Transform3D]) -> void:
	_status_label.text = (
		"APTO  ·  %d pieza(s)" % transforms.size()
		if valid else "BLOQUEADO  ·  " + _reason_text(reason)
	)
	_status_label.add_theme_color_override(
		"font_color", Color(0.40, 0.96, 0.68) if valid else Color(1.0, 0.50, 0.46)
	)


func _on_placement_confirmed(roots: Array[Node3D], was_edit: bool) -> void:
	if not was_edit:
		for root: Node3D in roots:
			_placed.append(root)
		if not roots.is_empty():
			_set_selected(NucleusPlaceable3D.find_in(roots.back()))
	else:
		_set_selected(NucleusPlaceable3D.find_in(roots[0]))
	_set_toast(
		"Modificacion confirmada." if was_edit
		else "%d pieza(s) colocada(s). Ahora puedes seleccionarlas y editarlas." % roots.size()
	)
	_update_panels()


func _on_placement_cancelled(was_edit: bool) -> void:
	_set_toast("Edicion revertida." if was_edit else "Colocacion cancelada.")
	_update_panels()


func _on_placement_rejected(reason: StringName) -> void:
	_set_toast("Operación rechazada: " + _reason_text(reason))


func _on_removal_requested(root: Node3D) -> void:
	# Demo-only mutation: production games own permissions, saves and authority.
	if root == null or not is_instance_valid(root) or root not in _placed:
		return
	_placed.erase(root)
	_set_selected(null)
	root.queue_free()
	_set_toast("Pieza retirada del laboratorio.")
	_update_panels()


func _set_selected(placeable: NucleusPlaceable3D) -> void:
	_selected = placeable if is_instance_valid(placeable) else null
	_update_marker()
	_update_panels()


func _update_marker() -> void:
	if _selected_marker == null:
		return
	var visible_selection := (
		_selected != null and is_instance_valid(_selected)
		and _selected.is_inside_tree()
		and (_session == null or _session.mode == NucleusPlacementSession3D.Mode.IDLE)
	)
	_selected_marker.visible = visible_selection
	if not visible_selection:
		return
	var root := _selected.get_root()
	_selected_marker.global_position = root.global_position + Vector3(0.0, 0.09, 0.0)
	var extent: Vector2 = _selected.profile.support_half_extents
	var size: float = maxf(extent.x, extent.y) + 0.33
	_selected_marker.scale = Vector3(size, 1.0, size)


func _raycast(screen_pos: Vector2, mask: int) -> Dictionary:
	var from := _camera.project_ray_origin(screen_pos)
	var to := from + _camera.project_ray_normal(screen_pos) * 120.0
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	query.collide_with_areas = false
	return _camera.get_world_3d().direct_space_state.intersect_ray(query)


func _focus_zone(position: Vector3) -> void:
	_camera_target = position
	_update_camera()


func _update_camera() -> void:
	var planar := cos(_orbit_pitch) * _camera_distance
	_camera.position = _camera_target + Vector3(
		sin(_orbit_yaw) * planar,
		sin(_orbit_pitch) * _camera_distance,
		cos(_orbit_yaw) * planar,
	)
	_camera.look_at(_camera_target, Vector3.UP)


func _update_panels() -> void:
	if _mode_label == null:
		return
	var active := "Exploracion"
	if _chain_waiting_for_anchor != null:
		active = "Cadena: elegir inicio"
	elif _session != null:
		match _session.mode:
			NucleusPlacementSession3D.Mode.SINGLE:
				active = "Colocacion individual"
			NucleusPlacementSession3D.Mode.CHAIN:
				active = "Cadena de vallas"
			NucleusPlacementSession3D.Mode.EDIT:
				active = "Editar objeto existente"
	_mode_label.text = "MODO  /  " + active
	var selected_name := "Ninguna"
	if _selected != null and is_instance_valid(_selected):
		selected_name = str(_selected.profile.kind).capitalize()
	_selection_label.text = "Seleccionado: " + selected_name
	var kept := 0
	for root: Node3D in _placed:
		if is_instance_valid(root):
			kept += 1
	_info_label.text = "Colocados: %d    |    Zonas: plano, rampa 18°, rampa 43°" % kept
	if _session == null or _session.mode == NucleusPlacementSession3D.Mode.IDLE:
		_status_label.text = "LISTO  ·  Elige una pieza o selecciona una existente"
		_status_label.add_theme_color_override("font_color", Color(0.68, 0.83, 0.96))


func _set_toast(message: String) -> void:
	if _toast_label != null:
		_toast_label.text = message


func _reason_text(reason: StringName) -> String:
	return str(REASONS.get(reason, str(reason).replace("_", " ")))


func _build_world() -> void:
	var flat := _material(Color(0.23, 0.34, 0.33))
	var ramp_ok := _material(Color(0.41, 0.54, 0.65))
	var ramp_bad := _material(Color(0.62, 0.35, 0.35))
	var blocked := _material(Color(0.66, 0.29, 0.26))
	var accent := _material(Color(0.35, 0.51, 0.64))
	_box_body("Suelo plano", Vector3(0, -0.5, 0), Vector3(56, 1, 54), flat, 1)
	_box_body(
		"Rampa 18 grados", Vector3(-11, 1.65, -1),
		Vector3(8, 0.35, 9), ramp_ok, 1, Vector3(18, 0, 0),
	)
	_box_body(
		"Rampa 43 grados", Vector3(11, 2.9, -1),
		Vector3(7, 0.35, 7), ramp_bad, 1, Vector3(43, 0, 0),
	)
	_box_body("Obstaculo", Vector3(0, 0.9, -8), Vector3(3.4, 1.8, 2.8), blocked, 4)
	_box_body("Obstaculo bajo", Vector3(6.5, 0.42, 6.3), Vector3(1.8, 0.85, 3.3), accent, 4)
	_build_grid()
	_sign("TERRENO PLANO", Vector3(0, 0.05, 11.5), Color(0.68, 0.90, 0.82))
	_sign("PENDIENTE 18°", Vector3(-11, 0.08, 5.4), Color(0.68, 0.83, 1.0))
	_sign("PENDIENTE 43°", Vector3(11, 0.08, 5.4), Color(1.0, 0.62, 0.57))
	_sign("ZONA OBSTACULOS", Vector3(0, 0.06, -11.4), Color(1.0, 0.62, 0.57))
	var sun := $Sun as DirectionalLight3D
	sun.rotation_degrees = Vector3(-56, -28, 0)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.18, 0.23)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.68, 0.78, 0.89)
	environment.ambient_light_energy = 0.55
	$WorldEnvironment.environment = environment


func _box_body(
	label: String,
	location: Vector3,
	size: Vector3,
	material: Material,
	layer: int,
	rotation: Vector3 = Vector3.ZERO,
) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = location
	body.rotation_degrees = rotation
	body.collision_layer = layer
	body.collision_mask = 0
	_world.add_child(body)
	var visual := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	visual.mesh = cube
	visual.material_override = material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)


func _build_grid() -> void:
	var mesh := ImmediateMesh.new()
	var material := _material(Color(0.38, 0.47, 0.49, 0.28))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for coordinate: int in range(-27, 28, 2):
		mesh.surface_add_vertex(Vector3(float(coordinate), 0.017, -26.5))
		mesh.surface_add_vertex(Vector3(float(coordinate), 0.017, 26.5))
		mesh.surface_add_vertex(Vector3(-27, 0.017, float(coordinate)))
		mesh.surface_add_vertex(Vector3(27, 0.017, float(coordinate)))
	mesh.surface_end()
	var grid := MeshInstance3D.new()
	grid.mesh = mesh
	grid.name = "Cuadricula visual sin colision"
	_world.add_child(grid)


func _sign(message: String, world_position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = message
	label.position = world_position + Vector3.UP * 1.6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.pixel_size = 0.009
	label.modulate = color
	label.outline_size = 5
	_world.add_child(label)


func _build_selection_marker() -> void:
	_selected_marker = MeshInstance3D.new()
	_selected_marker.name = "Indicador de seleccion (solo visual)"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.92
	ring.outer_radius = 1.0
	_selected_marker.mesh = ring
	_selected_marker.material_override = _ghost_material(Color(1.0, 0.85, 0.32, 0.8))
	_selected_marker.visible = false
	_world.add_child(_selected_marker)


func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.83
	return result


func _ghost_material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.no_depth_test = true
	return result


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Interfaz del laboratorio"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var left := _panel()
	left.offset_left = 16.0
	left.offset_top = 15.0
	left.offset_right = 322.0
	left.offset_bottom = 590.0
	root.add_child(left)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	left.add_child(stack)
	_add_label(stack, "NUCLEUS  /  PLACEMENT LAB", 18, Color(0.85, 0.96, 1.0))
	_add_label(stack, "Geometria de prueba · Godot 4", 12, Color(0.70, 0.81, 0.88))
	_add_label(stack, "CREAR PIEZA", 14, Color(0.42, 0.92, 0.78))
	for index: int in range(SCENES.size()):
		var idx := index
		_add_button(stack, "%d   %s" % [index + 1, NAMES[index]], func() -> void: _select_asset(idx))
	_add_button(stack, "F   Valla en cadena (2 clics)", _select_chain)
	_add_label(stack, "EDITAR SELECCION", 14, Color(0.42, 0.92, 0.78))
	_selection_label = _add_label(stack, "Seleccionado: Ninguna", 12, Color(0.88, 0.91, 0.94))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	stack.add_child(row)
	_add_button(row, "E  Mover", _edit_selection, true)
	_add_button(row, "Supr  Quitar", _remove_selection, true)
	var rotate_row := HBoxContainer.new()
	rotate_row.add_theme_constant_override("separation", 5)
	stack.add_child(rotate_row)
	_add_button(rotate_row, "Q  ↶ Rotar", func() -> void: _rotate(-1), true)
	_add_button(rotate_row, "R  ↷ Rotar", func() -> void: _rotate(1), true)
	_add_button(stack, "Esc   Cancelar / Revertir", _cancel_operation)
	_add_label(
		stack,
		"Raton derecho: orbitar · Rueda: zoom\n"
		+ "Raton central: mover · WASD: desplazar\n"
		+ "H/J/K: pendientes / plano",
		12, Color(0.69, 0.81, 0.89),
	)

	var right := _panel()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -388.0
	right.offset_top = 15.0
	right.offset_right = -16.0
	right.offset_bottom = 160.0
	root.add_child(right)
	var right_stack := VBoxContainer.new()
	right_stack.add_theme_constant_override("separation", 7)
	right.add_child(right_stack)
	_mode_label = _add_label(right_stack, "MODO  /  Exploracion", 14, Color(0.90, 0.96, 1.0))
	_status_label = _add_label(right_stack, "LISTO", 12, Color(0.50, 0.89, 0.75))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label = _add_label(right_stack, "Colocados: 0", 12, Color(0.69, 0.82, 0.92))
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var footer := _panel()
	footer.anchor_left = 0.0
	footer.anchor_right = 1.0
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_left = 338.0
	footer.offset_right = -18.0
	footer.offset_top = -75.0
	footer.offset_bottom = -17.0
	root.add_child(footer)
	_toast_label = _add_label(footer, "", 14, Color(0.92, 0.94, 0.97))
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.085, 0.13, 0.18, 0.94)
	style.border_color = Color(0.22, 0.38, 0.45, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _add_label(parent: Node, value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _add_button(parent: Node, label: String, callback: Callable, expand: bool = false) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 30)
	if expand:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	button.pressed.connect(callback)
	return button
