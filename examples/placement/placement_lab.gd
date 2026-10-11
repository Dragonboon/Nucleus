extends Node3D
## Executable, game-owned integration lab for Nucleus runtime placement.
## Deliberately lives in examples/: Nucleus only owns the placement mechanics.

const HOUSE: PackedScene = preload("res://examples/placement/assets/house.tscn")
const HOUSE_FLAT: PackedScene = preload("res://examples/placement/assets/house_flat.tscn")
const HOUSE_HIP: PackedScene = preload("res://examples/placement/assets/house_hip.tscn")
const FENCE: PackedScene = preload("res://examples/placement/assets/fence.tscn")
const PILLAR: PackedScene = preload("res://examples/placement/assets/pillar.tscn")
const PLATFORM: PackedScene = preload("res://examples/placement/assets/platform.tscn")
const CRATE: PackedScene = preload("res://examples/placement/assets/crate.tscn")
const TOTEM: PackedScene = preload("res://examples/placement/assets/totem.tscn")

const WORLD_DOCUMENT = preload("res://examples/placement/placement_world_document.gd")
const WORLD_SAVE_PREFIX: String = "user://placement_lab_world_"
const WORLD_SLOT_COUNT: int = 3
const MAX_DUPLICATE_GROUP: int = 8
const SCENES: Array[PackedScene] = [HOUSE, FENCE, PILLAR, PLATFORM, CRATE, TOTEM]
const KINDS: Array[String] = ["house", "fence", "pillar", "platform", "crate", "totem"]
const NAMES: Array[String] = ["Casa", "Valla", "Columna", "Plataforma", "Caja", "Tótem"]

const REASONS := {
	&"no_surface": "No hay una superficie de apoyo.",
	&"invalid_profile": "El perfil del objeto no es valido.",
	&"invalid_snap": "La cuadricula del snap no es valida.",
	&"forbidden_support": "Este objeto no puede apoyarse aqui.",
	&"surface_tags": "La superficie no tiene las etiquetas necesarias.",
	&"steep_surface": "La pendiente supera el limite del objeto.",
	&"unsupported_footprint": "Parte de la base queda sin soporte.",
	&"mixed_support": "La base se apoya sobre objetos distintos.",
	&"invalid_normal": "La orientacion del suelo no es valida.",
	&"uneven_surface": "La superficie es demasiado irregular.",
	&"occupied": "Hay un obstaculo u otro objeto en ese volumen.",
	&"chain_limit": "Cadena demasiado larga o no valida.",
	&"chain_self_overlap": "La curva hace que varios tramos se solapen.",
	&"group_self_overlap": "Los objetos del grupo se solapan entre si.",
	&"checking": "Validando por partes (sin bloquear el frame)...",
	&"invalid_scene": "No se puede instanciar la pieza.",
	&"no_visual_bounds": "El objeto requiere mallas visibles para calcular su base.",
	&"game_policy": "La regla del juego ha rechazado el cambio.",
}

@onready var _world: Node3D = $World
@onready var _camera: Camera3D = $LabCamera

var _session: NucleusPlacementSession3D
var _selected: NucleusPlaceable3D
var _selected_items: Array[NucleusPlaceable3D] = []
var _extra_selection_markers: Array[MeshInstance3D] = []
var _path_markers: Array[MeshInstance3D] = []
var _marquee: ColorRect
var _marquee_start: Vector2 = Vector2.ZERO
var _marquee_dragging: bool = false
var _curve_waiting_for_anchor: PackedScene
var _selected_marker: MeshInstance3D
var _chain_waiting_for_anchor: PackedScene
var _placed: Array[Node3D] = []
var _history := NucleusValidatedActionHistory.new()
var _catalog: Dictionary = {}
var _next_piece_id: int = 1
var _before_edit_document: Dictionary = {}
var _saved_document: Dictionary = {}
var _slot_documents: Dictionary = {}
var _active_world_slot: int = 1
var _clipboard: Dictionary = {}
var _confirmation: ConfirmationDialog
var _status_label: Label
var _mode_label: Label
var _snap_label: Label
var _snap_toggle: CheckButton
var _repeat_toggle: CheckButton
var _repeat_placement: bool = true
var _free_rotation: bool = false
var _rotation_toggle: CheckButton
var _roof_catalog: NucleusPlacementVariantSet3D
var _repeat_variant_id: StringName = &""
var _brush_scene: PackedScene
## Optional paint tool; the regular click-to-place session is unchanged.
var _paint_mode: bool = false
var _paint_dragging: bool = false
var _paint_closing: bool = false
var _paint_processing: bool = false
var _paint_tool := NucleusPlacementBrush3D.new()
var _paint_pending: Array[Vector3] = []
var _paint_before: Dictionary = {}
var _paint_accepted: int = 0
var _paint_rejected: int = 0
var _paint_radius: float = 0.0
var _paint_spacing: float = 1.5
var _paint_stroke_limit: int = 64
var _paint_toggle: CheckButton
var _pending_duplicate: bool = false
var _visual_grid: MeshInstance3D
var _snap_steps: OptionButton
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
	for i: int in range(KINDS.size()):
		_catalog[KINDS[i]] = SCENES[i]
	_catalog["house:roof_gable"] = HOUSE
	_catalog["house:roof_flat"] = HOUSE_FLAT
	_catalog["house:roof_hip"] = HOUSE_HIP
	_roof_catalog = _build_roof_catalog()
	_history.max_actions = 24
	_history.max_snapshot_bytes = WORLD_DOCUMENT.MAX_FILE_BYTES
	_history.max_snapshot_items = 25000
	_build_world()
	_build_selection_marker()
	_build_ui()
	_session = NucleusPlacementSession3D.new()
	_session.name = "RuntimePlacementSession"
	add_child(_session)
	_session.world_parent = _world
	_session.camera = _camera
	_session.ray_distance = 120.0
	_session.admission = Callable(self, "_admit_placement")
	_session.valid_preview_material = _ghost_material(Color(0.26, 0.95, 0.64, 0.52))
	_session.invalid_preview_material = _ghost_material(Color(1.0, 0.32, 0.30, 0.53))
	_session.pending_preview_material = _ghost_material(Color(1.0, 0.73, 0.25, 0.45))
	_session.max_checks_per_tick = 3
	_session.max_group_count = WORLD_DOCUMENT.MAX_PIECES
	_session.preview_interval_ms = 65
	# An OFF toggle now means truly free positioning, even for forced-snap assets.
	_session.set_snap_defaults(false, Vector2.ONE, Vector2.ZERO, true)
	_session.preview_updated.connect(_on_preview_updated)
	_session.placement_confirmed.connect(_on_placement_confirmed)
	_session.placement_cancelled.connect(_on_placement_cancelled)
	_session.placement_rejected.connect(_on_placement_rejected)
	_session.removal_requested.connect(_on_removal_requested)
	_session.variant_changed.connect(_on_variant_changed)
	# NucleusSave handles storage and integrity; the lab owns scene reconstruction.
	if not NucleusSave.is_initialized():
		push_warning("Placement lab: NucleusSave is not initialized.")
	# A file from a previous run is not the current world until explicitly loaded.
	_saved_document = {}
	_update_camera()
	_update_panels()
	_set_toast("Elige una pieza. Clic izquierdo para colocar; E para editar.")


