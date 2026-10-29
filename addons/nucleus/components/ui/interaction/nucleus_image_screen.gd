@tool
extends Control
class_name NucleusImageScreen

## Scene-owned image interaction; assign images/hotspots from the consuming game.
signal hotspot_activated(id: StringName, destination: StringName)
signal background_activated(image_point: Vector2)
signal screen_changed(id: StringName)
signal invalid_screen_requested(id: StringName)
signal hotspot_focus_changed(id: StringName)

@export var screen_id: StringName:
	set(value):
		if screen_id != value:
			_cancel_press()
		screen_id = value
@export var background: Texture2D:
	set(value):
		_cancel_press()
		background = value
		queue_redraw()
@export var hotspots: Array[NucleusScreenHotspot] = []:
	set(value):
		_cancel_press()
		hotspots = value
		_clear_focus()
@export var preserve_aspect := true:
	set(value):
		_cancel_press()
		preserve_aspect = value
		queue_redraw()
@export var consume_background_clicks := true
@export var interaction_enabled := true:
	set(value):
		interaction_enabled = value
		if not value:
			_cancel_press()
@export_range(0.0, 0.25, 0.001) var tap_slop_normalized := 0.02

var focused_hotspot: StringName
var _pressed_id: StringName
var _press_point := Vector2.ZERO
var _is_pressed := false
var _dispatching := false
var _press_screen: StringName
var _pointer_index := -2
var _pressed_hotspot: NucleusScreenHotspot = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	focus_exited.connect(_cancel_press)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_RESIZED, NOTIFICATION_EXIT_TREE, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_cancel_press()
		queue_redraw()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_cancel_press()


func _clear_focus() -> void:
	if focused_hotspot != &"":
		focused_hotspot = &""
		hotspot_focus_changed.emit(&"")
	queue_redraw()


func image_rect() -> Rect2:
	var area := Rect2(Vector2.ZERO, size)
	if background == null or not preserve_aspect:
		return area
	var image_size := background.get_size()
	if image_size.x <= 0 or image_size.y <= 0 or size.x <= 0 or size.y <= 0:
		return Rect2()
	var factor: float = minf(size.x / image_size.x, size.y / image_size.y)
	var drawn := image_size * factor
	return Rect2((size - drawn) * 0.5, drawn)


func normalized_point(local_point: Vector2) -> Vector2:
	var area := image_rect()
	if not local_point.is_finite() or not area.has_area() or not area.has_point(local_point):
		return Vector2(-1.0, -1.0)
	return (local_point - area.position) / area.size


## Use for viewport events/tools; _gui_input already supplies local coordinates.
func normalized_viewport_point(viewport_point: Vector2) -> Vector2:
	var canvas_transform := get_global_transform_with_canvas()
	if not viewport_point.is_finite() or is_zero_approx(canvas_transform.determinant()):
		return Vector2(-1.0, -1.0)
	return normalized_point(canvas_transform.affine_inverse() * viewport_point)


## The inverse mapping for game-owned overlays sharing this Control's transform.
func image_local_point(point: Vector2) -> Vector2:
	var area := image_rect()
	return area.position + point * area.size


func hotspot_at(point: Vector2) -> NucleusScreenHotspot:
	if not point.is_finite() or point.x < 0 or point.y < 0 or point.x > 1 or point.y > 1:
		return null
	var selected: NucleusScreenHotspot = null
	for candidate in hotspots:
		if candidate == null or not candidate.contains_normalized(point):
			continue
		if selected == null or candidate.priority > selected.priority:
			selected = candidate
	return selected


func focus_next(step: int = 1) -> StringName:
	var available: Array[StringName] = []
	for entry in hotspots:
		if entry != null and entry.enabled and entry.is_valid_hotspot():
			available.append(entry.id)
	if available.is_empty():
		_clear_focus()
		return focused_hotspot
	var index := available.find(focused_hotspot)
	if index < 0:
		index = 0 if step >= 0 else available.size() - 1
	else:
		index = posmod(index + step, available.size())
	focused_hotspot = available[index]
	hotspot_focus_changed.emit(focused_hotspot)
	queue_redraw()
	return focused_hotspot


func activate_focused() -> Error:
	if focused_hotspot == &"":
		focus_next()
	if focused_hotspot == &"":
		return ERR_DOES_NOT_EXIST
	return activate(focused_hotspot)


func _unhandled_input(event: InputEvent) -> void:
	if _handle_navigation_input(event):
		get_viewport().set_input_as_handled()


