extends Node
## Owns cross-scene input-device state and runtime InputMap overrides.
##
## Default bindings always come from project.godot. Only user modifications are
## persisted through NucleusSettings, keeping new project actions migration-free.

signal input_source_changed(source: int, previous_source: int)
signal active_gamepad_changed(device_id: int, family: int)
signal gamepad_connected(device_id: int, device_name: String)
signal gamepad_disconnected(device_id: int, device_name: String)
signal action_binding_changed(action: StringName)
signal bindings_reset(action: StringName)

const LOG_CONTEXT: StringName = &"Input"
const MOUSE_MOTION_ACTIVITY_THRESHOLD: float = 2.0
const JOYPAD_MOTION_ACTIVITY_THRESHOLD: float = 0.55

var allow_ui_action_rebinding: bool = false

var active_source: int = NucleusInputTypes.Source.KEYBOARD_MOUSE
var active_gamepad_id: int = -1
var active_gamepad_family: int = NucleusInputTypes.GamepadFamily.GENERIC

var _default_events: Dictionary[StringName, Array] = {}
var _default_deadzones: Dictionary[StringName, float] = {}
var _binding_overrides: Dictionary = {}
var _initialized: bool = false
var _writing_settings: bool = false


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_capture_project_defaults()


func _ready() -> void:
	NucleusSettings.setting_changed.connect(_on_setting_changed)

	if NucleusSettings.is_initialized():
		_initialize()
	else:
		NucleusSettings.settings_loaded.connect(
			_initialize,
			CONNECT_ONE_SHOT,
		)


func _exit_tree() -> void:
	for device_id: int in Input.get_connected_joypads():
		Input.stop_joy_vibration(device_id)


func _input(event: InputEvent) -> void:
	var detected_source: int = _detect_meaningful_source(event)

	if detected_source == NucleusInputTypes.Source.ANY:
		return

	if detected_source == NucleusInputTypes.Source.GAMEPAD:
		_set_active_gamepad(event.device)

	_set_active_source(detected_source)


## Returns whether persisted bindings have been applied.
func is_initialized() -> bool:
	return _initialized


## Returns every currently connected gamepad device id.
func get_connected_gamepads() -> Array[int]:
	return Input.get_connected_joypads()


## Returns whether an action can be modified by the rebinding API.
func is_action_rebindable(action: StringName) -> bool:
	if not InputMap.has_action(action):
		return false

	return allow_ui_action_rebinding or not str(action).begins_with("ui_")


## Returns all actions currently exposed by the rebinding API.
func get_rebindable_actions() -> Array[StringName]:
	var actions: Array[StringName] = []

	for action: StringName in InputMap.get_actions():
		if is_action_rebindable(action):
			actions.append(action)

	return actions


## Captures defaults for actions added to InputMap after startup.
##
## Existing default snapshots are never replaced.
func refresh_actions() -> void:
	for action: StringName in InputMap.get_actions():
		if not is_action_rebindable(action):
			continue

		if _default_events.has(action):
			continue

		_capture_action_default(action)


## Returns duplicated action events filtered by input source.
func get_action_events(
	action: StringName,
	source: int = NucleusInputTypes.Source.ANY,
) -> Array[InputEvent]:
	if not InputMap.has_action(action):
		return []

	var result: Array[InputEvent] = []

	for event: InputEvent in InputMap.action_get_events(action):
		if (
			source == NucleusInputTypes.Source.ANY
			or NucleusInputBindingCodec.get_source(event) == source
		):
			result.append(_duplicate_event(event))

	return result


## Returns a short display label for one binding.
func get_binding_text(
	action: StringName,
	source: int = NucleusInputTypes.Source.ANY,
	binding_index: int = 0,
) -> String:
	var resolved_source: int = source

	if resolved_source == NucleusInputTypes.Source.ANY:
		resolved_source = active_source

	var events: Array[InputEvent] = get_action_events(
		action,
		resolved_source,
	)

	if binding_index < 0 or binding_index >= events.size():
		return ""

	return NucleusInputLabels.event_to_text(
		events[binding_index],
		active_gamepad_family,
	)


## Adds one hardware binding to an action.
func add_binding(action: StringName, event: InputEvent) -> Error:
	if not is_action_rebindable(action):
		return ERR_DOES_NOT_EXIST

	var normalized_event: InputEvent = NucleusInputBindingCodec.normalize(event)

	if normalized_event == null:
		return ERR_INVALID_PARAMETER

	for current_event: InputEvent in InputMap.action_get_events(action):
		if current_event.is_match(normalized_event, true):
			return ERR_ALREADY_EXISTS

	InputMap.action_add_event(action, normalized_event)
	_commit_action_override(action)

	return OK