## One world candidate per physics tick, never an unbounded drag burst.
func _physics_process(_delta: float) -> void:
	if _paint_dragging or _paint_closing:
		_paint_pump()


func _process(delta: float) -> void:
	if _free_rotation and _session != null and not _paint_dragging:
		var direction := float(int(Input.is_key_pressed(KEY_R)) - int(Input.is_key_pressed(KEY_Q)))
		if not is_zero_approx(direction) and not Input.is_key_pressed(KEY_CTRL):
			_session.rotate_held(direction, delta)
	var horizontal := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) and not Input.is_key_pressed(KEY_CTRL):
		horizontal.x -= 1.0
	if Input.is_key_pressed(KEY_D) and not Input.is_key_pressed(KEY_CTRL):
		horizontal.x += 1.0
	if Input.is_key_pressed(KEY_W):
		horizontal.y -= 1.0
	if Input.is_key_pressed(KEY_S) and not Input.is_key_pressed(KEY_CTRL):
		horizontal.y += 1.0
	if not horizontal.is_zero_approx():
		var basis := Basis(Vector3.UP, _orbit_yaw)
		var offset: Vector3 = basis * Vector3(horizontal.x, 0.0, horizontal.y)
		_camera_target += offset.normalized() * 8.0 * delta
		_update_camera()
	_update_marker()
	_update_path_markers()
	if _session != null and _status_label != null:
		var progress := _session.get_validation_progress()
		if progress.y > 0:
			_status_label.text = "COMPROBANDO %d / %d verificaciones" % [progress.x, progress.y]
	# Mouse release over a Control may bypass _unhandled_input: finish anyway.
	if _paint_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_paint_end()
	if _marquee_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_marquee_dragging = false
		_marquee.visible = false
		_select_in_rectangle(Rect2(
			_marquee_start, get_viewport().get_mouse_position() - _marquee_start,
		).abs())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT:
			# During curved placement, RMB adds a bend instead of orbiting.
			# Alt+RMB is the explicit camera-orbit override in this mode.
			var editing_curve := (
				_session != null
				and _session.mode == NucleusPlacementSession3D.Mode.PATH
			)
			if editing_curve and not button.alt_pressed and not _orbiting:
				if button.pressed:
					_add_curve_control_at(button.position)
				get_viewport().set_input_as_handled()
				return
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
		if button.button_index == MOUSE_BUTTON_LEFT:
			if _paint_mode:
				if button.pressed:
					_paint_start(button.position)
				else:
					_paint_end()
				get_viewport().set_input_as_handled()
				return
			if (
				button.pressed and button.shift_pressed
				and _session.mode == NucleusPlacementSession3D.Mode.IDLE
			):
				_marquee_start = button.position
				_marquee_dragging = true
				_show_marquee(_marquee_start, _marquee_start)
				get_viewport().set_input_as_handled()
				return
			if not button.pressed and _marquee_dragging:
				_marquee_dragging = false
				_marquee.visible = false
				_select_in_rectangle(Rect2(_marquee_start, button.position - _marquee_start).abs())
				get_viewport().set_input_as_handled()
				return
			if button.pressed and not _marquee_dragging:
				_world_click(button.position, button.ctrl_pressed)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _paint_mode and _paint_dragging and not _orbiting and not _panning:
			_paint_add_cursor(motion.position)
			return
		if _marquee_dragging:
			_show_marquee(_marquee_start, motion.position)
		elif _orbiting:
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
		if _paint_dragging or _paint_closing:
			if event.keycode == KEY_ESCAPE:
				_paint_abort()
			else:
				_set_toast("Termina el trazo antes de usar otras herramientas.")
			get_viewport().set_input_as_handled()
			return
		if event.ctrl_pressed:
			match event.keycode:
				KEY_Z:
					if event.shift_pressed:
						_redo()
					else:
						_undo()
				KEY_Y:
					_redo()
				KEY_D:
					_duplicate_selection()
				KEY_C:
					_copy_selection()
				KEY_V:
					_paste_selection()
				KEY_A:
					_select_all()
				KEY_S:
					_save_world()
				KEY_O:
					_confirm_world_replacement(false)
				KEY_N:
					_confirm_world_replacement(true)
				_:
					return
			get_viewport().set_input_as_handled()
			return
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
			KEY_6, KEY_KP_6:
				_select_asset(5)
			KEY_P:
				_toggle_paint_mode()
			KEY_F:
				_select_chain()
			KEY_C:
				_select_curve()
			KEY_BACKSPACE:
				_remove_last_curve_point()
			KEY_A:
				if event.ctrl_pressed:
					_select_all()
			KEY_Q:
				if not _free_rotation:
					_rotate(-1)
			KEY_R:
				if not _free_rotation:
					_rotate(1)
			KEY_T:
				_toggle_rotation_mode()
			KEY_V:
				_cycle_roof(1)
			KEY_X:
				_cycle_roof(-1)
			KEY_E:
				_edit_selection()
			KEY_G:
				_toggle_default_snap()
			KEY_DELETE:
				_remove_selection()
			KEY_ESCAPE:
				_cancel_operation()
			KEY_H:
				_focus_zone(Vector3(-10.0, 0.0, -1.0))
			KEY_J:
				_focus_zone(Vector3(0.0, 0.0, 0.0))
			KEY_K:
				_focus_zone(Vector3(10.0, 0.0, -1.0))
			KEY_B:
				_toggle_repeat_placement()


func _world_click(screen_position: Vector2, additive: bool = false) -> void:
	if _curve_waiting_for_anchor != null:
		var hit := _raycast(screen_position, 1)
		if hit.is_empty():
			_set_toast("Necesitas terreno bajo el primer punto de la curva.")
			return
		var scene: PackedScene = _curve_waiting_for_anchor
		_curve_waiting_for_anchor = null
		var result := _session.begin_path(scene, hit["position"])
		if result == OK:
			_session.update_from_screen(screen_position)
			_set_toast("Curva iniciada. Clic derecho: nuevo giro; clic izquierdo: colocar.")
		else:
			_set_toast("No se pudo iniciar la curva: " + error_string(result))
		_update_panels()
		return
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
	if _session.mode == NucleusPlacementSession3D.Mode.PATH:
		# LMB commits the full path at the actual clicked position.
		# confirm() revalidates asynchronously; it is not an instant success.
		_session.update_from_screen(screen_position)
		_finish_curve()
		return
	if _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		var error := _session.confirm()
		if error != OK:
			_set_toast("No se puede confirmar: " + _reason_text(_session.last_reason))
		return
	var hit := _raycast(screen_position, 2)
	if hit.is_empty():
		if not additive:
			_set_selected(null)
		return
	var picked := NucleusPlaceable3D.find_for_collider(hit.get("collider"))
	if additive:
		_toggle_selected(picked)
	else:
		_set_selected(picked)


