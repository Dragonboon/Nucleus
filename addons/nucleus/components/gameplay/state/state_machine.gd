class_name NucleusStateMachine
extends Node
## Scene-owned finite state machine.
##
## States are Nodes below [member state_root]. The machine forwards update and
## input callbacks only to the active state.

signal states_initialized(states: Dictionary)
signal transition_started(
	from_state: NucleusState,
	to_state: NucleusState,
	context: Dictionary,
)
signal state_changed(
	from_state: NucleusState,
	to_state: NucleusState,
	context: Dictionary,
)
signal transition_rejected(
	from_state: NucleusState,
	to_state: NucleusState,
	error: Error,
)
## request_state() was accepted for later execution, not yet applied.
signal transition_queued(state_id: StringName, context: Dictionary)
signal transition_request_discarded(state_id: StringName, reason: Error)

@export var state_root: Node
@export var initial_state: NucleusState
@export var allow_first_state_fallback: bool = true
## Optional actor controlled by the states; defaults to the machine's parent.
@export var actor: Node

@export_group("Deferred Transitions")
## Leave unset for the historical immediate-only behavior.
@export var transition_policy: NucleusStateTransitionPolicy

@export_group("History")
@export_range(0, 128, 1) var history_capacity: int = 8

@export_group("Processing")
@export var active: bool = true

var current_state: NucleusState

var _states: Dictionary[StringName, NucleusState] = {}
var _history: Array[StringName] = []
var _transitioning: bool = false
var _initialized: bool = false
var _pending: Array[Dictionary] = []
var _executing_pending: bool = false


func _ready() -> void:
	if actor == null:
		actor = get_parent()
	if state_root == null:
		state_root = self

	_prepare_states()

	if _states.is_empty():
		NucleusLog.error(
			"%s has no NucleusState children." % get_path(),
			&"StateMachine",
		)
		_set_processing(false)
		return

	if initial_state == null and allow_first_state_fallback:
		initial_state = _states.values()[0]

	if initial_state == null:
		NucleusLog.error(
			"%s requires an initial state." % get_path(),
			&"StateMachine",
		)
		_set_processing(false)
		return

	if initial_state.get_state_id() not in _states:
		NucleusLog.error(
			"Initial state '%s' is not owned by %s."
			% [initial_state.name, get_path()],
			&"StateMachine",
		)
		_set_processing(false)
		return

	_initialized = true
	_set_processing(active)

	var error: Error = _enter_initial_state(initial_state)

	if error != OK:
		NucleusLog.error(
			"Could not enter initial state '%s': %s"
			% [initial_state.get_state_id(), error_string(error)],
			&"StateMachine",
		)

	states_initialized.emit(get_states())


func _exit_tree() -> void:
	clear_pending_requests()


func set_active(enabled: bool) -> void:
	if not enabled:
		clear_pending_requests()
	active = enabled

	if _initialized:
		_set_processing(active)


func is_active() -> bool:
	return active and _initialized


func is_transitioning() -> bool:
	return _transitioning


func get_actor() -> Node:
	return actor if is_instance_valid(actor) else null


func get_pending_request_count() -> int:
	return _pending.size()


## Rejects missing/invalid states. OK means accepted, not necessarily committed.
## Prefer change_state() for transactional actions requiring immediate results.
func request_state(next_state_id: StringName, context: Dictionary = {}) -> Error:
	if not is_active():
		return ERR_UNAVAILABLE
	if not _states.has(next_state_id):
		return ERR_DOES_NOT_EXIST
	var next_state: NucleusState = _states[next_state_id]
	if not is_instance_valid(next_state) or not next_state.is_inside_tree():
		return ERR_DOES_NOT_EXIST
	var safe_context: Dictionary = context.duplicate(true)
	if _transitioning:
		return _enqueue(next_state_id, safe_context)
	if next_state == current_state:
		return OK
	if not next_state.can_enter(current_state, safe_context):
		return ERR_UNAVAILABLE
	if current_state and not current_state.can_exit(next_state, safe_context):
		return _enqueue(next_state_id, safe_context)
	return change_state(next_state_id, safe_context)


