class_name NucleusTargetingAgent
extends Node
## Scene-owned candidate registry, selector, and lock-on state.
##
## Sensors register candidates by source ownership. Filters validate candidates,
## scorers rank them, and consumers observe [signal current_changed].

signal candidate_added(target: NucleusTargetable)
signal candidate_removed(target: NucleusTargetable)
signal current_changed(
	current: NucleusTargetable,
	previous: NucleusTargetable,
)
signal target_locked(target: NucleusTargetable)
signal target_unlocked(target: NucleusTargetable)
signal selection_refreshed(current: NucleusTargetable)

@export var source: Node
@export var origin: Node
@export var orientation_source: Node
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return

		enabled = value

		if not is_node_ready():
			return

		if enabled:
			request_refresh()
		else:
			unlock_target()
			set_current(null)

@export_group("Rules")
@export var rules_root: Node
@export_range(0.0, 100000.0, 0.01, "or_greater")
var current_target_bonus: float = 0.25

@export_group("Refresh")
@export var automatic_refresh: bool = true
@export_range(0.0, 10.0, 0.01, "or_greater")
var refresh_interval: float = 0.10
@export var refresh_physics_priority: int = 100
## Assign before entering the tree. Immediate refresh_selection() remains available.
@export var update_scheduler: NucleusUpdateScheduler
var _scheduler_token: int = -1

var current: NucleusTargetable

var _locked_target: NucleusTargetable
var _filters: Array[NucleusTargetFilter] = []
var _scorers: Array[NucleusTargetScorer] = []

var _candidates: Dictionary[int, NucleusTargetable] = {}
var _candidate_sources: Dictionary[int, Dictionary] = {}

var _refresh_elapsed: float = 0.0
var _refresh_requested: bool = true
var _ranked_cache: Array[NucleusTargetable] = []


func _enter_tree() -> void:
	_prune_invalid_candidates()
	for target: NucleusTargetable in _candidates.values():
		_connect_target(target)
	if is_node_ready():
		_connect_rules()
		request_refresh()
		_register_scheduled_refresh()


func _ready() -> void:
	if source == null:
		source = get_parent()

	if origin == null:
		origin = source

	if orientation_source == null:
		orientation_source = source

	if rules_root == null:
		rules_root = self

	process_physics_priority = refresh_physics_priority

	_discover_rules()
	_connect_rules()

	_register_scheduled_refresh()
	set_physics_process(automatic_refresh and _scheduler_token == -1)


func _exit_tree() -> void:
	if is_instance_valid(update_scheduler) and _scheduler_token != -1:
		update_scheduler.unregister_task(_scheduler_token)
	_scheduler_token = -1
	_disconnect_rules()
	_disconnect_all_targets()


func _physics_process(delta: float) -> void:
	if not automatic_refresh:
		return

	_refresh_elapsed += delta

	if (
		not _refresh_requested
		and refresh_interval > 0.0
		and _refresh_elapsed < refresh_interval
	):
		return

	_refresh_elapsed = 0.0
	_refresh_requested = false
	refresh_selection()


func register_candidate(
	target: NucleusTargetable,
	registration_source: Object = null,
) -> Error:
	if target == null:
		return ERR_INVALID_PARAMETER

	var target_id: int = target.get_instance_id()
	var source_object: Object = (
		registration_source
		if registration_source
		else target
	)
	var source_id: int = source_object.get_instance_id()

	var sources: Dictionary = _candidate_sources.get(
		target_id,
		{},
	)

	if sources.has(source_id):
		return ERR_ALREADY_EXISTS

	sources[source_id] = true
	_candidate_sources[target_id] = sources

	if _candidates.has(target_id):
		request_refresh()
		return OK

	_candidates[target_id] = target
	_connect_target(target)

	candidate_added.emit(target)
	request_refresh()

	return OK


func unregister_candidate(
	target: NucleusTargetable,
	registration_source: Object = null,
) -> void:
	if target == null:
		return

	var target_id: int = target.get_instance_id()

	if not _candidates.has(target_id):
		return

	var source_object: Object = (
		registration_source
		if registration_source
		else target
	)
	var source_id: int = source_object.get_instance_id()
	var sources: Dictionary = _candidate_sources.get(
		target_id,
		{},
	)

	if not sources.has(source_id):
		return

	sources.erase(source_id)

	if not sources.is_empty():
		_candidate_sources[target_id] = sources
		return

	_remove_candidate(target_id)


func unregister_candidate_all(
	target: NucleusTargetable,
) -> void:
	if target == null:
		return

	_remove_candidate(target.get_instance_id())


func clear_candidates() -> void:
	_prune_invalid_candidates()
	var ids: Array = _candidates.keys()

	for target_id: Variant in ids:
		_remove_candidate(int(target_id))


func request_refresh() -> void:
	_refresh_requested = true
	if is_instance_valid(update_scheduler) and _scheduler_token != -1:
		update_scheduler.request_task(_scheduler_token)