func _handle_navigation_input(event: InputEvent) -> bool:
	if not has_focus() or not interaction_enabled or Engine.is_editor_hint():
		return false
	if event.is_action_pressed("ui_cancel"):
		_cancel_press()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		focus_next(1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		focus_next(-1)
	elif event.is_action_pressed("ui_accept"):
		activate_focused()
	else:
		return false
	return true


func activate(id: StringName) -> Error:
	if not interaction_enabled or _dispatching:
		return ERR_BUSY
	for hotspot in hotspots:
		if hotspot != null and hotspot.id == id and hotspot.enabled:
			if not hotspot.is_valid_hotspot():
				return ERR_INVALID_DATA
			_dispatching = true
			hotspot_activated.emit(id, hotspot.destination)
			_dispatching = false
			return OK
	return ERR_DOES_NOT_EXIST


func set_screen(
	id: StringName, texture: Texture2D, entries: Array[NucleusScreenHotspot]
) -> Error:
	if id.is_empty() or texture == null:
		invalid_screen_requested.emit(id)
		return ERR_INVALID_PARAMETER
	var identifiers := {}
	for item in entries:
		if item == null or not item.is_valid_hotspot() or identifiers.has(item.id):
			invalid_screen_requested.emit(id)
			return ERR_INVALID_DATA
		identifiers[item.id] = true
	_cancel_press()
	focused_hotspot = &""
	screen_id = id
	background = texture
	hotspots = entries.duplicate()
	screen_changed.emit(id)
	return OK


func _gui_input(event: InputEvent) -> void:
	if not interaction_enabled or Engine.is_editor_hint():
		_cancel_press()
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			_cancel_press()
			return
		if mouse.canceled:
			_cancel_press()
		elif mouse.pressed:
			_begin_press(mouse.position)
		else:
			_finish_press(mouse.position)
		accept_event()
	elif event is InputEventMouseMotion:
		if event.device != InputEvent.DEVICE_ID_EMULATION and _pointer_index == -1:
			_update_press((event as InputEventMouseMotion).position)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if touch.canceled:
			if _pointer_index == touch.index:
				_cancel_press()
		elif touch.pressed:
			_begin_press(touch.position, touch.index)
		else:
			_finish_press(touch.position, touch.index)
		accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.device != InputEvent.DEVICE_ID_EMULATION and _pointer_index == drag.index:
			_update_press(drag.position)
	elif _handle_navigation_input(event):
		accept_event()


func _begin_press(local_point: Vector2, pointer_index: int = -1) -> void:
	if _is_pressed or not interaction_enabled:
		return
	_cancel_press()
	var point := normalized_point(local_point)
	if point.x < 0:
		return
	_is_pressed = true
	_pointer_index = pointer_index
	_press_point = point
	_press_screen = screen_id
	var target := hotspot_at(point)
	_pressed_hotspot = target
	_pressed_id = target.id if target != null else &""


func _update_press(local_point: Vector2) -> void:
	if not _is_pressed:
		return
	var point := normalized_point(local_point)
	if point.x < 0 or point.distance_to(_press_point) > tap_slop_normalized:
		_cancel_press()


func _finish_press(local_point: Vector2, pointer_index: int = -1) -> void:
	if not _is_pressed or _pointer_index != pointer_index:
		return
	var previous_hotspot := _pressed_hotspot
	var previous_id := _pressed_id
	var original_point := _press_point
	var pressed_screen := _press_screen
	_cancel_press()
	if not interaction_enabled or pressed_screen != screen_id:
		return
	var point := normalized_point(local_point)
	if point.x < 0 or point.distance_to(original_point) > tap_slop_normalized:
		return
	var target := hotspot_at(point)
	if previous_id != &"":
		if target != null and target == previous_hotspot and target.id == previous_id:
			activate(previous_id)
	elif target == null and consume_background_clicks:
		background_activated.emit(point)


func _cancel_press() -> void:
	_is_pressed = false
	_pointer_index = -2
	_pressed_hotspot = null
	_pressed_id = &""
	_press_screen = &""


func _draw() -> void:
	if background == null:
		return
	var area := image_rect()
	if area.has_area():
		draw_texture_rect(background, area, false)
		if focused_hotspot != &"" and has_focus():
			for entry in hotspots:
				if entry != null and entry.id == focused_hotspot:
					var rect := Rect2(
						area.position + entry.bounds.position * area.size,
						entry.bounds.size * area.size
					)
					draw_rect(rect, Color(1.0, 0.9, 0.3), false, 3.0)
					break