## Replaces one binding slot within a specific input source.
##
## If the slot does not exist yet, the binding is appended.
func set_binding(
	action: StringName,
	source: int,
	binding_index: int,
	event: InputEvent,
) -> Error:
	if not is_action_rebindable(action):
		return ERR_DOES_NOT_EXIST

	if binding_index < 0:
		return ERR_INVALID_PARAMETER

	var normalized_event: InputEvent = NucleusInputBindingCodec.normalize(event)

	if normalized_event == null:
		return ERR_INVALID_PARAMETER

	if (
		source != NucleusInputTypes.Source.ANY
		and NucleusInputBindingCodec.get_source(normalized_event) != source
	):
		return ERR_INVALID_PARAMETER

	var current_events: Array[InputEvent] = get_action_events(action)
	var matching_indices: Array[int] = []

	for index: int in range(current_events.size()):
		if (
			source == NucleusInputTypes.Source.ANY
			or NucleusInputBindingCodec.get_source(current_events[index])
			== source
		):
			matching_indices.append(index)

	var replace_index: int = -1

	if binding_index < matching_indices.size():
		replace_index = matching_indices[binding_index]

	for index: int in range(current_events.size()):
		if index == replace_index:
			continue

		if current_events[index].is_match(normalized_event, true):
			return ERR_ALREADY_EXISTS

	if replace_index != -1:
		current_events[replace_index] = normalized_event
	else:
		current_events.append(normalized_event)

	_apply_action_events(action, current_events)
	_commit_action_override(action)

	return OK


## Removes one binding slot from a specific input source.
func remove_binding(
	action: StringName,
	source: int,
	binding_index: int,
) -> Error:
	if not is_action_rebindable(action):
		return ERR_DOES_NOT_EXIST

	if binding_index < 0:
		return ERR_INVALID_PARAMETER

	var current_events: Array[InputEvent] = get_action_events(action)
	var source_index: int = 0
	var remove_index: int = -1

	for index: int in range(current_events.size()):
		var event: InputEvent = current_events[index]

		if (
			source != NucleusInputTypes.Source.ANY
			and NucleusInputBindingCodec.get_source(event) != source
		):
			continue

		if source_index == binding_index:
			remove_index = index
			break

		source_index += 1

	if remove_index == -1:
		return ERR_DOES_NOT_EXIST

	current_events.remove_at(remove_index)
	_apply_action_events(action, current_events)
	_commit_action_override(action)

	return OK


## Removes all bindings for an action or only the selected input source.
func clear_bindings(
	action: StringName,
	source: int = NucleusInputTypes.Source.ANY,
) -> Error:
	if not is_action_rebindable(action):
		return ERR_DOES_NOT_EXIST

	if source == NucleusInputTypes.Source.ANY:
		_apply_action_events(action, [])
	else:
		var retained_events: Array[InputEvent] = []

		for event: InputEvent in get_action_events(action):
			if NucleusInputBindingCodec.get_source(event) != source:
				retained_events.append(event)

		_apply_action_events(action, retained_events)

	_commit_action_override(action)

	return OK


## Restores one action to its project.godot events and deadzone.
func reset_action(action: StringName) -> Error:
	if not _default_events.has(action):
		return ERR_DOES_NOT_EXIST

	_restore_action_default(action)
	_binding_overrides.erase(str(action))
	_persist_overrides()

	bindings_reset.emit(action)
	action_binding_changed.emit(action)

	return OK


## Restores every tracked action to project.godot defaults.
func reset_all_bindings() -> void:
	_restore_all_defaults()
	_binding_overrides.clear()
	_persist_overrides()

	bindings_reset.emit(&"")

	for action: StringName in _default_events:
		action_binding_changed.emit(action)


## Finds actions already using an equivalent hardware binding.
func find_conflicts(
	event: InputEvent,
	exclude_action: StringName = &"",
) -> Array[StringName]:
	var conflicts: Array[StringName] = []
	var normalized_event: InputEvent = NucleusInputBindingCodec.normalize(event)

	if normalized_event == null:
		return conflicts

	for action: StringName in get_rebindable_actions():
		if action == exclude_action:
			continue

		for binding: InputEvent in InputMap.action_get_events(action):
			if binding.is_match(normalized_event, true):
				conflicts.append(action)
				break

	return conflicts