## RMB commits one control point, without affecting the live chain preview.
## The first anchor is still chosen by LMB after pressing C.
func _add_curve_control_at(screen_position: Vector2) -> void:
	if _session == null or _session.mode != NucleusPlacementSession3D.Mode.PATH:
		return
	var hit := _raycast(screen_position, 1)
	if hit.is_empty():
		_set_toast("No hay terreno bajo el nuevo punto de curva.")
		return
	var error: Error = _session.add_path_control(hit["position"])
	if error != OK:
		_set_toast("Punto rechazado: " + error_string(error))
	else:
		_set_toast("Giro añadido. Clic derecho: otro giro; izquierdo: colocar.")
	_update_panels()


## Explicit interaction modes: G OFF = free, G ON = per-asset rules + grid.
func _toggle_default_snap() -> void:
	if _session == null:
		return
	var next := not _session.snap_enabled_by_default
	var error := _session.set_snap_defaults(
		next, _session.snap_grid_step, _session.snap_grid_origin, not next,
	)
	if error != OK:
		if _snap_toggle != null:
			_snap_toggle.set_pressed_no_signal(_session.snap_enabled_by_default)
		_set_toast("Snap ocupado o configuración no válida: " + error_string(error))
		return
	if _snap_toggle != null:
		_snap_toggle.set_pressed_no_signal(next)
	if _visual_grid != null:
		_visual_grid.visible = next
	_set_toast(
		"SNAP: activos los perfiles y la cuadricula." if next
		else "LIBRE: movimiento continuo, sin snap, incluso para assets forzados."
	)
	_update_panels()


func _set_snap_step(index: int) -> void:
	if _session == null:
		return
	var choices := [0.5, 1.0, 2.0]
	if index < 0 or index >= choices.size():
		return
	var step: float = choices[index]
	var error := _session.set_snap_defaults(
		_session.snap_enabled_by_default, Vector2(step, step),
		_session.snap_grid_origin,
	)
	if error != OK:
		if _snap_steps != null:
			_snap_steps.select(choices.find(_session.snap_grid_step.x))
		_set_toast("No se pudo cambiar el paso: " + error_string(error))
		return
	_update_panels()


func _toggle_repeat_placement() -> void:
	_repeat_placement = not _repeat_placement
	if _repeat_toggle != null:
		_repeat_toggle.set_pressed_no_signal(_repeat_placement)
	_set_toast("Colocacion continua activa." if _repeat_placement else "Colocacion unica activa.")
	_update_panels()


## The session has committed and cleared its previous preview before calling
## this; use a deferred continuation to avoid signal reentrancy during physics.
func _resume_brush(scene: PackedScene) -> void:
	if _paint_mode or not _repeat_placement or _brush_scene != scene:
		return
	if _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		return
	var result: Error = (
		_session.begin_variants(_roof_catalog, _repeat_variant_id)
		if scene == HOUSE and _repeat_variant_id != &""
		else _session.begin_new(scene)
	)
	if result == OK:
		_session.update_from_screen(get_viewport().get_mouse_position())
		_update_panels()


## The lab owns authoring UX, catalog, stroke transactions and allowed paint masks.
## NucleusPlacementBrush3D owns only spacing/jitter. Session owns physics.
func _toggle_paint_mode() -> void:
	if _paint_dragging or _paint_closing:
		_set_toast("Termina o cancela el trazo actual.")
		_paint_toggle.set_pressed_no_signal(_paint_mode)
		return
	if not _paint_mode and _brush_scene == null:
		_brush_scene = CRATE
	_paint_mode = not _paint_mode
	_paint_toggle.set_pressed_no_signal(_paint_mode)
	if _paint_mode:
		_chain_waiting_for_anchor = null
		_curve_waiting_for_anchor = null
		_session.cancel()
		_set_selected(null)
		_set_toast("Pincel activo: arrastra clic izquierdo. Un trazo = un deshacer.")
	elif _brush_scene != null:
		_resume_brush(_brush_scene)
		_set_toast("Pincel desactivado. Vuelve la colocación individual.")
	_update_panels()


func _paint_start(screen_position: Vector2) -> void:
	if _paint_dragging or _paint_closing or _brush_scene == null:
		return
	if _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		_session.cancel()
	var started: Error = _paint_tool.begin(
		_paint_spacing, _paint_radius, _paint_stroke_limit, 11731,
	)
	if started != OK:
		_set_toast("Perfil de pincel no valido.")
		return
	_paint_pending.clear()
	_paint_before = _capture_document()
	_paint_accepted = 0
	_paint_rejected = 0
	_paint_dragging = true
	_paint_closing = false
	_paint_add_cursor(screen_position)


func _paint_add_cursor(screen_position: Vector2) -> void:
	if not _paint_dragging or _paint_tool.is_full():
		return
	# The lab paint brush targets terrain (layer 1), not placeable roofs.
	var hit: Dictionary = _raycast(screen_position, 1)
	if hit.is_empty():
		return
	for candidate: Vector3 in _paint_tool.add_cursor(hit["position"]):
		_paint_pending.append(candidate)


func _paint_end() -> void:
	if not _paint_dragging:
		return
	_paint_dragging = false
	_paint_closing = true
	_paint_tool.end()


func _paint_pump() -> void:
	if _paint_processing or _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		return
	if _paint_pending.is_empty():
		if _paint_closing:
			_paint_closing = false
			_record_action(_paint_before, &"paint_stroke")
			_paint_before.clear()
			_set_toast("Pincel: %d colocados, %d rechazados. Ctrl+Z deshace el trazo." % [
				_paint_accepted, _paint_rejected,
			])
			_update_panels()
		return
	if _placed.size() >= WORLD_DOCUMENT.MAX_PIECES:
		_paint_rejected += _paint_pending.size()
		_paint_pending.clear()
		return
	var position: Vector3 = _paint_pending.pop_front()
	var space: PhysicsDirectSpaceState3D = _world.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		position + Vector3.UP * 60.0,
		position - Vector3.UP * 60.0,
		1,
	)
	query.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		_paint_rejected += 1
		return
	_paint_processing = true
	if _session.begin_new(_brush_scene) != OK:
		_paint_processing = false
		_paint_rejected += 1
		return
	if not _session.update_from_hit(hit):
		_session.cancel()
		_paint_processing = false
		_paint_rejected += 1
		return
	var error: Error = _session.confirm()
	if error != OK and _paint_processing:
		_session.cancel()
		_paint_processing = false
		_paint_rejected += 1


func _paint_abort() -> void:
	_paint_pending.clear()
	_paint_tool.end()
	_paint_dragging = false
	_paint_closing = false
	_paint_processing = false
	_session.cancel()
	if not _paint_before.is_empty():
		var error: Error = _restore_document(_paint_before)
		if error != OK:
			push_error("Paint rollback failed: %s" % error_string(error))
	_paint_before.clear()
	_set_toast("Trazo cancelado y revertido.")


