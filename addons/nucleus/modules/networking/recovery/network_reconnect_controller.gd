class_name NucleusNetworkReconnectController
extends Node
## Optional client reconnect supervisor for one NucleusNetworkHandler.
## Transport connection does not imply authenticated or restored gameplay.

signal phase_changed(phase: int)
signal recovery_started(is_reconnect: bool)
signal attempt_started(attempt_number: int, request_token: int)
signal retry_scheduled(next_attempt: int, delay_seconds: float, reason: Error)
signal session_restore_requested(request_token: int)
signal session_ready(was_reconnect: bool)
signal recovery_failed(reason: Error)
signal stopped

enum Phase {
	IDLE,
	WAITING,
	CONNECTING,
	RESTORING,
	READY,
	FAILED,
}

@export var handler: NucleusNetworkHandler
@export var policy: NucleusNetworkReconnectPolicy
@export var auto_reconnect: bool = true
## Require explicit game acknowledgement after each transport connection.
@export var require_session_restore: bool = false

var phase: int = Phase.IDLE
var last_error: Error = OK

var _transport: int = NucleusNetworkTypes.Transport.NONE
var _address: String = ""
var _port: int = 42069
var _channel_count: int = 0
var _generation: int = 0
var _attempts: int = 0
var _cycle_started_msec: int = 0
var _deadline_msec: int = 0
var _recovering: bool = false
var _owns_connection: bool = false


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	if policy == null:
		policy = NucleusNetworkReconnectPolicy.new()
	_connect_handler_signals()


func _exit_tree() -> void:
	stop()
	_disconnect_handler_signals()


func _process(_delta: float) -> void:
	if phase not in [Phase.WAITING, Phase.CONNECTING, Phase.RESTORING]:
		return

	if not _handler_valid():
		_fail_terminal(ERR_UNCONFIGURED)
		return

	var now_msec: int = _now_msec()
	if _total_expired(now_msec):
		_fail_terminal(ERR_TIMEOUT)
		return

	if now_msec < _deadline_msec:
		return

	match phase:
		Phase.WAITING:
			_begin_attempt(now_msec)
		Phase.CONNECTING, Phase.RESTORING:
			_fail_attempt(ERR_TIMEOUT)


## Starts an ENet client session. Return OK means the request was accepted,
## not that the transport handshake or gameplay restoration succeeded.
func connect_enet(
	address: String,
	port: int = 42069,
	channel_count: int = 0,
) -> Error:
	var error: Error = _check_can_connect()
	if error != OK:
		return error
	if NucleusPlatform.is_web():
		return ERR_UNAVAILABLE
	if address.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	if not NucleusNetworkUtils.is_valid_port(port) or channel_count < 0:
		return ERR_INVALID_PARAMETER

	_transport = NucleusNetworkTypes.Transport.ENET
	_address = address.strip_edges()
	_port = port
	_channel_count = channel_count
	_begin_cycle(false)
	return OK


## Native WebSocket client transport; TLS validation remains Godot-owned.
func connect_websocket(url: String) -> Error:
	var error: Error = _check_can_connect()
	if error != OK:
		return error
	if not NucleusNetworkUtils.is_valid_websocket_url(url):
		return ERR_INVALID_PARAMETER

	_transport = NucleusNetworkTypes.Transport.WEBSOCKET
	_address = url.strip_edges()
	_port = 0
	_channel_count = 0
	_begin_cycle(false)
	return OK


## After receiving session_restore_requested, the game must validate identity,
## rejoin its authoritative session and finish rebuilding state before success.
## A failed acknowledgement is terminal, not an unsafe retry with another ID.
func complete_session_restore(request_token: int, accepted: bool) -> Error:
	if phase != Phase.RESTORING or request_token != _generation:
		return ERR_INVALID_PARAMETER
	if not _handler_valid() or not handler.is_client():
		return ERR_UNAVAILABLE

	if not accepted:
		_fail_terminal(ERR_UNAUTHORIZED)
		return OK

	_finish_ready()
	return OK


## Intentional Leave/Logout. Suppresses auto-reconnect and invalidates tokens.
func stop() -> void:
	if phase == Phase.IDLE and not _owns_connection:
		return

	_generation += 1
	_shutdown_owned_connection()
	_transport = NucleusNetworkTypes.Transport.NONE
	_address = ""
	_attempts = 0
	_recovering = false
	last_error = OK
	_set_phase(Phase.IDLE)
	stopped.emit()


func is_session_ready() -> bool:
	return phase == Phase.READY and _handler_valid() and handler.is_client()


func get_attempt_count() -> int:
	return _attempts


func get_request_token() -> int:
	return _generation


func _check_can_connect() -> Error:
	if not is_inside_tree() or not _handler_valid():
		return ERR_UNCONFIGURED
	if phase not in [Phase.IDLE, Phase.FAILED]:
		return ERR_BUSY
	if handler.state != NucleusNetworkTypes.State.OFFLINE or handler.peer:
		return ERR_ALREADY_IN_USE
	if policy == null or not policy.get_validation_errors().is_empty():
		return ERR_INVALID_PARAMETER
	_connect_handler_signals()
	return OK


