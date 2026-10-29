class_name NucleusNetworkHandler
extends Node
## Optional facade over Godot's high-level MultiplayerAPI.
##
## This module does not implement replication, gameplay RPCs, authentication,
## matchmaking, or lobby state. It only owns peer lifecycle and transport
## selection for projects that want this convenience layer.

signal state_changed(
	previous_state: int,
	state: int,
)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connected_to_server
signal connection_failed
signal server_disconnected
signal start_failed(error: Error)

const LOG_CONTEXT: StringName = &"Networking"

@export var shutdown_on_exit: bool = true

var state: int = NucleusNetworkTypes.State.OFFLINE
var transport: int = NucleusNetworkTypes.Transport.NONE
var peer: MultiplayerPeer


func _ready() -> void:
	_connect_multiplayer_signals()


func _exit_tree() -> void:
	if shutdown_on_exit:
		shutdown()


func start_enet_server(
	port: int = 42069,
	max_clients: int = 32,
	bind_address: String = "*",
	channel_count: int = 0,
	in_bandwidth: int = 0,
	out_bandwidth: int = 0,
) -> Error:
	if NucleusPlatform.is_web():
		return _start_error(ERR_UNAVAILABLE)

	if not NucleusNetworkUtils.is_valid_port(port):
		return _start_error(ERR_INVALID_PARAMETER)

	if max_clients <= 0:
		return _start_error(ERR_INVALID_PARAMETER)

	if not _can_start():
		return _start_error(ERR_ALREADY_IN_USE)

	_set_state(NucleusNetworkTypes.State.STARTING)

	var enet_peer := ENetMultiplayerPeer.new()

	if bind_address != "*":
		enet_peer.set_bind_ip(bind_address)

	var error: Error = enet_peer.create_server(
		port,
		max_clients,
		channel_count,
		in_bandwidth,
		out_bandwidth,
	)

	if error != OK:
		_set_state(NucleusNetworkTypes.State.OFFLINE)
		return _start_error(error)

	return _activate_peer(
		enet_peer,
		NucleusNetworkTypes.Transport.ENET,
		NucleusNetworkTypes.State.SERVER,
	)


func start_enet_client(
	address: String,
	port: int = 42069,
	channel_count: int = 0,
	in_bandwidth: int = 0,
	out_bandwidth: int = 0,
	local_port: int = 0,
) -> Error:
	if NucleusPlatform.is_web():
		return _start_error(ERR_UNAVAILABLE)

	if address.strip_edges().is_empty():
		return _start_error(ERR_INVALID_PARAMETER)

	if not NucleusNetworkUtils.is_valid_port(port):
		return _start_error(ERR_INVALID_PARAMETER)

	if (
		local_port != 0
		and not NucleusNetworkUtils.is_valid_port(
			local_port,
			true,
		)
	):
		return _start_error(ERR_INVALID_PARAMETER)

	if not _can_start():
		return _start_error(ERR_ALREADY_IN_USE)

	_set_state(NucleusNetworkTypes.State.STARTING)

	var enet_peer := ENetMultiplayerPeer.new()
	var error: Error = enet_peer.create_client(
		address,
		port,
		channel_count,
		in_bandwidth,
		out_bandwidth,
		local_port,
	)

	if error != OK:
		_set_state(NucleusNetworkTypes.State.OFFLINE)
		return _start_error(error)

	return _activate_peer(
		enet_peer,
		NucleusNetworkTypes.Transport.ENET,
		NucleusNetworkTypes.State.CONNECTING,
	)


func start_websocket_server(
	port: int = 42069,
	bind_address: String = "*",
	tls_options: TLSOptions = null,
) -> Error:
	# Browsers cannot listen for incoming socket connections.
	if NucleusPlatform.is_web():
		return _start_error(ERR_UNAVAILABLE)

	if not NucleusNetworkUtils.is_valid_port(port):
		return _start_error(ERR_INVALID_PARAMETER)

	if not _can_start():
		return _start_error(ERR_ALREADY_IN_USE)

	_set_state(NucleusNetworkTypes.State.STARTING)

	var websocket_peer := WebSocketMultiplayerPeer.new()
	var error: Error = websocket_peer.create_server(
		port,
		bind_address,
		tls_options,
	)

	if error != OK:
		_set_state(NucleusNetworkTypes.State.OFFLINE)
		return _start_error(error)

	return _activate_peer(
		websocket_peer,
		NucleusNetworkTypes.Transport.WEBSOCKET,
		NucleusNetworkTypes.State.SERVER,
	)


