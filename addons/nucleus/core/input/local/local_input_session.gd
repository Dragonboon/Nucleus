class_name NucleusLocalInputSession
extends Node
## Optional scene-owned local multiplayer input router.
##
## Keyboard/mouse, gamepads, and one logical touchscreen can own local seats.
## Single-player sessions may hot-swap the stable player object between sources.

signal player_joined(player: NucleusLocalPlayerInput)
signal player_left(player_index: int)
signal player_input(player: NucleusLocalPlayerInput, event: InputEvent)
signal player_device_disconnected(player: NucleusLocalPlayerInput)
signal player_device_reconnected(player: NucleusLocalPlayerInput)
signal player_device_changed(
	player: NucleusLocalPlayerInput,
	previous_source: int,
	previous_device_id: int,
)
signal join_requested(device_id: int)

@export_range(1, 16, 1, "or_greater")
var max_players: int = 4
@export var reserve_keyboard_mouse_player: bool = true
@export_range(0, 15, 1, "or_greater")
var keyboard_mouse_player_index: int = 0
@export var auto_join_gamepads: bool = true
## Lets a one-player session follow meaningful keyboard/gamepad/touch activity.
@export var single_player_hot_swap: bool = true

var _players: Dictionary[int, NucleusLocalPlayerInput] = {}
var _gamepad_to_player: Dictionary[int, int] = {}


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	NucleusInput.gamepad_connected.connect(_on_gamepad_connected)
	NucleusInput.gamepad_disconnected.connect(_on_gamepad_disconnected)
	NucleusInput.input_source_changed.connect(_on_input_source_changed)
	NucleusInput.active_gamepad_changed.connect(_on_active_gamepad_changed)

	if reserve_keyboard_mouse_player:
		join_keyboard_mouse(keyboard_mouse_player_index)


func _exit_tree() -> void:
	if NucleusInput.gamepad_connected.is_connected(_on_gamepad_connected):
		NucleusInput.gamepad_connected.disconnect(_on_gamepad_connected)
	if NucleusInput.gamepad_disconnected.is_connected(_on_gamepad_disconnected):
		NucleusInput.gamepad_disconnected.disconnect(_on_gamepad_disconnected)
	if NucleusInput.input_source_changed.is_connected(_on_input_source_changed):
		NucleusInput.input_source_changed.disconnect(_on_input_source_changed)
	if NucleusInput.active_gamepad_changed.is_connected(_on_active_gamepad_changed):
		NucleusInput.active_gamepad_changed.disconnect(_on_active_gamepad_changed)


func _input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return

	if event is InputEventJoypadButton:
		if event.pressed and not _gamepad_to_player.has(event.device):
			if auto_join_gamepads and not _uses_single_player_hot_swap():
				join_gamepad(event.device)
			elif not _uses_single_player_hot_swap():
				join_requested.emit(event.device)

		_route_gamepad_event(event)
		return

	if event is InputEventJoypadMotion:
		_route_gamepad_event(event)
		return

	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_route_touch_event(event)
		return

	if (
		event is InputEventKey
		or event is InputEventMouseButton
		or event is InputEventMouseMotion
	):
		_route_keyboard_mouse_event(event)


func join_keyboard_mouse(
	preferred_player_index: int = -1,
) -> NucleusLocalPlayerInput:
	for player: NucleusLocalPlayerInput in _players.values():
		if player.is_keyboard_mouse():
			return player

	return _join_source(
		NucleusInputTypes.Source.KEYBOARD_MOUSE,
		InputEvent.DEVICE_ID_KEYBOARD,
		preferred_player_index,
	)


func join_gamepad(
	device_id: int,
	preferred_player_index: int = -1,
) -> NucleusLocalPlayerInput:
	if device_id not in Input.get_connected_joypads():
		return null

	if _gamepad_to_player.has(device_id):
		return get_player(_gamepad_to_player[device_id])

	var player: NucleusLocalPlayerInput = _join_source(
		NucleusInputTypes.Source.GAMEPAD,
		device_id,
		preferred_player_index,
	)

	if player:
		_gamepad_to_player[device_id] = player.player_index

	return player


