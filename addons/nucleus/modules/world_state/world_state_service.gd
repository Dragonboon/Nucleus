class_name NucleusWorldStateService
extends Node
## Optional cross-scene runtime owner for persistent world state.
##
## Keep this Node alive across scene replacement (for example under a persistent
## GameSession or as an intentional opt-in Autoload) when world state must
## survive NucleusSceneFlow/SceneTree scene changes.

signal state_restored
signal state_cleared
signal region_activated(region_id: StringName, region: NucleusWorldRegion)

@export var save_session: NucleusSaveSession
@export var save_participant_id: StringName = &"world_state"

var _store := NucleusWorldStateStore.new()
var _active_regions: Dictionary[String, NucleusWorldRegion] = {}
var _bound_save_session: NucleusSaveSession
var _bound_participant_id: StringName = &""


func _ready() -> void:
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)

	if not get_tree().node_removed.is_connected(_on_node_removed):
		get_tree().node_removed.connect(_on_node_removed)

	if save_session != null:
		bind_save_session(
			save_session,
			save_participant_id,
		)

	call_deferred(&"_scan_current_scene")


func _exit_tree() -> void:
	if get_tree() != null:
		if get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.disconnect(_on_node_added)

		if get_tree().node_removed.is_connected(_on_node_removed):
			get_tree().node_removed.disconnect(_on_node_removed)

	unbind_save_session()
	_active_regions.clear()


func get_store() -> NucleusWorldStateStore:
	return _store


func bind_save_session(
	session: NucleusSaveSession,
	participant_id: StringName = &"world_state",
) -> Error:
	if session == null or participant_id == &"":
		return ERR_INVALID_PARAMETER

	unbind_save_session()

	var error: Error = session.register_participant(
		participant_id,
		capture_state,
		restore_state,
	)

	if error != OK:
		return error

	_bound_save_session = session
	_bound_participant_id = participant_id
	save_session = session
	save_participant_id = participant_id

	return OK


func unbind_save_session() -> void:
	if (
		_bound_save_session != null
		and is_instance_valid(_bound_save_session)
		and _bound_participant_id != &""
	):
		_bound_save_session.unregister_participant(
			_bound_participant_id
		)

	_bound_save_session = null
	_bound_participant_id = &""


func register_region(
	region: NucleusWorldRegion,
) -> Error:
	if region == null or region.region_id == &"":
		return ERR_INVALID_PARAMETER

	var key: String = String(region.region_id)

	if _active_regions.has(key):
		var existing: NucleusWorldRegion = _active_regions[key]

		if existing == region:
			return OK

		if existing != null and is_instance_valid(existing):
			NucleusLog.error(
				"World region '%s' is already active." % region.region_id,
				&"WorldState",
			)
			return ERR_ALREADY_EXISTS

		_active_regions.erase(key)

	var error: Error = region.activate(self)

	if error != OK:
		return error

	_active_regions[key] = region
	region_activated.emit(
		region.region_id,
		region,
	)

	return OK


func unregister_region(
	region: NucleusWorldRegion,
) -> void:
	if region == null or region.region_id == &"":
		return

	var key: String = String(region.region_id)

	if (
		_active_regions.get(key) == region
	):
		_active_regions.erase(key)


func commit_active_regions() -> void:
	var regions: Array[NucleusWorldRegion] = []

	for key: String in _active_regions:
		var region: NucleusWorldRegion = _active_regions[key]

		if region != null and is_instance_valid(region):
			regions.append(region)

	for region: NucleusWorldRegion in regions:
		region.commit_all()


func reconcile_active_regions() -> void:
	var regions: Array[NucleusWorldRegion] = []

	for key: String in _active_regions:
		var region: NucleusWorldRegion = _active_regions[key]

		if region != null and is_instance_valid(region):
			regions.append(region)

	for region: NucleusWorldRegion in regions:
		region.reconcile()


func capture_state() -> Dictionary:
	commit_active_regions()
	return _store.capture_state()


func restore_state(data: Dictionary) -> Error:
	var error: Error = _store.restore_state(data)

	if error != OK:
		return error

	reconcile_active_regions()
	state_restored.emit()
	return OK


func clear_state() -> void:
	_store.clear()
	state_cleared.emit()


func _scan_current_scene() -> void:
	if not is_inside_tree():
		return

	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		return

	if current_scene is NucleusWorldRegion:
		register_region(
			current_scene as NucleusWorldRegion
		)

	for node: Node in NucleusNodeUtils.descendants(current_scene):
		if node is NucleusWorldRegion:
			register_region(
				node as NucleusWorldRegion
			)


func _on_node_added(node: Node) -> void:
	if node is NucleusWorldRegion:
		call_deferred(
			&"_register_region_deferred",
			node,
		)


func _register_region_deferred(node: Node) -> void:
	if (
		node == null
		or not is_instance_valid(node)
		or not node.is_inside_tree()
		or not node is NucleusWorldRegion
	):
		return

	register_region(
		node as NucleusWorldRegion
	)


func _on_node_removed(node: Node) -> void:
	if node is NucleusWorldRegion:
		unregister_region(
			node as NucleusWorldRegion
		)