func refresh_rules() -> void:
	_disconnect_rules()
	_discover_rules()
	_connect_rules()
	request_refresh()


func refresh_selection(
	context: Dictionary = {},
) -> void:
	_prune_invalid_candidates()

	if not enabled:
		if is_locked():
			unlock_target()

		set_current(null)
		_ranked_cache.clear()
		selection_refreshed.emit(current)
		return

	if (
		_locked_target
		and _is_candidate_valid(
			_locked_target,
			context,
		)
	):
		set_current(_locked_target)
		selection_refreshed.emit(current)
		return

	if _locked_target:
		unlock_target()

	var ranked: Array[NucleusTargetable] = get_ranked_candidates(
		context
	)
	_ranked_cache.clear()
	_ranked_cache.append_array(ranked)

	set_current(
		ranked[0]
		if not ranked.is_empty()
		else null
	)

	selection_refreshed.emit(current)


func get_ranked_candidates(
	context: Dictionary = {},
) -> Array[NucleusTargetable]:
	_prune_invalid_candidates()

	var entries: Array[Dictionary] = []

	for target: NucleusTargetable in _candidates.values():
		if not _is_candidate_valid(target, context):
			continue

		entries.append(
			{
				"target": target,
				"score": _score_target(
					target,
					context,
				),
				"id": target.get_instance_id(),
			}
		)

	entries.sort_custom(_compare_rank_entries)

	var result: Array[NucleusTargetable] = []

	for entry: Dictionary in entries:
		result.append(
			entry["target"] as NucleusTargetable
		)

	return result


func get_cached_ranked_candidates() -> Array[NucleusTargetable]:
	_prune_ranked_cache()

	var result: Array[NucleusTargetable] = []
	result.append_array(_ranked_cache)
	return result


func get_candidates() -> Array[NucleusTargetable]:
	_prune_invalid_candidates()

	var result: Array[NucleusTargetable] = []

	for target: NucleusTargetable in _candidates.values():
		result.append(target)

	return result


func has_candidate(target: NucleusTargetable) -> bool:
	return (
		target != null
		and _candidates.has(target.get_instance_id())
	)


func set_current(target: NucleusTargetable) -> Error:
	if target and not has_candidate(target):
		return ERR_DOES_NOT_EXIST

	if current == target:
		return OK

	var previous: NucleusTargetable = current
	current = target
	current_changed.emit(
		current,
		previous,
	)

	return OK


func lock_current() -> Error:
	if current == null:
		request_refresh()
		return ERR_DOES_NOT_EXIST

	return lock_target(current)


func lock_target(target: NucleusTargetable) -> Error:
	if not enabled:
		return ERR_UNAVAILABLE

	if target == null or not has_candidate(target):
		return ERR_DOES_NOT_EXIST

	_prune_ranked_cache()

	if target != current and target not in _ranked_cache:
		return ERR_UNAVAILABLE

	if _locked_target == target:
		return OK

	var previous: NucleusTargetable = _locked_target
	_locked_target = target
	set_current(target)

	if previous:
		target_unlocked.emit(previous)

	target_locked.emit(target)

	return OK


func unlock_target() -> void:
	if _locked_target == null:
		return

	var previous: NucleusTargetable = _locked_target
	_locked_target = null
	target_unlocked.emit(previous)
	request_refresh()


func toggle_lock() -> Error:
	if is_locked():
		unlock_target()
		return OK

	return lock_current()


func is_locked() -> bool:
	return (
		_locked_target != null
		and is_instance_valid(_locked_target)
	)


func get_locked_target() -> NucleusTargetable:
	return _locked_target if is_locked() else null


func select_next(
	context: Dictionary = {},
) -> NucleusTargetable:
	return _cycle_selection(
		true,
		context,
	)


func select_previous(
	context: Dictionary = {},
) -> NucleusTargetable:
	return _cycle_selection(
		false,
		context,
	)


func _cycle_selection(
	forward: bool,
	_context: Dictionary,
) -> NucleusTargetable:
	var ranked: Array[NucleusTargetable] = (
		get_cached_ranked_candidates()
	)

	if ranked.is_empty():
		request_refresh()
		set_current(null)

		if is_locked():
			unlock_target()

		return null

	var next_target: NucleusTargetable

	if current == null or current not in ranked:
		next_target = ranked[0]
	elif ranked.size() == 1:
		next_target = ranked[0]
	else:
		var value: Variant = (
			NucleusArrayUtils.circular_next(
				ranked,
				current,
			)
			if forward
			else NucleusArrayUtils.circular_previous(
				ranked,
				current,
			)
		)
		next_target = value as NucleusTargetable

	if is_locked():
		lock_target(next_target)
	else:
		set_current(next_target)

	return next_target


func _is_candidate_valid(
	target: NucleusTargetable,
	context: Dictionary,
) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if not target.can_be_targeted(
		source,
		context,
	):
		return false

	for filter: NucleusTargetFilter in _filters:
		if (
			filter.enabled
			and not filter.accepts(
				self,
				target,
				context,
			)
		):
			return false

	return true