func start_websocket_client(
	url: String,
	tls_options: TLSOptions = null,
) -> Error:
	if not NucleusNetworkUtils.is_valid_websocket_url(url):
		return _start_error(ERR_INVALID_PARAMETER)

	if not _can_start():
		return _start_error(ERR_ALREADY_IN_USE)

	_set_state(NucleusNetworkTypes.State.STARTING)

	var websocket_peer := WebSocketMultiplayerPeer.new()
	var error: Error = websocket_peer.create_client(
		url,
		tls_options,
	)

	if error != OK:
		_set_state(NucleusNetworkTypes.State.OFFLINE)
		return _start_error(error)

	return _activate_peer(
		websocket_peer,
		NucleusNetworkTypes.Transport.WEBSOCKET,
		NucleusNetworkTypes.State.CONNECTING,
	)


## Closes the current peer and restores Godot's offline multiplayer peer.
func shutdown() -> void:
	if peer:
		peer.close()

	peer = null
	transport = NucleusNetworkTypes.Transport.NONE
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	_set_state(NucleusNetworkTypes.State.OFFLINE)


func is_online() -> bool:
	return state != NucleusNetworkTypes.State.OFFLINE


func is_server() -> bool:
	return state == NucleusNetworkTypes.State.SERVER


func is_client() -> bool:
	return state == NucleusNetworkTypes.State.CLIENT


func get_unique_id() -> int:
	if not is_online():
		return 0

	return multiplayer.get_unique_id()


func get_connected_peers() -> PackedInt32Array:
	if not is_online():
		return PackedInt32Array()

	return multiplayer.get_peers()


func disconnect_peer(
	peer_id: int,
	force: bool = false,
) -> Error:
	if not is_server() or peer == null:
		return ERR_UNAVAILABLE

	if peer_id <= 0:
		return ERR_INVALID_PARAMETER

	peer.disconnect_peer(peer_id, force)

	return OK


func _activate_peer(
	new_peer: MultiplayerPeer,
	new_transport: int,
	new_state: int,
) -> Error:
	peer = new_peer
	transport = new_transport
	multiplayer.multiplayer_peer = peer

	_set_state(new_state)

	return OK


func _can_start() -> bool:
	return (
		state == NucleusNetworkTypes.State.OFFLINE
		and peer == null
	)


func _connect_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(
		_on_peer_connected
	):
		multiplayer.peer_connected.connect(_on_peer_connected)

	if not multiplayer.peer_disconnected.is_connected(
		_on_peer_disconnected
	):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if not multiplayer.connected_to_server.is_connected(
		_on_connected_to_server
	):
		multiplayer.connected_to_server.connect(
			_on_connected_to_server
		)

	if not multiplayer.connection_failed.is_connected(
		_on_connection_failed
	):
		multiplayer.connection_failed.connect(
			_on_connection_failed
		)

	if not multiplayer.server_disconnected.is_connected(
		_on_server_disconnected
	):
		multiplayer.server_disconnected.connect(
			_on_server_disconnected
		)


func _set_state(new_state: int) -> void:
	if state == new_state:
		return

	var previous_state: int = state
	state = new_state

	state_changed.emit(previous_state, state)


func _start_error(error: Error) -> Error:
	start_failed.emit(error)

	NucleusLog.warning(
		"Network peer could not start: %s"
		% error_string(error),
		LOG_CONTEXT,
	)

	return error


func _on_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	_set_state(NucleusNetworkTypes.State.CLIENT)
	connected_to_server.emit()


func _on_connection_failed() -> void:
	if peer:
		peer.close()

	peer = null
	transport = NucleusNetworkTypes.Transport.NONE
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_set_state(NucleusNetworkTypes.State.OFFLINE)

	connection_failed.emit()


func _on_server_disconnected() -> void:
	if peer:
		peer.close()

	peer = null
	transport = NucleusNetworkTypes.Transport.NONE
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_set_state(NucleusNetworkTypes.State.OFFLINE)

	server_disconnected.emit()