func join_touch(
	preferred_player_index: int = -1,
) -> NucleusLocalPlayerInput:
	for player: NucleusLocalPlayerInput in _players.values():
		if player.is_touch():
			return player

	return _join_source(
		NucleusInputTypes.Source.TOUCH,
		-1,
		preferred_player_index,
	)


func set_player_device(
	player_index: int,
	source: int,
	device_id: int = -1,
) -> Error:
	var player: NucleusLocalPlayerInput = get_player(player_index)

	if player == null:
		return ERR_DOES_NOT_EXIST

	var resolved_device_id: int = device_id

	if source == NucleusInputTypes.Source.KEYBOARD_MOUSE:
		resolved_device_id = InputEvent.DEVICE_ID_KEYBOARD
	elif source == NucleusInputTypes.Source.TOUCH:
		resolved_device_id = -1
	elif source == NucleusInputTypes.Source.GAMEPAD:
		if resolved_device_id == -1:
			resolved_device_id = NucleusInput.active_gamepad_id
		if resolved_device_id not in Input.get_connected_joypads():
			return ERR_DOES_NOT_EXIST
	else:
		return ERR_INVALID_PARAMETER

	if (
		source == NucleusInputTypes.Source.GAMEPAD
		and _gamepad_to_player.has(resolved_device_id)
		and _gamepad_to_player[resolved_device_id] != player_index
	):
		return ERR_ALREADY_IN_USE

	if source == NucleusInputTypes.Source.TOUCH:
		for other: NucleusLocalPlayerInput in _players.values():
			if other.player_index != player_index and other.is_touch():
				return ERR_ALREADY_IN_USE

	var previous_source: int = player.source
	var previous_device_id: int = player.device_id

	if player.is_gamepad() and player.device_id != -1:
		_gamepad_to_player.erase(player.device_id)

	if not player._set_input_device(source, resolved_device_id):
		return OK

	if player.is_gamepad():
		_gamepad_to_player[player.device_id] = player.player_index

	player_device_changed.emit(
		player,
		previous_source,
		previous_device_id,
	)
	return OK


func set_touch_action(
	player_index: int,
	action: StringName,
	strength: float,
) -> Error:
	if action == &"" or not InputMap.has_action(action):
		return ERR_DOES_NOT_EXIST

	var normalized: float = clampf(strength, 0.0, 1.0)

	if normalized > 0.0 and _uses_single_player_hot_swap():
		_hot_swap_single_player(NucleusInputTypes.Source.TOUCH)

	var player: NucleusLocalPlayerInput = get_player(player_index)
	if player == null:
		return ERR_DOES_NOT_EXIST

	# A delayed touch release must not steal the seat back after another source
	# became active.
	if not player.is_touch():
		return OK

	player._set_touch_action(action, normalized)
	return OK


func leave_player(player_index: int) -> void:
	var player: NucleusLocalPlayerInput = _players.get(player_index)

	if player == null:
		return

	if player.is_gamepad() and player.device_id != -1:
		_gamepad_to_player.erase(player.device_id)
		player.stop_vibration()

	if player.is_touch():
		player._clear_touch_actions()

	_players.erase(player_index)
	player_left.emit(player_index)


func clear_players() -> void:
	var player_indices: Array[int] = _players.keys()
	player_indices.sort()

	for player_index: int in player_indices:
		leave_player(player_index)


func get_player(player_index: int) -> NucleusLocalPlayerInput:
	return _players.get(player_index)


func get_players() -> Array[NucleusLocalPlayerInput]:
	var result: Array[NucleusLocalPlayerInput] = []
	var player_indices: Array[int] = _players.keys()
	player_indices.sort()

	for player_index: int in player_indices:
		result.append(_players[player_index])

	return result


func get_connected_players() -> Array[NucleusLocalPlayerInput]:
	return get_players().filter(
		func(player: NucleusLocalPlayerInput) -> bool:
			return player.connected
	)


