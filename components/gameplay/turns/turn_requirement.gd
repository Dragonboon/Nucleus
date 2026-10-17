class_name NucleusTurnRequirement
extends NucleusActionRequirement
## Optional gate: an action is executable only during its owner's active turn.

@export var session: NucleusTurnSession
@export var participant: NucleusTurnParticipant


func _ready() -> void:
	if session == null or participant == null:
		return
	session.turn_started.connect(_on_turn_started)
	session.turn_ended.connect(_on_turn_ended)
	session.session_ended.connect(_on_session_ended)


func _exit_tree() -> void:
	if not is_instance_valid(session):
		return
	if session.turn_started.is_connected(_on_turn_started):
		session.turn_started.disconnect(_on_turn_started)
	if session.turn_ended.is_connected(_on_turn_ended):
		session.turn_ended.disconnect(_on_turn_ended)
	if session.session_ended.is_connected(_on_session_ended):
		session.session_ended.disconnect(_on_session_ended)


func check(_context: Dictionary) -> Error:
	if not is_instance_valid(session) or not is_instance_valid(participant):
		return ERR_UNCONFIGURED
	if not session.running or session.paused:
		return ERR_UNAVAILABLE
	if not session.get_active_participants().has(participant):
		return ERR_UNAVAILABLE
	return OK


func _on_turn_started(_seat: NucleusTurnParticipant, _round: int) -> void:
	notify_availability_changed()


func _on_turn_ended(_seat: NucleusTurnParticipant, _reason: StringName) -> void:
	notify_availability_changed()


func _on_session_ended(_reason: StringName, _turns: int) -> void:
	notify_availability_changed()
