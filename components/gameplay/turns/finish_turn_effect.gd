class_name NucleusFinishTurnEffect
extends NucleusActionEffect
## Committed action closes one turn; author this after other action effects.
## Do not attach this to out-of-turn reactions unless that is the game's rule.

@export var participant: NucleusTurnParticipant
@export var skip_instead: bool = false


func can_apply(_context: Dictionary) -> Error:
	if not is_instance_valid(participant):
		return ERR_UNCONFIGURED
	var session: NucleusTurnSession = participant.get_session()
	if session == null or not session.running:
		return ERR_UNAVAILABLE
	return (
		OK if session.get_active_participants().has(participant)
		else ERR_UNAVAILABLE
	)


func apply(context: Dictionary) -> Error:
	var error: Error = can_apply(context)
	if error != OK:
		return error
	return (
		participant.skip_turn() if skip_instead
		else participant.end_turn()
	)