func has_player(player_index: int) -> bool:
	return _players.has(player_index)


func get_player_for_gamepad(
	device_id: int,
) -> NucleusLocalPlayerInput:
	if not _gamepad_to_player.has(device_id):
		return null

	return get_player(_gamepad_to_player[device_id])


func _join_source(
	source: int,
	device_id: int,
	preferred_player_index: int,
) -> NucleusLocalPlayerInput:
	var player_index: int = _resolve_player_index(preferred_player_index)
	if player_index == -1:
		return null

	var player := NucleusLocalPlayerInput.new(
		player_index,
		source,
		device_id,
	)
	_players[player_index] = player
	player_joined.emit(player)
	return player


func _resolve_player_index(preferred_player_index: int) -> int:
	if (
		preferred_player_index >= 0
		and preferred_player_index < max_players
		and not _players.has(preferred_player_index)
	):
		return preferred_player_index

	for player_index: int in range(max_players):
		if not _players.has(player_index):
			return player_index

	return -1


func _route_keyboard_mouse_event(event: InputEvent) -> void:
	for player: NucleusLocalPlayerInput in _players.values():
		if player.is_keyboard_mouse() and player.connected:
			player._dispatch_input(event)
			player_input.emit(player, event)
			return


func _route_gamepad_event(event: InputEvent) -> void:
	var player: NucleusLocalPlayerInput = get_player_for_gamepad(event.device)

	if player == null or not player.connected:
		return

	player._dispatch_input(event)
	player_input.emit(player, event)


func _route_touch_event(event: InputEvent) -> void:
	for player: NucleusLocalPlayerInput in _players.values():
		if player.is_touch() and player.connected:
			player._dispatch_input(event)
			player_input.emit(player, event)
			return


func _uses_single_player_hot_swap() -> bool:
	return single_player_hot_swap and max_players == 1


func _hot_swap_single_player(source: int) -> void:
	if not _uses_single_player_hot_swap():
		return

	var players: Array[NucleusLocalPlayerInput] = get_players()

	if players.size() != 1:
		return

	var device_id: int = -1

	if source == NucleusInputTypes.Source.GAMEPAD:
		device_id = NucleusInput.active_gamepad_id
		if device_id == -1:
			return
	elif source == NucleusInputTypes.Source.KEYBOARD_MOUSE:
		device_id = InputEvent.DEVICE_ID_KEYBOARD
	elif source != NucleusInputTypes.Source.TOUCH:
		return

	set_player_device(
		players[0].player_index,
		source,
		device_id,
	)


func _on_input_source_changed(
	source: int,
	_previous_source: int,
) -> void:
	if source in [
		NucleusInputTypes.Source.KEYBOARD_MOUSE,
		NucleusInputTypes.Source.GAMEPAD,
		NucleusInputTypes.Source.TOUCH,
	]:
		_hot_swap_single_player(source)


func _on_active_gamepad_changed(
	_device_id: int,
	_family: int,
) -> void:
	if NucleusInput.active_source == NucleusInputTypes.Source.GAMEPAD:
		_hot_swap_single_player(NucleusInputTypes.Source.GAMEPAD)


func _on_gamepad_disconnected(
	device_id: int,
	_device_name: String,
) -> void:
	var player: NucleusLocalPlayerInput = get_player_for_gamepad(device_id)

	if player == null:
		return

	_gamepad_to_player.erase(device_id)
	player._mark_disconnected()
	player_device_disconnected.emit(player)


func _on_gamepad_connected(
	device_id: int,
	_device_name: String,
) -> void:
	var guid: String = Input.get_joy_guid(device_id)

	for player: NucleusLocalPlayerInput in _players.values():
		if (
			player.is_gamepad()
			and not player.connected
			and not player.device_guid.is_empty()
			and player.device_guid == guid
		):
			player._set_gamepad_device(device_id)
			_gamepad_to_player[device_id] = player.player_index
			player_device_reconnected.emit(player)
			return