func _begin_cycle(is_reconnect: bool) -> void:
	_generation += 1
	_attempts = 0
	_recovering = is_reconnect
	_cycle_started_msec = _now_msec()
	last_error = OK
	_set_phase(Phase.WAITING)
	recovery_started.emit(is_reconnect)
	if phase != Phase.WAITING:
		return

	if is_reconnect:
		var delay: float = policy.initial_delay_seconds
		_deadline_msec = _cycle_started_msec + _to_msec(delay)
		retry_scheduled.emit(1, delay, ERR_CANT_CONNECT)
	else:
		_begin_attempt(_cycle_started_msec)


func _begin_attempt(now_msec: int) -> void:
	if phase != Phase.WAITING:
		return
	if _attempts >= policy.max_attempts or _total_expired(now_msec):
		_fail_terminal(ERR_TIMEOUT)
		return
	if handler.state != NucleusNetworkTypes.State.OFFLINE or handler.peer:
		_fail_terminal(ERR_ALREADY_IN_USE)
		return

	_attempts += 1
	_generation += 1
	var request_token: int = _generation
	_deadline_msec = now_msec + _to_msec(policy.attempt_timeout_seconds)
	_set_phase(Phase.CONNECTING)
	attempt_started.emit(_attempts, request_token)
	if phase != Phase.CONNECTING or request_token != _generation:
		return

	var error: Error = ERR_INVALID_PARAMETER
	match _transport:
		NucleusNetworkTypes.Transport.ENET:
			error = handler.start_enet_client(
				_address,
				_port,
				_channel_count,
			)
		NucleusNetworkTypes.Transport.WEBSOCKET:
			error = handler.start_websocket_client(_address)

	if phase != Phase.CONNECTING or request_token != _generation:
		return
	if error != OK:
		_fail_attempt(error)
		return
	_owns_connection = true


func _fail_attempt(error: Error) -> void:
	if phase not in [Phase.CONNECTING, Phase.RESTORING]:
		return
	last_error = error
	_shutdown_owned_connection()
	var now_msec: int = _now_msec()

	if _attempts >= policy.max_attempts or _total_expired(now_msec):
		_fail_terminal(error)
		return

	var delay: float = policy.delay_after_failure(_attempts)
	var delay_msec: int = _to_msec(delay)
	if now_msec + delay_msec >= (
		_cycle_started_msec + _to_msec(policy.total_timeout_seconds)
	):
		_fail_terminal(ERR_TIMEOUT)
		return

	_generation += 1
	_deadline_msec = now_msec + delay_msec
	_set_phase(Phase.WAITING)
	retry_scheduled.emit(_attempts + 1, delay, error)


func _on_connected_to_server() -> void:
	if phase != Phase.CONNECTING or not _handler_valid() or not handler.is_client():
		return

	if not require_session_restore:
		_finish_ready()
		return

	_deadline_msec = _now_msec() + _to_msec(policy.restore_timeout_seconds)
	_set_phase(Phase.RESTORING)
	session_restore_requested.emit(_generation)


func _on_connection_failed() -> void:
	_fail_attempt(ERR_CANT_CONNECT)


func _on_server_disconnected() -> void:
	if phase in [Phase.CONNECTING, Phase.RESTORING]:
		_fail_attempt(ERR_CANT_CONNECT)
		return
	if phase != Phase.READY:
		return

	_owns_connection = false
	if auto_reconnect:
		_begin_cycle(true)
	else:
		_fail_terminal(ERR_CANT_CONNECT)


func _finish_ready() -> void:
	if phase not in [Phase.CONNECTING, Phase.RESTORING]:
		return
	var was_reconnect: bool = _recovering
	last_error = OK
	_set_phase(Phase.READY)
	session_ready.emit(was_reconnect)


func _fail_terminal(error: Error) -> void:
	if phase in [Phase.IDLE, Phase.FAILED]:
		return
	_generation += 1
	_shutdown_owned_connection()
	last_error = error
	_set_phase(Phase.FAILED)
	recovery_failed.emit(error)


func _shutdown_owned_connection() -> void:
	if _owns_connection and _handler_valid():
		handler.shutdown()
	_owns_connection = false


func _connect_handler_signals() -> void:
	if not _handler_valid():
		return
	if not handler.connected_to_server.is_connected(_on_connected_to_server):
		handler.connected_to_server.connect(_on_connected_to_server)
	if not handler.connection_failed.is_connected(_on_connection_failed):
		handler.connection_failed.connect(_on_connection_failed)
	if not handler.server_disconnected.is_connected(_on_server_disconnected):
		handler.server_disconnected.connect(_on_server_disconnected)


func _disconnect_handler_signals() -> void:
	if not _handler_valid():
		return
	if handler.connected_to_server.is_connected(_on_connected_to_server):
		handler.connected_to_server.disconnect(_on_connected_to_server)
	if handler.connection_failed.is_connected(_on_connection_failed):
		handler.connection_failed.disconnect(_on_connection_failed)
	if handler.server_disconnected.is_connected(_on_server_disconnected):
		handler.server_disconnected.disconnect(_on_server_disconnected)


func _handler_valid() -> bool:
	return handler != null and is_instance_valid(handler)


func _set_phase(next_phase: int) -> void:
	if phase == next_phase:
		return
	phase = next_phase
	phase_changed.emit(phase)


func _total_expired(now_msec: int) -> bool:
	return now_msec - _cycle_started_msec >= _to_msec(
		policy.total_timeout_seconds
	)


func _to_msec(seconds: float) -> int:
	return int(ceilf(seconds * 1000.0))


## Overridable monotonic clock boundary for deterministic tests.
func _now_msec() -> int:
	return Time.get_ticks_msec()
