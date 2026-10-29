class_name NucleusAnimationEventRelay
extends Node
## Local signal endpoint intended for AnimationPlayer method tracks.
##
## Animation assets call emit_event() instead of reaching game-specific Nodes
## directly. Consumers connect locally to [signal event_received].

signal event_received(
	event_id: StringName,
	payload: Variant,
)


func emit_event(
	event_id: StringName,
	payload: Variant = null,
) -> void:
	if event_id == &"":
		return

	event_received.emit(
		event_id,
		payload,
	)