## Poll at most one accepted request. Safe to call explicitly after unlocking.
func process_pending_request() -> bool:
	if not is_active() or _transitioning or _pending.is_empty():
		return false
	var request: Dictionary = _pending[0]
	var key: StringName = request["state_id"]
	if transition_policy != null and transition_policy.timeout_seconds > 0.0:
		var elapsed: int = Time.get_ticks_msec() - int(request["queued_msec"])
		if elapsed > int(transition_policy.timeout_seconds * 1000.0):
			_pending.pop_front()
			transition_request_discarded.emit(key, ERR_TIMEOUT)
			return false
	var next_state: NucleusState = _states.get(key)
	if not is_instance_valid(next_state) or not next_state.is_inside_tree():
		_pending.pop_front()
		transition_request_discarded.emit(key, ERR_DOES_NOT_EXIST)
		return false
	if next_state == current_state:
		_pending.pop_front()
		transition_request_discarded.emit(key, ERR_ALREADY_EXISTS)
		return false
	var context: Dictionary = (request["context"] as Dictionary).duplicate(true)
	if current_state and not current_state.can_exit(next_state, context):
		return false
	if not next_state.can_enter(current_state, context):
		_pending.pop_front()
		transition_request_discarded.emit(key, ERR_UNAVAILABLE)
		return false
	_pending.pop_front()
	_executing_pending = true
	var outcome: Error = change_state(key, context)
	_executing_pending = false
	if outcome != OK:
		transition_request_discarded.emit(key, outcome)
	return outcome == OK


func clear_pending_requests() -> void:
	var obsolete: Array[Dictionary] = _pending.duplicate()
	_pending.clear()
	for request in obsolete:
		transition_request_discarded.emit(request["state_id"], ERR_UNAVAILABLE)


func _enqueue(state_id: StringName, context: Dictionary) -> Error:
	if transition_policy == null:
		return ERR_BUSY if _transitioning else ERR_UNAVAILABLE
	var limit: int = clampi(transition_policy.capacity, 1, 16)
	if _pending.size() >= limit:
		if not transition_policy.replace_latest:
			return ERR_BUSY
		var discarded: Dictionary = _pending.pop_back()
		transition_request_discarded.emit(discarded["state_id"], ERR_BUSY)
	_pending.append({
		"state_id": state_id,
		"context": context.duplicate(true),
		"queued_msec": Time.get_ticks_msec(),
	})
	transition_queued.emit(state_id, context.duplicate(true))
	return OK


func get_state(
	state_id: StringName,
) -> NucleusState:
	return _states.get(state_id)


func has_state(state_id: StringName) -> bool:
	return _states.has(state_id)


func get_states() -> Dictionary:
	return _states.duplicate()


func get_history() -> Array[StringName]:
	return _history.duplicate()


func get_previous_state_id() -> StringName:
	return _history.back() if not _history.is_empty() else &""


func change_state(
	next_state_id: StringName,
	context: Dictionary = {},
) -> Error:
	if not is_active():
		return ERR_UNAVAILABLE
	if _transitioning:
		return ERR_BUSY
	if not _states.has(next_state_id):
		return ERR_DOES_NOT_EXIST
	var next_state: NucleusState = _states[next_state_id]
	if not is_instance_valid(next_state) or not next_state.is_inside_tree():
		return ERR_DOES_NOT_EXIST
	if next_state == current_state:
		return OK
	var safe_context: Dictionary = context.duplicate(true)
	if current_state and not current_state.can_exit(next_state, safe_context):
		transition_rejected.emit(current_state, next_state, ERR_UNAVAILABLE)
		return ERR_UNAVAILABLE
	if not next_state.can_enter(current_state, safe_context):
		transition_rejected.emit(current_state, next_state, ERR_UNAVAILABLE)
		return ERR_UNAVAILABLE
	if not _executing_pending:
		clear_pending_requests()
	_commit_transition(next_state, safe_context, true)
	return OK