func _select_asset(index: int) -> void:
	if index < 0 or index >= SCENES.size():
		return
	if _paint_mode:
		_paint_mode = false
		_paint_toggle.set_pressed_no_signal(false)
	_chain_waiting_for_anchor = null
	_curve_waiting_for_anchor = null
	_brush_scene = SCENES[index]
	_set_selected(null)
	_repeat_variant_id = &""
	var error: Error = (
		_session.begin_variants(_roof_catalog) if index == 0
		else _session.begin_new(SCENES[index])
	)
	if error != OK:
		_set_toast("No se pudo cargar: " + error_string(error))
		return
	_session.update_from_screen(get_viewport().get_mouse_position())
	_set_toast("Colocando " + NAMES[index] + ". Q/R rota; T alterna giro; V/X cambia tejado.")
	_update_panels()


func _select_chain() -> void:
	if _paint_mode:
		_paint_mode = false
		_paint_toggle.set_pressed_no_signal(false)
	_brush_scene = null
	_session.cancel()
	_set_selected(null)
	_curve_waiting_for_anchor = null
	_chain_waiting_for_anchor = FENCE
	_set_toast("Valla en cadena: haz clic sobre el suelo para fijar el inicio.")
	_update_panels()


func _select_curve() -> void:
	if _paint_mode:
		_paint_mode = false
		_paint_toggle.set_pressed_no_signal(false)
	_brush_scene = null
	_session.cancel()
	_set_selected(null)
	_chain_waiting_for_anchor = null
	_curve_waiting_for_anchor = FENCE
	_set_toast("Cadena CURVA: clic izquierdo para fijar el inicio; derecho para giros.")
	_update_panels()


func _finish_curve() -> void:
	if _session.mode != NucleusPlacementSession3D.Mode.PATH:
		return
	var error := _session.confirm()
	if error == OK:
		# A short chain can commit synchronously and emit placement_confirmed
		# before confirm() returns. Never overwrite its success feedback.
		if _session.mode == NucleusPlacementSession3D.Mode.PATH:
			_set_toast("Validando cadena antes de colocarla...")
	elif error == ERR_BUSY:
		_set_toast("La cadena ya se esta comprobando. Espera al resultado.")
	else:
		_set_toast("No se puede colocar: " + _reason_text(_session.last_reason)
			+ " (" + error_string(error) + ")")


func _remove_last_curve_point() -> void:
	if _session.mode == NucleusPlacementSession3D.Mode.PATH:
		if _session.remove_last_path_control() == OK:
			_set_toast("Último punto de la curva retirado.")


func _toggle_selected(placeable: NucleusPlaceable3D) -> void:
	if placeable == null or not is_instance_valid(placeable):
		return
	if placeable in _selected_items:
		_selected_items.erase(placeable)
	else:
		_selected_items.append(placeable)
	_selected = _selected_items.back() if not _selected_items.is_empty() else null
	_update_marker()
	_update_panels()


func _select_all() -> void:
	# Selection takes priority over painting; subsequent clicks can edit assets.
	if _paint_mode:
		_paint_mode = false
		_paint_toggle.set_pressed_no_signal(false)
	# A repeated single-asset brush is not a modal lock: Ctrl+A switches
	# immediately to selection mode, so E can move the whole authored world.
	if _session.mode == NucleusPlacementSession3D.Mode.SINGLE and _brush_scene != null:
		_brush_scene = null
		_session.cancel()
	if _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		return
	_selected_items.clear()
	for root: Node3D in _placed:
		if is_instance_valid(root):
			var placeable := NucleusPlaceable3D.find_in(root)
			if placeable != null:
				_selected_items.append(placeable)
	_selected = _selected_items.back() if not _selected_items.is_empty() else null
	_update_marker()
	_update_panels()


func _show_marquee(a: Vector2, b: Vector2) -> void:
	var rectangle := Rect2(a, b - a).abs()
	_marquee.position = rectangle.position
	_marquee.size = rectangle.size
	_marquee.visible = true


func _select_in_rectangle(rectangle: Rect2) -> void:
	_selected_items.clear()
	for root: Node3D in _placed:
		if not is_instance_valid(root):
			continue
		var p := NucleusPlaceable3D.find_in(root)
		if p == null or _camera.is_position_behind(root.global_position):
			continue
		if rectangle.has_point(_camera.unproject_position(root.global_position)):
			_selected_items.append(p)
	_selected = _selected_items.back() if not _selected_items.is_empty() else null
	_update_marker()
	_update_panels()


func _update_path_markers() -> void:
	if _session == null:
		return
	var points: Array[Vector3] = []
	if _session.mode == NucleusPlacementSession3D.Mode.PATH:
		points = _session.get_path_controls()
	while _path_markers.size() < points.size():
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.18
		sphere.height = 0.36
		marker.mesh = sphere
		marker.material_override = _ghost_material(Color(1.0, 0.81, 0.26, 0.95))
		_world.add_child(marker)
		_path_markers.append(marker)
	for i: int in range(_path_markers.size()):
		_path_markers[i].visible = i < points.size()
		if i < points.size():
			_path_markers[i].global_position = points[i] + Vector3.UP * 0.25


func _edit_selection() -> void:
	if _selected_items.is_empty():
		_set_toast("Selecciona una o varias piezas; Ctrl+clic o Mayus+arrastrar.")
		return
	if _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		_set_toast("Confirma o cancela la operacion actual primero.")
		return
	var before := _capture_document()
	var error := _session.begin_edit_many(_selected_items.duplicate())
	if error != OK:
		_set_toast("La pieza no admite edicion: " + error_string(error))
		return
	_brush_scene = null
	_before_edit_document = before
	_set_toast("Editando pieza. Mueve el raton, Q/R para rotar, clic confirma, Esc restaura.")
	_update_panels()


func _remove_selection() -> void:
	if _selected_items.is_empty():
		_set_toast("Selecciona primero uno o varios objetos colocados.")
		return
	if _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		return
	# Validate all before issuing deletion requests; no partial authoring by mistake.
	for p: NucleusPlaceable3D in _selected_items:
		if not is_instance_valid(p) or p.profile == null or not p.profile.can_remove:
			_set_toast("No todos los seleccionados permiten retirarse.")
			return
	var before := _capture_document()
	for p: NucleusPlaceable3D in _selected_items.duplicate():
		var error := _session.request_removal(p)
		if error != OK:
			_set_toast("No se pudo retirar: " + error_string(error))
			return
	_set_selected(null)
	_record_action(before, &"remove")


func _toggle_rotation_mode() -> void:
	_free_rotation = not _free_rotation
	if _rotation_toggle != null:
		_rotation_toggle.set_pressed_no_signal(_free_rotation)
	_set_toast("Giro libre: mantén Q/R." if _free_rotation else "Giro por pasos: pulsa Q/R.")


func _cycle_roof(direction: int) -> void:
	if _session == null or _session.get_variant_id() == &"":
		return
	var result: Error = _session.cycle_variant(direction)
	if result != OK:
		_set_toast("No se pudo cambiar el tejado: " + error_string(result))


func _on_variant_changed(variant_id: StringName, _index: int) -> void:
	_repeat_variant_id = variant_id
	_set_toast("Variante de casa: %s" % str(variant_id))


