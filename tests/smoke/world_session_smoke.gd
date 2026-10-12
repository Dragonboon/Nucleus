extends Node
## Three real ENet clients: world readiness gates interaction and reconnect.
## Independent MultiplayerAPI roots share one process; this is not a dedicated-server benchmark.

class ReadyIntent extends NucleusNetworkIntentChannel:
	var readiness: NucleusNetworkWorldReadiness

	func validate_intent(peer: int, action: StringName, payload: Dictionary, _reliable: bool) -> Error:
		if not readiness.is_ready(peer):
			return ERR_UNAVAILABLE
		return OK if action == &"interact" and payload.get("target") == "door" else ERR_INVALID_DATA


var _roots: Array[Node] = []
var _handlers: Array[NucleusNetworkHandler] = []
var _gates: Array[NucleusNetworkWorldReadiness] = []
var _accepted: int = 0
var _rejected: int = 0
var _failures: int = 0
const PORT: int = 48473


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for index in range(4):
		_create_peer(index)
	_check(_handlers[0].start_enet_server(PORT, 3, "127.0.0.1") == OK, "Server starts.")
	for index in range(1, 4):
		_check(_handlers[index].start_enet_client("127.0.0.1", PORT) == OK, "Client starts.")
	if not await _until(func() -> bool: return _roots[0].multiplayer.get_peers().size() == 3):
		_finish()
		return
	_check(_gates[0].begin_session(100), "World session starts.")
	for slot in range(1, 4):
		_bind_peer(slot)
		var channel := _roots[slot].get_node("Intent%d" % slot) as ReadyIntent
		channel.submit_reliable(&"interact", {"target": "door"})
	await _until(func() -> bool: return _rejected == 3)
	_check(_accepted == 0, "Peers cannot interact before world readiness.")
	for slot in range(1, 4):
		_gates[slot].prepare_session(100)
		_gates[slot].confirm_loaded()
	await _until(_all_ready)
	for slot in range(1, 4):
		var channel := _roots[slot].get_node("Intent%d" % slot) as ReadyIntent
		channel.submit_reliable(&"interact", {"target": "door"})
	await _until(func() -> bool: return _accepted == 3)
	var departed: int = _roots[1].multiplayer.get_unique_id()
	_handlers[1].shutdown()
	await _until(func() -> bool: return _roots[0].multiplayer.get_peers().size() == 2)
	_check(not _gates[0].is_ready(departed), "Disconnect removes world admission.")
	for slot in range(1, 4):
		(_roots[0].get_node("Intent%d" % slot) as ReadyIntent).reset_peer_admission(departed)
	_handlers[1].start_enet_client("127.0.0.1", PORT)
	await _until(func() -> bool: return _roots[0].multiplayer.get_peers().size() == 3)
	_bind_peer(1)
	_gates[1].prepare_session(99)
	_gates[1].confirm_loaded()
	for frame in range(12):
		await get_tree().process_frame
	_check(not _gates[0].is_ready(_roots[1].multiplayer.get_unique_id()),
		"Stale readiness cannot admit a reconnected peer.")
	_gates[1].prepare_session(100)
	_gates[1].confirm_loaded()
	await _until(_all_ready)
	(_roots[1].get_node("Intent1") as ReadyIntent).submit_reliable(&"interact", {"target": "door"})
	await _until(func() -> bool: return _accepted == 4)
	_finish()


func _create_peer(index: int) -> void:
	var peer := Node.new()
	peer.name = "Peer%d" % index
	add_child(peer)
	get_tree().set_multiplayer(MultiplayerAPI.create_default_interface(), peer.get_path())
	_roots.append(peer)
	var handler := NucleusNetworkHandler.new()
	peer.add_child(handler)
	_handlers.append(handler)
	var gate := NucleusNetworkWorldReadiness.new()
	gate.name = "Readiness"
	peer.add_child(gate)
	_gates.append(gate)
	for slot in range(1, 4):
		var channel := ReadyIntent.new()
		channel.name = "Intent%d" % slot
		channel.readiness = gate
		peer.add_child(channel)
		if index == 0:
			channel.intent_received.connect(func(_a, _b, _c, _d, _e): _accepted += 1)
			channel.intent_rejected.connect(func(_a, _b, _c): _rejected += 1)


func _bind_peer(slot: int) -> void:
	var identity: int = _roots[slot].multiplayer.get_unique_id()
	_check(_gates[0].expect_peer(identity), "Server explicitly admits a connected peer.")
	for peer: Node in _roots:
		(peer.get_node("Intent%d" % slot) as ReadyIntent).controlling_peer_id = identity


func _all_ready() -> bool:
	for slot in range(1, 4):
		if not _gates[0].is_ready(_roots[slot].multiplayer.get_unique_id()):
			return false
	return true


func _until(condition: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + 5000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var success: bool = condition.call()
	_check(success, "Timed out waiting for a network composition phase.")
	return success


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error("WORLD_SESSION_SMOKE: FAIL: " + message)


func _finish() -> void:
	for handler: NucleusNetworkHandler in _handlers:
		handler.shutdown()
	if _failures == 0:
		print("WORLD_SESSION_SMOKE: PASS (3 clients, readiness, interaction, reconnect).")
	get_tree().quit(0 if _failures == 0 else 1)
