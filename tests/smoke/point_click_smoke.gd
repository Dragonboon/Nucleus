extends Node
## Real GUI dispatch in an isolated viewport, with addon-owned page/input components.

const FIXTURE := preload("res://tests/fixtures/point_click/navigation.tscn")

var _failures := 0
var _checks := 0
var _viewport: SubViewport
var _screen: NucleusImageScreen
var _session: NucleusAdventureSession


func _ready() -> void:
	get_tree().create_timer(30.0).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("_run")


func _run() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 480)
	_viewport.handle_input_locally = true
	add_child(_viewport)
	var fixture := FIXTURE.instantiate()
	_viewport.add_child(fixture)
	_screen = fixture.get_node("Screen") as NucleusImageScreen
	_session = fixture.get_node("Session") as NucleusAdventureSession
	_check(_session.screen == _screen, "The actual session owns the actual scene screen.")
	_check(_session.validate_configuration(true).is_empty(), "Fixture has no trapped pages.")
	await get_tree().process_frame
	for dimensions in [Vector2i(640, 480), Vector2i(1280, 720), Vector2i(2560, 1080),
		Vector2i(720, 1280), Vector2i(480, 320), Vector2i(3840, 2160)]:
		_viewport.size = dimensions
		await get_tree().process_frame
		_session.change_page(&"room")
		_click(Vector2(0.3, 0.3))
		_check(_session.current_page == &"detail", "Mouse opens detail at %s." % dimensions)
		_click(Vector2(0.5, 0.975))
		_check(_session.current_page == &"room", "Back edge returns at %s." % dimensions)
		_touch(Vector2(0.3, 0.3), true, 4)
		_touch(Vector2(0.3, 0.3), false, 4)
		_check(_session.current_page == &"detail", "Native touch opens detail at %s." % dimensions)
		_session.go_back()
		var bars := _screen.image_rect()
		if bars.position.x > 0 or bars.position.y > 0:
			_mouse_local(Vector2.ONE, true)
			_mouse_local(Vector2.ONE, false)
			_check(_session.current_page == &"room", "Letterbox is inert at %s." % dimensions)
	# Lifecycle/layout changes cancel a held click before release.
	var original_size := _screen.size
	_mouse_local(_screen.image_local_point(Vector2(0.3, 0.3)), true)
	_screen.size += Vector2(2, 0)
	_mouse_local(_screen.image_local_point(Vector2(0.3, 0.3)), false)
	_check(_session.current_page == &"room", "Resize cancels a held gesture.")
	_screen.size = original_size
	_mouse_local(_screen.image_local_point(Vector2(0.3, 0.3)), true)
	_screen.hide()
	_screen.show()
	_mouse_local(_screen.image_local_point(Vector2(0.3, 0.3)), false)
	_check(_session.current_page == &"room", "Hide/show cancels a held gesture.")
	_mouse_local(_screen.image_local_point(Vector2(0.3, 0.3)), true)
	_screen.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_mouse_local(_screen.image_local_point(Vector2(0.3, 0.3)), false)
	_check(_session.current_page == &"room", "Application focus loss cancels a held gesture.")
	# Coordinate ownership survives the same canvas transform used for camera breathing.
	_screen.position += Vector2(15, 11)
	_screen.scale = Vector2(1.03, 1.03)
	_click(Vector2(0.3, 0.3))
	_check(_session.current_page == &"detail", "Zoomed/translated image remains aligned.")
	var expected := Vector2(0.3, 0.3)
	var mapped := _screen.normalized_viewport_point(_viewport_point(expected))
	_check(mapped.is_equal_approx(expected), "Viewport helper is the inverse of image mapping.")
	_session.go_back()
	# A small target and substantial transform expose incorrect viewport/local conversions.
	var object_region: NucleusScreenHotspot = _session.pages[0].hotspots[0]
	var original_bounds := object_region.bounds
	object_region.bounds = Rect2(0.28, 0.28, 0.04, 0.04)
	_screen.position = Vector2(100, 80)
	_screen.scale = Vector2(0.65, 0.65)
	_click(Vector2(0.3, 0.3))
	_check(_session.current_page == &"detail", "Mouse hits a small transformed target.")
	_session.go_back()
	_touch(Vector2(0.3, 0.3), true, 4)
	_touch(Vector2(0.3, 0.3), false, 4)
	_check(_session.current_page == &"detail", "Touch hits the same small transformed target.")
	_session.go_back()
	object_region.bounds = original_bounds
	_screen.position = Vector2(15, 11)
	_screen.scale = Vector2(1.03, 1.03)
	# Native canceled touch and secondary fingers cannot complete a gesture.
	_touch(Vector2(0.3, 0.3), true, 4)
	_touch(Vector2(0.3, 0.3), false, 5)
	_check(_session.current_page == &"room", "Secondary touch release is ignored.")
	_touch(Vector2(0.3, 0.3), false, 4, true)
	_check(_session.current_page == &"room", "Canceled native touch cannot activate.")
	_touch(Vector2(0.3, 0.3), true, 4)
	var drag := InputEventScreenDrag.new()
	drag.index = 4
	drag.position = _viewport_point(Vector2(0.8, 0.7))
	_viewport.push_input(drag, true)
	_touch(Vector2(0.3, 0.3), false, 4)
	_check(_session.current_page == &"room", "Drag out and back never becomes a tap.")
	# Input emulation must not cause a second world activation.
	_mouse_local(_screen.image_local_point(Vector2(0.3, 0.3)), true, true)
	_mouse_local(_screen.image_local_point(Vector2(0.3, 0.3)), false, true)
	_check(_session.current_page == &"room", "Emulated pointer duplicate is ignored.")
	# A game-owned modal barrier and interaction gate prevent click-through/stale release.
	_mouse_local(_screen.image_local_point(Vector2(0.3, 0.3)), true)
	_screen.interaction_enabled = false
	var modal := fixture.get_node("HUD/Modal") as Control
	modal.show()
	_mouse_local(_screen.image_local_point(Vector2(0.3, 0.3)), false)
	modal.hide()
	_screen.interaction_enabled = true
	_mouse_local(_screen.image_local_point(Vector2(0.3, 0.3)), false)
	_check(_session.current_page == &"room", "Opening/closing modal cannot revive a press.")
	_screen.grab_focus()
	_joy(JOY_BUTTON_DPAD_RIGHT)
	_check(_screen.focused_hotspot == &"inspect", "Joypad reaches semantic hotspot focus.")
	_joy(JOY_BUTTON_A)
	_check(_session.current_page == &"detail", "Joypad activates the focused hotspot.")
	_screen.grab_focus()
	_joy(JOY_BUTTON_DPAD_RIGHT)
	_joy(JOY_BUTTON_A)
	_check(_session.current_page == &"room", "Joypad activates the explicit back edge.")
	# Re-entering the tree reconnects the same owner without duplicate activation.
	fixture.remove_child(_session)
	_check(not _screen.hotspot_activated.is_connected(_session._on_hotspot),
		"Detached session does not receive screen events.")
	fixture.add_child(_session)
	_click(Vector2(0.3, 0.3))
	_check(_session.current_page == &"detail", "Re-entered session reconnects without request_ready.")
	_viewport.free()
	print("Point-click GUI smoke: %d checks, %d failures." % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _viewport_point(point: Vector2) -> Vector2:
	return _screen.get_global_transform_with_canvas() * _screen.image_local_point(point)


func _click(point: Vector2) -> void:
	_mouse_local(_screen.image_local_point(point), true)
	_mouse_local(_screen.image_local_point(point), false)


func _mouse_local(local_point: Vector2, pressed: bool, emulated: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = _screen.get_global_transform_with_canvas() * local_point
	event.global_position = event.position
	if emulated:
		event.device = InputEvent.DEVICE_ID_EMULATION
	_viewport.push_input(event, true)


func _touch(point: Vector2, pressed: bool, index: int, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = _viewport_point(point)
	event.pressed = pressed
	event.index = index
	event.canceled = canceled
	_viewport.push_input(event, true)


func _joy(button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	_viewport.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	_viewport.push_input(event, true)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