func _build_roof_catalog() -> NucleusPlacementVariantSet3D:
	var catalog := NucleusPlacementVariantSet3D.new()
	catalog.default_variant_id = &"roof_gable"
	for option: Dictionary in [
		{"id": &"roof_gable", "scene": HOUSE},
		{"id": &"roof_flat", "scene": HOUSE_FLAT},
		{"id": &"roof_hip", "scene": HOUSE_HIP},
	]:
		var entry := NucleusPlacementVariant3D.new()
		entry.variant_id = option["id"]
		entry.scene = option["scene"]
		catalog.variants.append(entry)
	return catalog


func _rotate(direction: int) -> void:
	if _session.mode == NucleusPlacementSession3D.Mode.IDLE:
		_set_toast("Empieza a colocar o editar un objeto para rotarlo.")
		return
	var error := _session.rotate_step(direction)
	if error != OK:
		_set_toast("Este objeto no se puede rotar.")


func _cancel_operation() -> void:
	if _paint_mode:
		_paint_mode = false
		_paint_toggle.set_pressed_no_signal(false)
		_brush_scene = null
		_set_toast("Pincel desactivado.")
		_update_panels()
		return
	_brush_scene = null
	if _curve_waiting_for_anchor != null:
		_curve_waiting_for_anchor = null
		_set_toast("Inicio de curva cancelado.")
	elif _chain_waiting_for_anchor != null:
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
		if valid else (
			"CALCULANDO  ·  " + _reason_text(reason)
			if reason == &"checking"
			else "BLOQUEADO  ·  " + _reason_text(reason)
		)
	)
	_status_label.add_theme_color_override(
		"font_color", Color(0.40, 0.96, 0.68) if valid else (
			Color(1.0, 0.82, 0.40) if reason == &"checking" else Color(1.0, 0.50, 0.46)
		)
	)


func _on_placement_confirmed(roots: Array[Node3D], was_edit: bool) -> void:
	if _paint_processing:
		# No per-piece history: the entire drag becomes one reversible operation.
		for root: Node3D in roots:
			var component := NucleusPlaceable3D.find_in(root)
			if component != null:
				component.stable_id = _issue_piece_id()
			_placed.append(root)
		_paint_accepted += roots.size()
		_paint_processing = false
		# Avoid serializing the full world after each brush stamp.
		return
	var duplicated := _pending_duplicate
	_pending_duplicate = false
	var resume: PackedScene = (
		_brush_scene if not was_edit
		and _session.mode == NucleusPlacementSession3D.Mode.IDLE else null
	)
	var before := _before_edit_document if was_edit else _capture_document()
	if not was_edit:
		for root: Node3D in roots:
			var p := NucleusPlaceable3D.find_in(root)
			if p != null:
				p.stable_id = _issue_piece_id()
			_placed.append(root)
	_before_edit_document = {}
	_selected_items.clear()
	for root: Node3D in roots:
		var p := NucleusPlaceable3D.find_in(root)
		if p != null:
			_selected_items.append(p)
	_selected = _selected_items.back() if not _selected_items.is_empty() else null
	_update_marker()
	var action: StringName = &"transform" if was_edit else (
		&"duplicate" if duplicated else &"place"
	)
	_record_action(before, action)
	var message := "Modificacion confirmada."
	if not was_edit:
		var detail := "Puedes editarlas."
		if resume != null and _repeat_placement:
			detail = "Continua colocando; Esc selecciona."
		message = "%d pieza(s) colocada(s). %s" % [roots.size(), detail]
	_set_toast(message)
	_update_panels()
	if resume != null and _repeat_placement:
		call_deferred("_resume_brush", resume)


func _on_placement_cancelled(was_edit: bool) -> void:
	_pending_duplicate = false
	_before_edit_document = {}
	_set_toast("Edicion revertida." if was_edit else "Colocacion cancelada.")
	_update_panels()


func _on_placement_rejected(reason: StringName) -> void:
	if _paint_processing:
		_paint_rejected += 1
		_paint_processing = false
		_session.cancel()
		return
	_set_toast("Operación rechazada: " + _reason_text(reason))


func _on_removal_requested(root: Node3D) -> void:
	# Demo-only mutation: production games own permissions, saves and authority.
	if root == null or not is_instance_valid(root) or root not in _placed:
		return
	_placed.erase(root)
	for p: NucleusPlaceable3D in _selected_items.duplicate():
		if p.get_root() == root:
			_selected_items.erase(p)
	_selected = _selected_items.back() if not _selected_items.is_empty() else null
	root.free()
	_update_marker()
	_set_toast("Pieza retirada del laboratorio.")
	_update_panels()


func _set_selected(placeable: NucleusPlaceable3D) -> void:
	_selected_items.clear()
	if placeable != null and is_instance_valid(placeable):
		_selected_items.append(placeable)
	_selected = placeable if is_instance_valid(placeable) else null
	_update_marker()
	_update_panels()


