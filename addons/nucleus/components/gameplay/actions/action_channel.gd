class_name NucleusActionChannel
extends Node
## Optional windup/recovery around a synchronous GameplayAction transaction.
## Interrupting a windup prevents payment; committed effects cannot be undone.

signal phase_changed(phase: int)
signal action_finished(error: Error)
signal action_interrupted(priority: int, reason: StringName)

enum Phase { IDLE, WINDUP, RECOVERY }

@export var action: NucleusGameplayAction
@export_range(0.0, 3600.0, 0.01, "or_greater") var windup_seconds: float = 0.0
@export_range(0.0, 3600.0, 0.01, "or_greater") var recovery_seconds: float = 0.0
@export var minimum_interrupt_priority: int = 0

var phase: Phase = Phase.IDLE
var _remaining: float = 0.0
var _context: Dictionary = {}


func _ready() -> void:
	set_process(false)


func start_action(context: Dictionary = {}) -> Error:
	if phase != Phase.IDLE:
		return ERR_BUSY
	if action == null or not is_instance_valid(action):
		return ERR_UNCONFIGURED
	var error: Error = action.get_execution_error(context)
	if error != OK:
		return error
	_context = context.duplicate(true)
	_remaining = maxf(0.0, windup_seconds)
	_set_phase(Phase.WINDUP)
	advance(0.0)
	return OK


func is_running() -> bool:
	return phase != Phase.IDLE


func interrupt_action(priority: int, reason: StringName = &"interrupt") -> Error:
	if not is_running():
		return ERR_DOES_NOT_EXIST
	if priority < minimum_interrupt_priority:
		return ERR_UNAVAILABLE
	_set_phase(Phase.IDLE)
	_remaining = 0.0
	_context.clear()
	action_interrupted.emit(priority, reason)
	action_finished.emit(ERR_BUSY)
	return OK


func advance(delta: float) -> void:
	if is_nan(delta) or is_inf(delta) or delta < 0.0:
		return
	var budget: float = delta
	while is_running():
		if _remaining > budget:
			_remaining -= budget
			break
		budget -= _remaining
		_remaining = 0.0
		if phase == Phase.WINDUP:
			if action == null or not is_instance_valid(action):
				_finish(ERR_UNCONFIGURED)
				break
			var error: Error = action.try_execute(_context)
			if error != OK:
				_finish(error)
				break
			_remaining = maxf(0.0, recovery_seconds)
			_set_phase(Phase.RECOVERY)
		elif phase == Phase.RECOVERY:
			_finish(OK)
			break


func _process(delta: float) -> void:
	advance(delta)


func _set_phase(next: Phase) -> void:
	phase = next
	set_process(phase != Phase.IDLE)
	phase_changed.emit(phase)


func _finish(error: Error) -> void:
	_set_phase(Phase.IDLE)
	_remaining = 0.0
	_context.clear()
	action_finished.emit(error)