func _score_target(
	target: NucleusTargetable,
	context: Dictionary,
) -> float:
	var result: float = target.priority

	if target == current and not is_locked():
		result += current_target_bonus

	for scorer: NucleusTargetScorer in _scorers:
		result += scorer.get_weighted_score(
			self,
			target,
			context,
		)

	return result


func _compare_rank_entries(
	left: Dictionary,
	right: Dictionary,
) -> bool:
	var left_score: float = float(left["score"])
	var right_score: float = float(right["score"])

	if not is_equal_approx(left_score, right_score):
		return left_score > right_score

	return int(left["id"]) < int(right["id"])


func _remove_candidate(target_id: int) -> void:
	if not _candidates.has(target_id):
		return

	var target: NucleusTargetable = _candidates[target_id]

	_candidate_sources.erase(target_id)
	_candidates.erase(target_id)
	_ranked_cache.erase(target)
	_disconnect_target(target)

	if _locked_target == target:
		unlock_target()

	if current == target:
		set_current(null)

	candidate_removed.emit(target)
	request_refresh()


func _prune_invalid_candidates() -> void:
	var ids: Array = _candidates.keys()

	for target_id: Variant in ids:
		var target: Variant = _candidates[int(target_id)]

		if target and is_instance_valid(target):
			continue

		_candidate_sources.erase(int(target_id))
		_candidates.erase(int(target_id))

	if current and not is_instance_valid(current):
		current = null

	if _locked_target and not is_instance_valid(_locked_target):
		_locked_target = null


func _prune_ranked_cache() -> void:
	for index: int in range(
		_ranked_cache.size() - 1,
		-1,
		-1,
	):
		var target: Variant = _ranked_cache[index]

		if (
			target
			and is_instance_valid(target)
			and has_candidate(target)
		):
			continue

		_ranked_cache.remove_at(index)


func _discover_rules() -> void:
	_filters.clear()
	_scorers.clear()

	if rules_root == null:
		return

	for node: Node in NucleusNodeUtils.descendants(
		rules_root,
		true,
	):
		if node is NucleusTargetFilter:
			_filters.append(node as NucleusTargetFilter)
		elif node is NucleusTargetScorer:
			_scorers.append(node as NucleusTargetScorer)


func _connect_rules() -> void:
	for filter: NucleusTargetFilter in _filters:
		if not filter.rule_changed.is_connected(request_refresh):
			filter.rule_changed.connect(request_refresh)

	for scorer: NucleusTargetScorer in _scorers:
		if not scorer.rule_changed.is_connected(request_refresh):
			scorer.rule_changed.connect(request_refresh)


func _disconnect_rules() -> void:
	for filter: NucleusTargetFilter in _filters:
		if filter.rule_changed.is_connected(request_refresh):
			filter.rule_changed.disconnect(request_refresh)

	for scorer: NucleusTargetScorer in _scorers:
		if scorer.rule_changed.is_connected(request_refresh):
			scorer.rule_changed.disconnect(request_refresh)


func _connect_target(target: NucleusTargetable) -> void:
	var exiting := _on_target_tree_exiting.bind(target.get_instance_id())
	if not target.tree_exiting.is_connected(exiting):
		target.tree_exiting.connect(exiting)
	if not target.availability_changed.is_connected(
		_on_target_availability_changed
	):
		target.availability_changed.connect(
			_on_target_availability_changed
		)

	if not target.ranking_changed.is_connected(request_refresh):
		target.ranking_changed.connect(request_refresh)


func _disconnect_target(target: NucleusTargetable) -> void:
	if target == null or not is_instance_valid(target):
		return

	var exiting := _on_target_tree_exiting.bind(target.get_instance_id())
	if target.tree_exiting.is_connected(exiting):
		target.tree_exiting.disconnect(exiting)

	if target.availability_changed.is_connected(
		_on_target_availability_changed
	):
		target.availability_changed.disconnect(
			_on_target_availability_changed
		)

	if target.ranking_changed.is_connected(request_refresh):
		target.ranking_changed.disconnect(request_refresh)


func _disconnect_all_targets() -> void:
	for target: Variant in _candidates.values():
		if is_instance_valid(target):
			_disconnect_target(target)


func _on_target_availability_changed(
	_available: bool,
) -> void:
	request_refresh()


func _on_target_tree_exiting(target_id: int) -> void:
	# Remove while signals can still carry a valid endpoint.
	_remove_candidate(target_id)


func _register_scheduled_refresh() -> void:
	if not automatic_refresh or refresh_interval <= 0.0 or _scheduler_token != -1:
		return
	if not is_instance_valid(update_scheduler):
		return
	_scheduler_token = update_scheduler.register_task(_scheduled_refresh, refresh_interval)
	set_physics_process(_scheduler_token == -1)


func _scheduled_refresh(_elapsed: float) -> void:
	if not is_inside_tree() or not can_process() or not automatic_refresh or not enabled:
		return
	_refresh_elapsed = 0.0
	_refresh_requested = false
	refresh_selection()
