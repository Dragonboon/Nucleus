class_name NucleusTurnStatusBinding
extends Node
## Optional clock adapter. Status definitions must opt into TURN duration.

enum Clock { PARTICIPANT_OPPORTUNITY, EVERY_OPPORTUNITY, COMPLETED_ROUND }

@export var session: NucleusTurnSession
@export var container: NucleusStatusEffectContainer
@export var participant: NucleusTurnParticipant
@export var clock: Clock = Clock.PARTICIPANT_OPPORTUNITY


func _ready() -> void:
	if session == null or container == null:
		return
	session.turn_ended.connect(_on_turn_ended)
	session.turn_skipped.connect(_on_turn_skipped)
	session.round_ended.connect(_on_round_ended)


func _exit_tree() -> void:
	if not is_instance_valid(session):
		return
	if session.turn_ended.is_connected(_on_turn_ended):
		session.turn_ended.disconnect(_on_turn_ended)
	if session.turn_skipped.is_connected(_on_turn_skipped):
		session.turn_skipped.disconnect(_on_turn_skipped)
	if session.round_ended.is_connected(_on_round_ended):
		session.round_ended.disconnect(_on_round_ended)


func _on_turn_ended(
	seat: NucleusTurnParticipant,
	reason: StringName,
) -> void:
	if reason == &"session_ended":
		return
	_advance_for_opportunity(seat)


func _on_turn_skipped(
	seat: NucleusTurnParticipant,
	reason: StringName,
) -> void:
	# Manually skipped active turns also emit turn_ended: never double-count.
	if reason == &"blocked":
		_advance_for_opportunity(seat)


func _on_round_ended(_round: int) -> void:
	if clock == Clock.COMPLETED_ROUND and is_instance_valid(container):
		container.advance_turns()


func _advance_for_opportunity(seat: NucleusTurnParticipant) -> void:
	if clock == Clock.COMPLETED_ROUND or not is_instance_valid(container):
		return
	if clock == Clock.EVERY_OPPORTUNITY or seat == participant:
		container.advance_turns()
