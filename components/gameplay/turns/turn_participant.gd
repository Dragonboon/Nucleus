class_name NucleusTurnParticipant
extends Node
## Scene-owned turn seat. Actor may be any Node; it need not be a combatant.

signal turn_started(round_number: int)
signal turn_ended(reason: StringName)
signal turn_skipped(reason: StringName)
signal blocked_opportunities_changed(remaining: int)

@export var participant_id: StringName
@export var actor: Node
@export var enabled: bool = true
@export var initiative: int = 0
## -1 inherits the session default; 0 has no timeout.
@export var turn_seconds: float = -1.0

var blocked_opportunities: int = 0
var _session: NucleusTurnSession


func _ready() -> void:
	if actor == null:
		actor = get_parent()


func get_session() -> NucleusTurnSession:
	return _session


func end_turn() -> Error:
	if _session == null:
		return ERR_UNAVAILABLE
	return _session.complete_turn(self)


func skip_turn() -> Error:
	if _session == null:
		return ERR_UNAVAILABLE
	return _session.skip_turn(self)


func block_turns(count: int) -> Error:
	if count < 1 or count > 2147483647 - blocked_opportunities:
		return ERR_INVALID_PARAMETER
	blocked_opportunities += count
	blocked_opportunities_changed.emit(blocked_opportunities)
	return OK


func clear_blocks() -> void:
	if blocked_opportunities == 0:
		return
	blocked_opportunities = 0
	blocked_opportunities_changed.emit(0)


func consume_blocked_opportunity() -> bool:
	if blocked_opportunities <= 0:
		return false
	blocked_opportunities -= 1
	blocked_opportunities_changed.emit(blocked_opportunities)
	return true
