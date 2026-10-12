class_name NucleusNetworkWorldReadiness
extends Node
## Scene-owned join barrier; authentication and replication remain game-owned.
signal peer_ready(peer_id: int, epoch: int)
signal peer_removed(peer_id: int)

var _epoch: int = 0
var _expected: Dictionary = {}
var _ready_peers: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_disconnected.connect(remove_peer)

func _exit_tree() -> void:
	if multiplayer.peer_disconnected.is_connected(remove_peer):
		multiplayer.peer_disconnected.disconnect(remove_peer)
	clear()

## Server resets the handshake for a strictly newer positive world/session epoch.
func begin_session(epoch: int) -> bool:
	if not multiplayer.is_server() or epoch <= 0 or epoch <= _epoch:
		return false
	clear()
	_epoch = epoch
	return true

## Client receives epoch from a trusted game-owned admission protocol.
func prepare_session(epoch: int) -> bool:
	if multiplayer.is_server() or epoch <= 0:
		return false
	clear()
	_epoch = epoch
	return true

## Call only after the game has authenticated and admitted the peer.
func expect_peer(peer_id: int) -> bool:
	if not multiplayer.is_server() or _epoch <= 0 or peer_id <= 1:
		return false
	_expected[peer_id] = true
	_ready_peers.erase(peer_id)
	return true

func confirm_loaded() -> Error:
	if multiplayer.is_server() or _epoch <= 0:
		return ERR_UNAVAILABLE
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return ERR_UNAVAILABLE
	_receive_ready.rpc_id(1, _epoch)
	return OK

@rpc("any_peer", "call_remote", "reliable", 0)
func _receive_ready(epoch: int) -> void:
	if multiplayer.is_server():
		var sender: int = multiplayer.get_remote_sender_id()
		if multiplayer.get_peers().has(sender):
			_accept_ready(sender, epoch)

func _accept_ready(peer_id: int, epoch: int) -> bool:
	if (
		not multiplayer.is_server()
		or epoch != _epoch
		or epoch <= 0
		or not _expected.has(peer_id)
		or _ready_peers.has(peer_id)
	):
		return false
	_ready_peers[peer_id] = true
	peer_ready.emit(peer_id, epoch)
	return true

func is_ready(peer_id: int) -> bool:
	return _ready_peers.has(peer_id)

func remove_peer(peer_id: int) -> void:
	var existed: bool = _expected.has(peer_id) or _ready_peers.has(peer_id)
	_expected.erase(peer_id)
	_ready_peers.erase(peer_id)
	if existed:
		peer_removed.emit(peer_id)

func clear() -> void:
	for peer_id in _expected.keys():
		remove_peer(int(peer_id))
	_epoch = 0
