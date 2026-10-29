class_name NucleusReactionCoordinator
extends Node
## Scene-local reactions; callers own which combat events open reaction windows.

signal reaction_executed(event_id: StringName, action_id: StringName)
signal reaction_rejected(event_id: StringName, error: Error)
signal window_closed(window_id: StringName)

@export var action_set: NucleusActionSet
@export var channel: NucleusActionChannel
@export var reactions: Array[NucleusReactionDefinition] = []

# Window ID -> seconds left; -1 means explicitly closed only.
var _windows: Dictionary[StringName, float] = {}


func _ready() -> void:
	set_process(false)


func open_window(window_id: StringName, seconds: float = 0.0) -> Error:
	if window_id == &"" or is_nan(seconds) or is_inf(seconds) or seconds < 0.0:
		return ERR_INVALID_PARAMETER
	_windows[window_id] = seconds if seconds > 0.0 else -1.0
	set_process(true)
	return OK


func has_window(window_id: StringName) -> bool:
	return _windows.has(window_id)


func close_window(window_id: StringName) -> bool:
	if not _windows.erase(window_id):
		return false
	window_closed.emit(window_id)
	set_process(not _windows.is_empty())
	return true


func clear_windows() -> void:
	for window_id: StringName in _windows.keys():
		close_window(window_id)


func react(event_id: StringName, context: Dictionary = {}) -> Error:
	if action_set == null:
		return ERR_UNCONFIGURED
	var ordered: Array[NucleusReactionDefinition] = []
	for definition: NucleusReactionDefinition in reactions:
		if definition == null or definition.event_id != event_id:
			continue
		if definition.window_id != &"" and not has_window(definition.window_id):
			continue
		var index: int = 0
		while index < ordered.size() and ordered[index].priority >= definition.priority:
			index += 1
		ordered.insert(index, definition)
	var last_error: Error = ERR_DOES_NOT_EXIST
	for definition: NucleusReactionDefinition in ordered:
		var action: NucleusGameplayAction = action_set.get_action(definition.action_id)
		if action == null:
			last_error = ERR_DOES_NOT_EXIST
			continue
		last_error = action.get_execution_error(context)
		if last_error != OK:
			continue
		if channel != null and channel.is_running():
			last_error = channel.interrupt_action(definition.interrupt_priority, event_id)
			if last_error != OK:
				continue
		last_error = action.try_execute(context)
		if last_error == OK:
			reaction_executed.emit(event_id, definition.action_id)
			return OK
	reaction_rejected.emit(event_id, last_error)
	return last_error


func advance(delta: float) -> void:
	if delta < 0.0 or is_nan(delta) or is_inf(delta):
		return
	for window_id: StringName in _windows.keys():
		var remaining: float = _windows[window_id]
		if remaining < 0.0:
			continue
		remaining -= delta
		if remaining <= 0.0:
			close_window(window_id)
		else:
			_windows[window_id] = remaining


func _process(delta: float) -> void:
	advance(delta)
