class_name NucleusNetworkInterestController3D
extends Node
## Scene-owned, server-only interest decisions for replicated 3D entities.
## The game supplies authoritative positions and applies native visibility.

signal entity_entered_interest(peer_id: int, entity_id: StringName)
signal entity_exited_interest(peer_id: int, entity_id: StringName)

@export_group("Spatial policy")
@export_range(1.0, 100000.0, 1.0, "or_greater")
var cell_size: float = 32.0
@export_range(0.0, 100000.0, 1.0, "or_greater")
var interest_radius: float = 96.0
@export_range(0, 1024, 1)
var max_relevant_entities: int = 128

@export_group("Admission budgets")
@export_range(0, 128, 1)
var max_enters_per_peer_per_pump: int = 8
@export_range(0, 128, 1)
var max_exits_per_peer_per_pump: int = 16
@export_range(1, 128, 1)
var max_peers_per_pump: int = 8
@export_range(1, 1024, 1)
var max_tracked_peers: int = 128
@export var process_automatically: bool = true

var _grid := NucleusNetworkInterestGrid3D.new()
var _peer_trackers: Dictionary = {}
var _peer_positions: Dictionary = {}
var _peer_order: Array[int] = []
var _peer_cursor: int = 0


func _ready() -> void:
	set_process(process_automatically)


func _process(_delta: float) -> void:
	pump()


func set_automatic_processing(enabled: bool) -> void:
	process_automatically = enabled
	set_process(enabled)


func upsert_entity(entity_id: StringName, position: Vector3) -> Error:
	if not _has_server_authority():
		return ERR_UNAUTHORIZED
	var error: Error = _configure_grid()
	if error != OK:
		return error
	return _grid.upsert_entity(entity_id, position)


func remove_entity(entity_id: StringName) -> Error:
	if not _has_server_authority():
		return ERR_UNAUTHORIZED
	if not _grid.remove_entity(entity_id):
		return ERR_DOES_NOT_EXIST

	for peer_id: int in _peer_order.duplicate():
		var tracker: NucleusNetworkInterestReconciler = _peer_trackers[peer_id]
		tracker.forget_entity(entity_id)
	return OK


func update_peer_interest(
	peer_id: int,
	authoritative_position: Vector3,
) -> Error:
	if not _has_server_authority():
		return ERR_UNAUTHORIZED
	if peer_id <= 0 or not NucleusNetworkInterestGrid3D.is_valid_position(authoritative_position):
		return ERR_INVALID_PARAMETER

	var error: Error = _configure_grid()
	if error != OK:
		return error
	if not _grid.is_supported_radius(interest_radius):
		return ERR_INVALID_PARAMETER

	if not _peer_trackers.has(peer_id):
		if _peer_order.size() >= max_tracked_peers:
			return ERR_BUSY
		_add_peer(peer_id)

	_peer_positions[peer_id] = authoritative_position
	var tracker: NucleusNetworkInterestReconciler = _peer_trackers[peer_id]
	tracker.set_desired_entities(_grid.query_radius(
		authoritative_position,
		interest_radius,
		max_relevant_entities,
	))
	return OK


func refresh_peer_interest(peer_id: int) -> Error:
	if not _has_server_authority():
		return ERR_UNAUTHORIZED
	if not _peer_positions.has(peer_id):
		return ERR_DOES_NOT_EXIST

	var position: Vector3 = _peer_positions[peer_id]
	return update_peer_interest(peer_id, position)


func remove_peer(peer_id: int) -> Error:
	if not _has_server_authority():
		return ERR_UNAUTHORIZED
	if not _peer_trackers.has(peer_id):
		return ERR_DOES_NOT_EXIST

	var tracker: NucleusNetworkInterestReconciler = _peer_trackers[peer_id]
	tracker.clear_immediately()
	_peer_trackers.erase(peer_id)
	_peer_positions.erase(peer_id)
	_peer_order.erase(peer_id)
	if _peer_order.is_empty():
		_peer_cursor = 0
	else:
		_peer_cursor %= _peer_order.size()
	return OK


func get_admitted_entities(peer_id: int) -> Array[StringName]:
	if not _peer_trackers.has(peer_id):
		var empty: Array[StringName] = []
		return empty
	var tracker: NucleusNetworkInterestReconciler = _peer_trackers[peer_id]
	return tracker.get_admitted_entities()


func get_debug_snapshot() -> Dictionary:
	var pending: int = 0
	var admitted: int = 0
	for peer_id: int in _peer_order:
		var tracker: NucleusNetworkInterestReconciler = _peer_trackers[peer_id]
		pending += tracker.get_pending_count()
		admitted += tracker.get_admitted_entities().size()

	return {
		"entities": _grid.get_entity_count(),
		"peers": _peer_order.size(),
		"admitted_memberships": admitted,
		"pending_changes": pending,
	}


func pump() -> void:
	if not _has_server_authority() or _peer_order.is_empty():
		return

	var count: int = mini(max_peers_per_pump, _peer_order.size())
	for index: int in range(count):
		if _peer_order.is_empty():
			break
		_peer_cursor %= _peer_order.size()
		var peer_id: int = _peer_order[_peer_cursor]
		_peer_cursor = (_peer_cursor + 1) % _peer_order.size()
		var tracker: NucleusNetworkInterestReconciler = _peer_trackers[peer_id]
		tracker.max_enters_per_pump = max_enters_per_peer_per_pump
		tracker.max_exits_per_pump = max_exits_per_peer_per_pump
		tracker.pump()


func _configure_grid() -> Error:
	if not is_finite(cell_size) or cell_size <= 0.0:
		return ERR_INVALID_PARAMETER
	return _grid.set_cell_size(cell_size)


func _has_server_authority() -> bool:
	return is_inside_tree() and multiplayer.is_server()


func _add_peer(peer_id: int) -> void:
	var tracker := NucleusNetworkInterestReconciler.new()
	tracker.entity_entered.connect(_on_entered.bind(peer_id))
	tracker.entity_exited.connect(_on_exited.bind(peer_id))
	_peer_trackers[peer_id] = tracker
	_peer_order.append(peer_id)


func _on_entered(entity_id: StringName, peer_id: int) -> void:
	entity_entered_interest.emit(peer_id, entity_id)


func _on_exited(entity_id: StringName, peer_id: int) -> void:
	entity_exited_interest.emit(peer_id, entity_id)