func _update_marker() -> void:
	if _selected_marker == null:
		return
	var visible := (_session == null or _session.mode == NucleusPlacementSession3D.Mode.IDLE)
	while _extra_selection_markers.size() + 1 < _selected_items.size():
		var new_marker := MeshInstance3D.new()
		new_marker.mesh = _selected_marker.mesh
		new_marker.material_override = _selected_marker.material_override
		_world.add_child(new_marker)
		_extra_selection_markers.append(new_marker)
	var markers: Array[MeshInstance3D] = []
	markers.append(_selected_marker)
	markers.append_array(_extra_selection_markers)
	for index: int in range(markers.size()):
		var marker := markers[index]
		marker.visible = visible and index < _selected_items.size()
		if not marker.visible:
			continue
		var component: NucleusPlaceable3D = _selected_items[index]
		if component == null or not is_instance_valid(component) or not component.is_inside_tree():
			marker.visible = false
			continue
		var root := component.get_root()
		marker.global_position = root.global_position + Vector3(0.0, 0.09, 0.0)
		var extent: Vector2 = component.profile.support_half_extents
		var size: float = maxf(extent.x, extent.y) + 0.33
		marker.scale = Vector3(size, 1.0, size)


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
	if _paint_mode:
		active = "Pincel: %d / %d candidatos" % [_paint_tool.get_count(), _paint_stroke_limit]
	elif _curve_waiting_for_anchor != null:
		active = "Curva: elegir inicio"
	elif _chain_waiting_for_anchor != null:
		active = "Cadena: elegir inicio"
	elif _session != null:
		match _session.mode:
			NucleusPlacementSession3D.Mode.SINGLE:
				active = "Colocacion individual"
			NucleusPlacementSession3D.Mode.CHAIN:
				active = "Cadena de vallas"
			NucleusPlacementSession3D.Mode.EDIT:
				active = "Editar objeto existente"
			NucleusPlacementSession3D.Mode.PATH:
				active = "Cadena CURVA: puntos de control"
			NucleusPlacementSession3D.Mode.EDIT_GROUP:
				active = "Editar grupo"
			NucleusPlacementSession3D.Mode.DUPLICATE:
				active = "Duplicar objeto (previsualizar)"
			NucleusPlacementSession3D.Mode.DUPLICATE_GROUP:
				active = "Duplicar grupo (previsualizar)"
	_mode_label.text = "MODO  /  " + active
	if _snap_label != null and _session != null:
		var effective := _session.get_snap_settings()
		if _session.mode == NucleusPlacementSession3D.Mode.IDLE:
			if _selected != null and is_instance_valid(_selected):
				effective = _session.get_snap_settings(_selected.profile)
		var active_snap: bool = bool(effective.get("enabled", false))
		var grid: Vector2 = effective.get("step", Vector2.ONE)
		var source := str(effective.get("source", &"session"))
		var author := "asset" if source in ["asset", "asset_off", "legacy_asset"] else (
			"rejilla de asset" if source == "asset_grid" else "sesion"
		)
		if source == "free_override":
			author = "LIBRE (forzado por el usuario)"
		_snap_label.text = "SNAP EFECTIVO: %s  |  X/Z %.2f / %.2f  |  %s" % [
			"ON" if active_snap else "OFF", grid.x, grid.y, author,
		]
	var selected_name := "Ninguna"
	if _selected != null and is_instance_valid(_selected):
		selected_name = str(_selected.profile.kind).capitalize()
	_selection_label.text = (
		"Seleccionados: %d  |  Ultimo: %s" % [_selected_items.size(), selected_name]
	)
	var kept := 0
	for root: Node3D in _placed:
		if is_instance_valid(root):
			kept += 1
	var has_save := NucleusSave.is_initialized() and _slot_id() in NucleusSave.list_slots()
	var dirty := not has_save or _capture_document() != _saved_document
	_info_label.text = "Mundo %d | Piezas: %d | Undo: %d Redo: %d | %s" % [
		_active_world_slot, kept, _history.undo_count(), _history.redo_count(),
		"SIN GUARDAR" if dirty else "GUARDADO",
	]
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
	grid.visible = false  # A free cursor should not look grid-locked.
	_visual_grid = grid
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
	_marquee = ColorRect.new()
	_marquee.name = "Marquee multiseleccion"
	_marquee.color = Color(0.35, 0.73, 1.0, 0.18)
	_marquee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marquee.visible = false
	root.add_child(_marquee)

	var left := _panel()
	left.offset_left = 16.0
	left.offset_top = 15.0
	left.offset_right = 322.0
	left.anchor_bottom = 1.0
	left.offset_bottom = -87.0
	root.add_child(left)
	var scrolling := ScrollContainer.new()
	scrolling.name = "Herramientas desplazables"
	scrolling.custom_minimum_size = Vector2(280.0, 0.0)
	scrolling.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scrolling)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 7)
	scrolling.add_child(stack)
	_add_label(stack, "NUCLEUS  /  PLACEMENT LAB", 18, Color(0.85, 0.96, 1.0))
	_add_label(stack, "Geometria de prueba · Godot 4", 12, Color(0.70, 0.81, 0.88))
	_add_label(stack, "CREAR PIEZA", 14, Color(0.42, 0.92, 0.78))
	for index: int in range(SCENES.size()):
		var idx := index
		_add_button(stack, "%d   %s" % [index + 1, NAMES[index]], func() -> void: _select_asset(idx))
	_add_button(stack, "F   Valla recta (2 clics)", _select_chain)
	_add_button(stack, "C   Valla CURVA (puntos)", _select_curve)
	_add_label(stack, "PINCEL DE OBJETOS (RUNTIME)", 14, Color(0.42, 0.92, 0.78))
	_paint_toggle = CheckButton.new()
	_paint_toggle.name = "PaintModeToggle"
	_paint_toggle.text = "P   Pintar arrastrando clic izq."
	_paint_toggle.toggled.connect(func(pressed: bool) -> void:
		if _paint_mode != pressed:
			_toggle_paint_mode())
	stack.add_child(_paint_toggle)
	var paint_spacing := OptionButton.new()
	paint_spacing.name = "PaintSpacing"
	for distance: float in [0.8, 1.5, 2.5, 4.0]:
		paint_spacing.add_item("Separación: %.1f m" % distance)
	paint_spacing.select(1)
	paint_spacing.item_selected.connect(func(index: int) -> void:
		_paint_spacing = [0.8, 1.5, 2.5, 4.0][index])
	stack.add_child(paint_spacing)
	var paint_radius := OptionButton.new()
	paint_radius.name = "PaintRadius"
	for radius: float in [0.0, 0.5, 1.0, 2.0]:
		paint_radius.add_item("Dispersión: %.1f m" % radius)
	paint_radius.select(0)
	paint_radius.item_selected.connect(func(index: int) -> void:
		_paint_radius = [0.0, 0.5, 1.0, 2.0][index])
	stack.add_child(paint_radius)
	_add_button(stack, "Curva: colocar (clic izq.)", _finish_curve)
	_repeat_toggle = CheckButton.new()
	_repeat_toggle.name = "RepeatPlacement"
	_repeat_toggle.text = "B   Repetir tras colocar"
	_repeat_toggle.button_pressed = _repeat_placement
	_repeat_toggle.toggled.connect(func(value: bool) -> void:
		if _repeat_placement != value:
			_toggle_repeat_placement())
	stack.add_child(_repeat_toggle)
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
	_rotation_toggle = CheckButton.new()
	_rotation_toggle.name = "FreeRotationToggle"
	_rotation_toggle.text = "T   Rotacion libre (mantener Q/R)"
	_rotation_toggle.toggled.connect(func(value: bool) -> void:
		if _free_rotation != value:
			_toggle_rotation_mode())
	stack.add_child(_rotation_toggle)
	var variants_row := HBoxContainer.new()
	stack.add_child(variants_row)
	_add_button(variants_row, "X  Tejado anterior", func() -> void: _cycle_roof(-1), true)
	_add_button(variants_row, "V  Tejado siguiente", func() -> void: _cycle_roof(1), true)
	_add_button(stack, "Ctrl+A   Seleccionar todo", _select_all)
	var edit_tools := HBoxContainer.new()
	stack.add_child(edit_tools)
	_add_button(edit_tools, "Ctrl+C  Copiar", _copy_selection, true)
	_add_button(edit_tools, "Ctrl+V  Pegar", _paste_selection, true)
	_add_button(stack, "Ctrl+D   Duplicar seleccion", _duplicate_selection)
	var undo_tools := HBoxContainer.new()
	stack.add_child(undo_tools)
	_add_button(undo_tools, "Ctrl+Z  Deshacer", _undo, true)
	_add_button(undo_tools, "Ctrl+Y  Rehacer", _redo, true)
	_add_label(stack, "MUNDO / PERSISTENCIA", 14, Color(0.42, 0.92, 0.78))
	var slot_picker := OptionButton.new()
	slot_picker.name = "WorldSlot"
	for slot: int in range(1, WORLD_SLOT_COUNT + 1):
		slot_picker.add_item("Mundo %d" % slot)
	slot_picker.select(0)
	slot_picker.item_selected.connect(_select_world_slot)
	stack.add_child(slot_picker)
	var save_tools := HBoxContainer.new()
	stack.add_child(save_tools)
	_add_button(save_tools, "Ctrl+S  Guardar", _save_world, true)
	_add_button(save_tools, "Ctrl+O  Cargar", func() -> void: _confirm_world_replacement(false), true)
	_add_button(stack, "Ctrl+N   Nuevo mundo vacio", func() -> void: _confirm_world_replacement(true))
	_add_button(stack, "Esc   Cancelar / Revertir", _cancel_operation)
	_add_label(
		stack,
		"Raton derecho: orbitar (en curva: nuevo giro)\n"
		+ "Alt+derecho: orbitar curva · Rueda: zoom\n"
		+ "Raton central: mover · WASD: desplazar\n"
		+ "Ctrl+clic: sumar/quitar seleccion\n"
		+ "Mayus+arrastrar: seleccionar por marco\n"
		+ "Curva: izq.=colocar, der.=giro, Retroceso=deshacer\n"
		+ "G: libre absoluto / snap por asset\n"
		+ "T: giro libre; mantener Q/R · V/X: tejado siguiente/anterior\n"
		+ "P: pincel para pintar piezas arrastrando (max. 64)\n"
		+ "Ctrl+C/V/D: copiar, pegar, duplicar\n"
		+ "Ctrl+Z/Y: deshacer/rehacer\n"
		+ "Ctrl+S/O/N: guardar/cargar/nuevo\n"
		+ "H/J/K: pendientes / plano",
		12, Color(0.69, 0.81, 0.89),
	)

	var right := _panel()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -388.0
	right.offset_top = 15.0
	right.offset_right = -16.0
	right.offset_bottom = 278.0
	root.add_child(right)
	var right_stack := VBoxContainer.new()
	right_stack.add_theme_constant_override("separation", 7)
	right.add_child(right_stack)
	_mode_label = _add_label(right_stack, "MODO  /  Exploracion", 14, Color(0.90, 0.96, 1.0))
	_status_label = _add_label(right_stack, "LISTO", 12, Color(0.50, 0.89, 0.75))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label = _add_label(right_stack, "Colocados: 0", 12, Color(0.69, 0.82, 0.92))
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var snap_heading := _add_label(
		right_stack, "AJUSTE DE CUADRICULA", 12, Color(0.42, 0.92, 0.78),
	)
	snap_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_snap_toggle = CheckButton.new()
	_snap_toggle.name = "SnapGlobal"
	_snap_toggle.text = "G  Snap ON / OFF = libre"
	right_stack.add_child(_snap_toggle)
	_snap_toggle.toggled.connect(func(_pressed: bool) -> void: _toggle_default_snap())
	_snap_steps = OptionButton.new()
	_snap_steps.name = "SnapStep"
	_snap_steps.add_item("Paso global: 0,5 m")
	_snap_steps.add_item("Paso global: 1 m")
	_snap_steps.add_item("Paso global: 2 m")
	_snap_steps.select(1)
	_snap_steps.item_selected.connect(_set_snap_step)
	right_stack.add_child(_snap_steps)
	_snap_label = _add_label(right_stack, "SNAP EFECTIVO: OFF", 11, Color(0.81, 0.89, 0.96))
	_snap_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

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
	_confirmation = ConfirmationDialog.new()
	_confirmation.name = "Confirmar sustitucion de mundo"
	_confirmation.title = "Placement Lab"
	layer.add_child(_confirmation)


