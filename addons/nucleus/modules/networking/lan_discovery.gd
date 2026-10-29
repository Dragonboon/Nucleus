class_name NucleusLanDiscovery
extends Node
## Optional native-platform LAN announcement/listener over UDP broadcast.
##
## Raw UDP is unavailable in Web exports. Discovery payloads use JSON and are
## intentionally separate from the game's authoritative multiplayer transport.

signal announcement_received(
	address: String,
	source_port: int,
	payload: Dictionary,
)
signal discovery_error(error: Error)

const DEFAULT_DISCOVERY_PORT: int = 42071
const DEFAULT_BROADCAST_ADDRESS: String = "255.255.255.255"
const MAX_PACKET_BYTES: int = 8192

@export_range(0.1, 60.0, 0.1, "or_greater")
var broadcast_interval_seconds: float = 1.0

var _broadcaster: PacketPeerUDP
var _listener: PacketPeerUDP
var _broadcast_packet: PackedByteArray = PackedByteArray()
var _timer: Timer


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_timer = Timer.new()
	_timer.name = "LanBroadcastTimer"
	_timer.one_shot = false
	_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_timer.timeout.connect(_broadcast_once)
	add_child(_timer)

	set_process(false)


func _exit_tree() -> void:
	stop()


func _process(_delta: float) -> void:
	if _listener == null:
		set_process(false)
		return

	while _listener.get_available_packet_count() > 0:
		var packet: PackedByteArray = _listener.get_packet()

		if packet.size() <= 0 or packet.size() > MAX_PACKET_BYTES:
			continue

		var json := JSON.new()
		var error: Error = json.parse(
			packet.get_string_from_utf8()
		)

		if error != OK:
			continue

		if typeof(json.data) != TYPE_DICTIONARY:
			continue

		announcement_received.emit(
			_listener.get_packet_ip(),
			_listener.get_packet_port(),
			json.data,
		)


func start_announcing(
	payload: Dictionary,
	destination_port: int = DEFAULT_DISCOVERY_PORT,
	broadcast_address: String = DEFAULT_BROADCAST_ADDRESS,
) -> Error:
	if NucleusPlatform.is_web():
		return _emit_error(ERR_UNAVAILABLE)

	if not NucleusNetworkUtils.is_valid_port(
		destination_port,
		true,
	):
		return _emit_error(ERR_INVALID_PARAMETER)

	var encoded_payload: String = JSON.stringify(payload)

	if encoded_payload.is_empty():
		return _emit_error(ERR_INVALID_DATA)

	var packet: PackedByteArray = encoded_payload.to_utf8_buffer()

	if packet.size() > MAX_PACKET_BYTES:
		return _emit_error(ERR_OUT_OF_MEMORY)

	stop_announcing()

	_broadcaster = PacketPeerUDP.new()
	_broadcaster.set_broadcast_enabled(true)

	var address_error: Error = _broadcaster.set_dest_address(
		broadcast_address,
		destination_port,
	)

	if address_error != OK:
		_broadcaster.close()
		_broadcaster = null
		return _emit_error(address_error)

	_broadcast_packet = packet
	_timer.wait_time = broadcast_interval_seconds
	_timer.start()

	return _broadcast_once()


func start_listening(
	port: int = DEFAULT_DISCOVERY_PORT,
	bind_address: String = "0.0.0.0",
) -> Error:
	if NucleusPlatform.is_web():
		return _emit_error(ERR_UNAVAILABLE)

	if not NucleusNetworkUtils.is_valid_port(port, true):
		return _emit_error(ERR_INVALID_PARAMETER)

	stop_listening()

	_listener = PacketPeerUDP.new()

	var bind_error: Error = _listener.bind(
		port,
		bind_address,
	)

	if bind_error != OK:
		_listener.close()
		_listener = null
		return _emit_error(bind_error)

	set_process(true)

	return OK


func stop_announcing() -> void:
	if _timer:
		_timer.stop()

	if _broadcaster:
		_broadcaster.close()

	_broadcaster = null
	_broadcast_packet.clear()


func stop_listening() -> void:
	if _listener:
		_listener.close()

	_listener = null
	set_process(false)


func stop() -> void:
	stop_announcing()
	stop_listening()


func _broadcast_once() -> Error:
	if _broadcaster == null or _broadcast_packet.is_empty():
		return ERR_UNCONFIGURED

	var error: Error = _broadcaster.put_packet(
		_broadcast_packet
	)

	if error != OK:
		return _emit_error(error)

	return OK


func _emit_error(error: Error) -> Error:
	discovery_error.emit(error)

	return error
