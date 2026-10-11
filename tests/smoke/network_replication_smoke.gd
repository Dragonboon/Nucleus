extends Node
## Real localhost ENet peers with independent MultiplayerAPI scene roots.
## Verifies existing 2D/3D replicators; this is not a game lobby or latency benchmark.

var _server_2d: NucleusNetworkTransformReplicator2D
var _server_3d: NucleusNetworkTransformReplicator3D
var _client_2d: NucleusNetworkTransformReplicator2D
var _client_3d: NucleusNetworkTransformReplicator3D
var _handlers: Array[NucleusNetworkHandler] = []
var _phase: int = 0
var _settle_frames: int = 0
var _started_msec: int = 0


func _ready() -> void:
	_started_msec = Time.get_ticks_msec()
	var server_root: Node = _create_peer_root("Server")
	var client_root: Node = _create_peer_root("Client")
	_server_2d = server_root.get_node("Planar/Replicator")
	_server_3d = server_root.get_node("Spatial/Replicator")
	_client_2d = client_root.get_node("Planar/Replicator")
	_client_3d = client_root.get_node("Spatial/Replicator")
	_server_2d.target.position = Vector2(20.0, 0.0)
	_server_3d.target.position = Vector3(20.0, 0.0, 0.0)
	var port: int = 48472
	var error: Error = _handlers[0].start_enet_server(port, 1, "127.0.0.1")
	if error == OK:
		error = _handlers[1].start_enet_client("127.0.0.1", port)
	if error != OK:
		_finish(false, "Could not start localhost ENet peers: " + error_string(error))


func _create_peer_root(peer_name: String) -> Node:
	var peer_root := Node.new()
	peer_root.name = peer_name
	add_child(peer_root)
	get_tree().set_multiplayer(MultiplayerAPI.create_default_interface(), peer_root.get_path())
	var handler := NucleusNetworkHandler.new()
	peer_root.add_child(handler)
	_handlers.append(handler)
	var planar := Node2D.new()
	planar.name = "Planar"
	var spatial := Node3D.new()
	spatial.name = "Spatial"
	peer_root.add_child(planar)
	peer_root.add_child(spatial)
	var replica_2d := NucleusNetworkTransformReplicator2D.new()
	var replica_3d := NucleusNetworkTransformReplicator3D.new()
	replica_2d.name = "Replicator"
	replica_3d.name = "Replicator"
	replica_2d.teleport_distance = 8.0
	replica_3d.teleport_distance = 8.0
	planar.add_child(replica_2d)
	spatial.add_child(replica_3d)
	return peer_root


func _physics_process(_delta: float) -> void:
	if Time.get_ticks_msec() - _started_msec > 10000:
		_finish(false, "Timed out waiting for replicated state.")
		return
	match _phase:
		0:
			if _client_2d._buffer.get_count() < 2 or _client_3d._buffer.get_count() < 2:
				return
			_server_2d.active = false
			_server_3d.active = false
			_server_2d._receive_snapshot.rpc(0, Vector2(1000.0, 0.0), 0.0)
			_server_3d._receive_snapshot.rpc(0, Vector3(1000.0, 0.0, 0.0), Quaternion())
			_server_2d._receive_snapshot.rpc(100000, Vector2.INF, 0.0)
			_server_3d._receive_snapshot.rpc(100000, Vector3.INF, Quaternion())
			_phase = 1
		1:
			_settle_frames += 1
			if _settle_frames < 12:
				return
			if not _positions_match(20.0):
				_finish(false, "Stale or invalid RPC mutated a remote transform.")
				return
			_server_2d._receive_snapshot.rpc(100000, Vector2(40.0, 0.0), 0.0)
			_server_3d._receive_snapshot.rpc(100000, Vector3(40.0, 0.0, 0.0), Quaternion())
			_phase = 2
		2:
			if _positions_match(40.0):
				_finish(true, "2D/3D snapshots, stale/invalid rejection and valid retry.")


func _positions_match(expected_x: float) -> bool:
	return (
		_client_2d.target.position.is_equal_approx(Vector2(expected_x, 0.0))
		and _client_3d.target.position.is_equal_approx(Vector3(expected_x, 0.0, 0.0))
	)


func _finish(success: bool, message: String) -> void:
	set_physics_process(false)
	for handler: NucleusNetworkHandler in _handlers:
		handler.shutdown()
	if success:
		print("Nucleus ENet replication smoke: PASS. " + message)
	else:
		push_error("Nucleus ENet replication smoke: FAIL. " + message)
	get_tree().quit(0 if success else 1)