func _slot_path() -> String:
	return WORLD_SAVE_PREFIX + "%d.json" % _active_world_slot


func _slot_id() -> String:
	return "placement_lab_world_%d" % _active_world_slot



func _select_world_slot(index: int) -> void:
	if index < 0 or index >= WORLD_SLOT_COUNT:
		return
	_active_world_slot = index + 1
	_saved_document = _slot_documents.get(_active_world_slot, {})
	_update_panels()
	_set_toast("Ranura Mundo %d. Guardar y cargar afectan solo esta ranura." % _active_world_slot)


## Prevent the authoring demo from growing past its bounded save/history limits.
func _admit_placement(
	transforms: Array[Transform3D],
	_components: Array[NucleusPlaceable3D],
) -> Error:
	if _session.mode in [
		NucleusPlacementSession3D.Mode.EDIT,
		NucleusPlacementSession3D.Mode.EDIT_GROUP,
	]:
		return OK
	if _placed.size() + transforms.size() > WORLD_DOCUMENT.MAX_PIECES:
		return ERR_OUT_OF_MEMORY
	return OK


## Keep the document authoring policy local to the example, not Nucleus core.
func _capture_document() -> Dictionary:
	return WORLD_DOCUMENT.capture(_placed)


func _issue_piece_id() -> StringName:
	var id := StringName("p_%d" % _next_piece_id)
	_next_piece_id += 1
	return id


func _record_action(before: Dictionary, label: StringName) -> void:
	var after := _capture_document()
	if before.is_empty() or before == after:
		_update_panels()
		return
	var error := _history.record(before, after, label)
	if error != OK:
		# Do not keep mutations that cannot be represented in undo history.
		var restore_error := _restore_document(before)
		_set_toast("Historial lleno/invalido; cambio revertido: %s / %s" % [
			error_string(error), error_string(restore_error),
		])
	_update_panels()


## Stage every PackedScene BEFORE destroying the old world. No partial restore.
func _restore_document(document: Dictionary) -> Error:
	if _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		return ERR_BUSY
	var staged: Dictionary = WORLD_DOCUMENT.instantiate_validated(document, _catalog)
	if int(staged.get("error", ERR_INVALID_DATA)) != OK:
		return ERR_INVALID_DATA
	var roots: Array[Node3D] = staged["roots"]
	_set_selected(null)
	for existing: Node3D in _placed:
		if is_instance_valid(existing):
			existing.free()
	_placed.clear()
	var maximum_id := _next_piece_id - 1
	for instance: Node3D in roots:
		_world.add_child(instance)
		_placed.append(instance)
		var component := NucleusPlaceable3D.find_in(instance)
		var n: int = str(component.stable_id).substr(2).to_int()
		maximum_id = maxi(maximum_id, n)
	_next_piece_id = maximum_id + 1
	_update_marker()
	_update_panels()
	return OK


func _suspend_brush_for_command() -> void:
	# Saving and history commands should not require an extra Esc while the
	# repeat brush is active. Preview instances are never part of the document.
	if _session.mode != NucleusPlacementSession3D.Mode.SINGLE or _brush_scene == null:
		return
	var brush := _brush_scene
	_session.cancel()
	call_deferred("_resume_brush", brush)


func _undo() -> void:
	_suspend_brush_for_command()
	if _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		_set_toast("Finaliza o cancela el placement antes de deshacer.")
		return
	var preview := _history.peek_undo()
	if preview.is_empty():
		_set_toast("No hay acciones anteriores.")
		return
	var error := _restore_document(preview["snapshot"])
	if error != OK:
		_history.cancel_preview()
		_set_toast("Restauracion rechazada: " + error_string(error))
		return
	var confirmed := _history.confirm_undo(int(preview["ticket"]))
	_set_toast("Deshecho: %s" % str(preview["label"]) if confirmed == OK
		else "No se pudo confirmar el deshacer.")
	_update_panels()