## Deliberately restarts the same state without adding a duplicate history entry.
func restart_state(context: Dictionary = {}) -> Error:
	if not is_active() or current_state == null:
		return ERR_UNAVAILABLE
	if _transitioning:
		return ERR_BUSY
	var safe_context: Dictionary = context.duplicate(true)
	if not current_state.can_exit(current_state, safe_context):
		return ERR_UNAVAILABLE
	if not current_state.can_enter(current_state, safe_context):
		return ERR_UNAVAILABLE
	clear_pending_requests()
	_commit_transition(current_state, safe_context, false)
	return OK


func _commit_transition(
	next_state: NucleusState,
	context: Dictionary,
	record_history: bool,
) -> void:
	_transitioning = true
	var previous_state: NucleusState = current_state
	transition_started.emit(previous_state, next_state, context)
	if previous_state:
		if record_history:
			_push_history(previous_state.get_state_id())
		previous_state.exit(next_state)
		previous_state.exited.emit(next_state)
	current_state = next_state
	current_state.enter(previous_state, context)
	current_state.entered.emit(previous_state, context)
	_transitioning = false
	state_changed.emit(previous_state, current_state, context)


func capture_state() -> Dictionary:
	return {
		"current_state": (
			String(current_state.get_state_id())
			if current_state
			else ""
		),
		"history": _history.duplicate(),
	}


func restore_state(data: Dictionary) -> Error:
	if not _initialized:
		return ERR_UNCONFIGURED
	var state_id := StringName(str(data.get("current_state", "")))
	if state_id == &"" or not _states.has(state_id):
		return ERR_DOES_NOT_EXIST
	var supplied_history: Variant = data.get("history", [])
	if not supplied_history is Array:
		return ERR_INVALID_DATA
	var restored_history: Array[StringName] = []
	for value: Variant in supplied_history:
		var history_id := StringName(str(value))
		if _states.has(history_id):
			restored_history.append(history_id)
	if current_state != _states[state_id]:
		var outcome: Error = change_state(state_id, {"restored": true})
		if outcome != OK:
			return outcome
	# History is committed only after the requested transition succeeds.
	_history = restored_history
	_trim_history()
	clear_pending_requests()
	return OK


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)
	process_pending_request()


func _input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_unhandled_input(event)


func _prepare_states() -> void:
	_states.clear()

	for node: Node in NucleusNodeUtils.descendants(
		state_root,
		true,
	):
		if not (node is NucleusState):
			continue

		if _belongs_to_nested_machine(node):
			continue

		var state := node as NucleusState
		var state_id: StringName = state.get_state_id()

		if state_id == &"":
			NucleusLog.error(
				"State %s has an empty state id." % state.get_path(),
				&"StateMachine",
			)
			continue

		if _states.has(state_id):
			NucleusLog.error(
				"Duplicate state id '%s' in %s."
				% [state_id, get_path()],
				&"StateMachine",
			)
			continue

		state.machine = self
		_states[state_id] = state
		state.state_ready()


func _belongs_to_nested_machine(node: Node) -> bool:
	var current: Node = node.get_parent()

	while current and current != state_root:
		if (
			current is NucleusStateMachine
			and current != self
		):
			return true

		current = current.get_parent()

	return false


func _enter_initial_state(state: NucleusState) -> Error:
	if not state.can_enter(null, {}):
		return ERR_UNAVAILABLE

	current_state = state
	_transitioning = true
	current_state.enter(null, {})
	current_state.entered.emit(null, {})
	_transitioning = false

	return OK


func _push_history(state_id: StringName) -> void:
	if history_capacity <= 0:
		return

	_history.append(state_id)
	_trim_history()


func _trim_history() -> void:
	while _history.size() > history_capacity:
		_history.pop_front()


func _set_processing(is_enabled: bool) -> void:
	set_process(is_enabled)
	set_physics_process(is_enabled)
	set_process_input(is_enabled)
	set_process_unhandled_input(is_enabled)