## Starts a vibration effect on the active or explicitly supplied controller.
func start_vibration(
	weak_strength: float = 0.5,
	strong_strength: float = 0.5,
	duration: float = 0.65,
	device_id: int = -1,
) -> Error:
	if not NucleusSettings.get_bool(
		NucleusSettingIds.INPUT_VIBRATION_ENABLED,
		true,
	):
		return ERR_UNAVAILABLE

	var resolved_device_id: int = _resolve_gamepad_id(device_id)

	if resolved_device_id == -1:
		return ERR_DOES_NOT_EXIST

	if not Input.has_joy_vibration(resolved_device_id):
		return ERR_UNAVAILABLE

	Input.start_joy_vibration(
		resolved_device_id,
		clampf(weak_strength, 0.0, 1.0),
		clampf(strong_strength, 0.0, 1.0),
		maxf(duration, 0.0),
	)

	return OK


func stop_vibration(device_id: int = -1) -> void:
	var resolved_device_id: int = _resolve_gamepad_id(device_id)

	if resolved_device_id != -1:
		Input.stop_joy_vibration(resolved_device_id)


func _initialize() -> void:
	var persisted_value: Variant = NucleusSettings.get_value(
		NucleusSettingIds.INPUT_BINDINGS,
		{},
	)
	var overrides: Dictionary = {}

	if typeof(persisted_value) == TYPE_DICTIONARY:
		overrides = persisted_value.duplicate(true)

	_apply_override_dictionary(overrides)
	_initialized = true


func _capture_project_defaults() -> void:
	for action: StringName in InputMap.get_actions():
		if is_action_rebindable(action):
			_capture_action_default(action)


func _capture_action_default(action: StringName) -> void:
	_default_events[action] = get_action_events(action)
	_default_deadzones[action] = InputMap.action_get_deadzone(action)


func _restore_action_default(action: StringName) -> void:
	if not _default_events.has(action):
		return

	_apply_action_events(
		action,
		_duplicate_events(_default_events[action]),
	)
	InputMap.action_set_deadzone(
		action,
		_default_deadzones[action],
	)


func _restore_all_defaults() -> void:
	for action: StringName in _default_events:
		_restore_action_default(action)


func _apply_override_dictionary(overrides: Dictionary) -> void:
	_restore_all_defaults()

	var sanitized_overrides: Dictionary = {}

	for raw_action: Variant in overrides:
		var action := StringName(str(raw_action))

		if not is_action_rebindable(action):
			continue

		var encoded_events: Variant = overrides[raw_action]

		if typeof(encoded_events) != TYPE_ARRAY:
			continue

		var decoded_events: Array[InputEvent] = (
			NucleusInputBindingCodec.decode_events(encoded_events)
		)

		if (
			not encoded_events.is_empty()
			and decoded_events.size() != encoded_events.size()
		):
			NucleusLog.warning(
				"Ignored invalid binding override for '%s'." % action,
				LOG_CONTEXT,
			)
			continue

		_apply_action_events(action, decoded_events)

		if not _events_match_defaults(action, decoded_events):
			sanitized_overrides[str(action)] = (
				NucleusInputBindingCodec.encode_events(decoded_events)
			)

	_binding_overrides = sanitized_overrides

	if _binding_overrides != overrides:
		_persist_overrides()

	for action: StringName in _default_events:
		action_binding_changed.emit(action)


func _apply_action_events(
	action: StringName,
	events: Array[InputEvent],
) -> void:
	InputMap.action_erase_events(action)

	for event: InputEvent in events:
		var normalized_event: InputEvent = (
			NucleusInputBindingCodec.normalize(event)
		)

		if normalized_event:
			InputMap.action_add_event(action, normalized_event)


func _commit_action_override(action: StringName) -> void:
	var current_events: Array[InputEvent] = get_action_events(action)

	if _events_match_defaults(action, current_events):
		_binding_overrides.erase(str(action))
	else:
		_binding_overrides[str(action)] = (
			NucleusInputBindingCodec.encode_events(current_events)
		)

	_persist_overrides()
	action_binding_changed.emit(action)