func _redo() -> void:
	_suspend_brush_for_command()
	if _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		_set_toast("Finaliza o cancela el placement antes de rehacer.")
		return
	var preview := _history.peek_redo()
	if preview.is_empty():
		_set_toast("No hay acciones para rehacer.")
		return
	var error := _restore_document(preview["snapshot"])
	if error != OK:
		_history.cancel_preview()
		_set_toast("Restauracion rechazada: " + error_string(error))
		return
	var confirmed := _history.confirm_redo(int(preview["ticket"]))
	_set_toast("Rehecho: %s" % str(preview["label"]) if confirmed == OK
		else "No se pudo confirmar el rehacer.")
	_update_panels()


func _duplicate_selection() -> void:
	if _selected_items.is_empty():
		_set_toast("Selecciona objetos antes de duplicar.")
		return
	_copy_selection()
	if not _clipboard.is_empty():
		_paste_selection()


func _copy_selection() -> void:
	if _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		_set_toast("Termina primero el placement activo.")
		return
	var roots: Array[Node3D] = []
	for p: NucleusPlaceable3D in _selected_items:
		if is_instance_valid(p) and is_instance_valid(p.get_root()):
			roots.append(p.get_root())
	if roots.is_empty():
		_clipboard = {}
		_set_toast("Selecciona objetos antes de copiar.")
		return
	if roots.size() > MAX_DUPLICATE_GROUP:
		_clipboard = {}
		_set_toast("Copia limitada a %d piezas por operacion." % MAX_DUPLICATE_GROUP)
		return
	_clipboard = WORLD_DOCUMENT.capture(roots)
	_set_toast("Copiados %d objeto(s). Ctrl+V para pegar con validacion." % roots.size())


## Copy/paste/duplicate begins a movable *preview*, never immediately creates
## live pieces. The player positions and confirms the complete group at the
## cursor. No IDs/history are committed until placement_confirmed is emitted.
func _paste_selection() -> void:
	if _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		_set_toast("Termina primero el placement activo.")
		return
	if _clipboard.is_empty():
		_set_toast("El portapapeles interno esta vacio (Ctrl+C).")
		return
	var checked: Dictionary = WORLD_DOCUMENT.validate(_clipboard, _catalog)
	if int(checked.get("error", ERR_INVALID_DATA)) != OK:
		_set_toast("Copia invalida: " + str(checked.get("message", "")))
		return
	var entries: Array[Dictionary] = checked["objects"]
	if entries.is_empty() or entries.size() > MAX_DUPLICATE_GROUP:
		return
	if _placed.size() + entries.size() > WORLD_DOCUMENT.MAX_PIECES:
		_set_toast("Limite de piezas del laboratorio alcanzado.")
		return
	var staged := WORLD_DOCUMENT.instantiate_validated(_clipboard, _catalog)
	if int(staged.get("error", ERR_INVALID_DATA)) != OK:
		_set_toast("No se pudieron preparar las copias.")
		return
	var roots: Array[Node3D] = staged["roots"]
	for root: Node3D in roots:
		var component := NucleusPlaceable3D.find_in(root)
		component.stable_id = &""  # New identity only on commit.
	var result := _session.begin_duplicate(roots)
	if result != OK:
		for root: Node3D in roots:
			root.free()
		_set_toast("Duplicacion rechazada: " + error_string(result))
		return
	_brush_scene = null
	_pending_duplicate = true
	_set_selected(null)
	_session.update_from_screen(get_viewport().get_mouse_position())
	_set_toast("Copias flotantes: mueve el raton, Q/R rota, clic confirma, Esc cancela.")
	_update_panels()


func _save_world() -> void:
	_suspend_brush_for_command()
	if _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		_set_toast("Confirma o cancela antes de guardar.")
		return
	var document := _capture_document()
	var checked := WORLD_DOCUMENT.validate(document, _catalog)
	if int(checked["error"]) != OK:
		_set_toast("No se puede guardar: " + str(checked["message"]))
		return
	if JSON.stringify(document).to_utf8_buffer().size() > WORLD_DOCUMENT.MAX_FILE_BYTES:
		_set_toast("El mundo supera el limite de archivo del lab.")
		return
	var result := NucleusSave.save_manual(
		_slot_id(), {"world": document}, {"purpose": "placement_lab"},
	)
	if not result.succeeded():
		_set_toast("Fallo al guardar con NucleusSave: " + error_string(result.error))
		return
	_saved_document = document.duplicate(true)
	_slot_documents[_active_world_slot] = _saved_document.duplicate(true)
	_set_toast("Mundo %d guardado con NucleusSave (integridad + backups)." % _active_world_slot)
	_update_panels()


func _confirm_world_replacement(new_world: bool) -> void:
	if _session.mode != NucleusPlacementSession3D.Mode.IDLE:
		_set_toast("Finaliza primero la operacion en curso.")
		return
	_confirmation.dialog_text = (
		"¿Crear un mundo vacio? Los cambios no guardados se perderan."
		if new_world else
		"¿Cargar el mundo guardado? El mundo actual se sustituira."
	)
	var method: Callable = _new_world if new_world else _load_world
	for callback: Dictionary in _confirmation.confirmed.get_connections():
		_confirmation.confirmed.disconnect(callback["callable"])
	_confirmation.confirmed.connect(method, CONNECT_ONE_SHOT)
	_confirmation.popup_centered()


func _new_world() -> void:
	var before := _capture_document()
	var empty := {"schema_version": 1, "objects": []}
	var error := _restore_document(empty)
	if error == OK:
		_record_action(before, &"clear_world")
		_set_toast("Nuevo mundo vacio. Ctrl+Z recupera el anterior.")


func _load_world() -> void:
	var result := NucleusSave.load_manual(_slot_id())
	var document: Variant = null
	var from_legacy := false
	if result.succeeded() and result.document != null:
		document = result.document.payload.get("world")
	elif result.error == ERR_FILE_NOT_FOUND and FileAccess.file_exists(_slot_path()):
		# Previous lab iteration used a standalone JSON file. Import only a
		# bounded, schema-validated local document; never load resource paths.
		var size := FileAccess.get_size(_slot_path())
		if size < 0 or size > WORLD_DOCUMENT.MAX_FILE_BYTES:
			_set_toast("El JSON antiguo es demasiado grande.")
			return
		var file := FileAccess.open(_slot_path(), FileAccess.READ)
		if file == null:
			_set_toast("No se puede leer el JSON antiguo.")
			return
		document = JSON.parse_string(file.get_buffer(size).get_string_from_utf8())
		file.close()
		from_legacy = true
	else:
		_set_toast("No se pudo cargar NucleusSave: " + error_string(result.error))
		return
	var checked := WORLD_DOCUMENT.validate(document, _catalog)
	if int(checked.get("error", ERR_INVALID_DATA)) != OK:
		_set_toast("Carga rechazada: " + str(checked["message"]))
		return
	var before := _capture_document()
	var error := _restore_document(document)
	if error != OK:
		_set_toast("Error cargando mundo: " + error_string(error))
		return
	_record_action(before, &"load_world")
	_saved_document = _capture_document()
	_slot_documents[_active_world_slot] = _saved_document.duplicate(true)
	_set_toast("Importado JSON antiguo: pulsa Ctrl+S para migrarlo a NucleusSave."
		if from_legacy else "Mundo %d cargado mediante NucleusSave." % _active_world_slot)
	_update_panels()


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
