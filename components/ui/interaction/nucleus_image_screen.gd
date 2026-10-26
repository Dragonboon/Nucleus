@tool
extends Control
class_name NucleusImageScreen

## Scene-owned image interaction; assign images/hotspots from the consuming game.
signal hotspot_activated(id: StringName, destination: StringName)
signal background_activated(image_point: Vector2)
signal screen_changed(id: StringName)
signal invalid_screen_requested(id: StringName)
signal hotspot_focus_changed(id: StringName)

@export var screen_id: StringName
@export var background: Texture2D:
	set(value):
		background = value
		queue_redraw()
@export var hotspots: Array[NucleusScreenHotspot] = []
@export var preserve_aspect := true
@export var consume_background_clicks := true
@export var interaction_enabled := true
@export_range(0.0, 0.25, 0.001) var tap_slop_normalized := 0.02

var focused_hotspot: StringName
var _pressed_id: StringName
var _press_point := Vector2.ZERO
var _is_pressed := false
var _dispatching := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	resized.connect(queue_redraw)


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
	if not area.has_area() or not area.has_point(local_point):
		return Vector2(-1.0, -1.0)
	return (local_point - area.position) / area.size


func hotspot_at(point: Vector2) -> NucleusScreenHotspot:
	if point.x < 0 or point.y < 0 or point.x > 1 or point.y > 1:
		return null
	var selected: NucleusScreenHotspot
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
		focused_hotspot = &""
		return focused_hotspot
	var index := available.find(focused_hotspot)
	focused_hotspot = available[posmod(index + step, available.size())]
	hotspot_focus_changed.emit(focused_hotspot)
	queue_redraw()
	return focused_hotspot


func activate_focused() -> Error:
	if focused_hotspot == &"":
		focus_next()
	if focused_hotspot == &"":
		return ERR_DOES_NOT_EXIST
	return activate(focused_hotspot)


func _unhandled_key_input(event: InputEvent) -> void:
	if not has_focus() or not interaction_enabled or Engine.is_editor_hint():
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		focus_next(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		focus_next(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		activate_focused()
		get_viewport().set_input_as_handled()


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
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_begin_press(mouse.position)
		else:
			_finish_press(mouse.position)
		accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index != 0:
			return
		if touch.pressed:
			_begin_press(touch.position)
		else:
			_finish_press(touch.position)
		accept_event()
	elif event.is_action_pressed("ui_cancel"):
		_cancel_press()
		accept_event()


func _begin_press(local_point: Vector2) -> void:
	_cancel_press()
	var point := normalized_point(local_point)
	if point.x < 0:
		return
	_is_pressed = true
	_press_point = point
	var target := hotspot_at(point)
	_pressed_id = target.id if target != null else &""


func _finish_press(local_point: Vector2) -> void:
	if not _is_pressed:
		return
	var previous_id := _pressed_id
	var original_point := _press_point
	_cancel_press()
	var point := normalized_point(local_point)
	if point.x < 0 or point.distance_to(original_point) > tap_slop_normalized:
		return
	var target := hotspot_at(point)
	if previous_id != &"":
		if target != null and target.id == previous_id:
			activate(previous_id)
	elif target == null and consume_background_clicks:
		background_activated.emit(point)


func _cancel_press() -> void:
	_is_pressed = false
	_pressed_id = &""


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