func _events_match_defaults(
	action: StringName,
	events: Array[InputEvent],
) -> bool:
	if not _default_events.has(action):
		return false

	var defaults: Array = _default_events[action]

	if defaults.size() != events.size():
		return false

	for index: int in range(events.size()):
		var default_event: InputEvent = defaults[index]

		if not default_event.is_match(events[index], true):
			return false

	return true


func _persist_overrides() -> void:
	if not NucleusSettings.is_initialized():
		return

	_writing_settings = true
	NucleusSettings.set_value(
		NucleusSettingIds.INPUT_BINDINGS,
		_binding_overrides,
	)
	_writing_settings = false


func _duplicate_events(events: Array) -> Array[InputEvent]:
	var duplicated_events: Array[InputEvent] = []

	for event: InputEvent in events:
		duplicated_events.append(_duplicate_event(event))

	return duplicated_events


func _duplicate_event(event: InputEvent) -> InputEvent:
	return event.duplicate(true) as InputEvent


func _detect_meaningful_source(event: InputEvent) -> int:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		if event is InputEventMouse:
			return NucleusInputTypes.Source.TOUCH

		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			return NucleusInputTypes.Source.KEYBOARD_MOUSE

	if event is InputEventKey:
		if event.pressed and not event.echo:
			return NucleusInputTypes.Source.KEYBOARD_MOUSE

	elif event is InputEventMouseButton:
		if event.pressed:
			return NucleusInputTypes.Source.KEYBOARD_MOUSE

	elif event is InputEventMouseMotion:
		if (
			event.relative.length()
			>= MOUSE_MOTION_ACTIVITY_THRESHOLD
		):
			return NucleusInputTypes.Source.KEYBOARD_MOUSE

	elif event is InputEventJoypadButton:
		if event.pressed:
			return NucleusInputTypes.Source.GAMEPAD

	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) >= JOYPAD_MOTION_ACTIVITY_THRESHOLD:
			return NucleusInputTypes.Source.GAMEPAD

	elif event is InputEventScreenTouch:
		if event.pressed:
			return NucleusInputTypes.Source.TOUCH

	elif event is InputEventScreenDrag:
		return NucleusInputTypes.Source.TOUCH

	return NucleusInputTypes.Source.ANY


func _set_active_source(source: int) -> void:
	if source == active_source:
		return

	var previous_source: int = active_source
	active_source = source
	input_source_changed.emit(active_source, previous_source)


func _set_active_gamepad(device_id: int) -> void:
	var resolved_device_id: int = _resolve_gamepad_id(device_id)

	if resolved_device_id == -1:
		return

	var family: int = NucleusGamepad.detect_family(resolved_device_id)

	if (
		resolved_device_id == active_gamepad_id
		and family == active_gamepad_family
	):
		return

	active_gamepad_id = resolved_device_id
	active_gamepad_family = family
	active_gamepad_changed.emit(
		active_gamepad_id,
		active_gamepad_family,
	)


func _resolve_gamepad_id(requested_device_id: int) -> int:
	var connected_gamepads: Array[int] = Input.get_connected_joypads()

	if requested_device_id in connected_gamepads:
		return requested_device_id

	if active_gamepad_id in connected_gamepads:
		return active_gamepad_id

	if not connected_gamepads.is_empty():
		return connected_gamepads.front()

	return -1


func _on_joy_connection_changed(
	device_id: int,
	connected: bool,
) -> void:
	var device_name: String = Input.get_joy_name(device_id)

	if connected:
		gamepad_connected.emit(device_id, device_name)

		if active_gamepad_id == -1:
			_set_active_gamepad(device_id)

		return

	gamepad_disconnected.emit(device_id, device_name)

	if device_id != active_gamepad_id:
		return

	Input.stop_joy_vibration(device_id)
	active_gamepad_id = -1
	active_gamepad_family = NucleusInputTypes.GamepadFamily.GENERIC

	var remaining_gamepads: Array[int] = Input.get_connected_joypads()

	if remaining_gamepads.is_empty():
		_set_active_source(NucleusInputTypes.Source.KEYBOARD_MOUSE)
	else:
		_set_active_gamepad(remaining_gamepads.front())


func _on_setting_changed(
	setting_id: StringName,
	value: Variant,
	_previous_value: Variant,
) -> void:
	if (
		setting_id != NucleusSettingIds.INPUT_BINDINGS
		or _writing_settings
	):
		return

	if typeof(value) != TYPE_DICTIONARY:
		return

	_apply_override_dictionary(value.duplicate(true))
