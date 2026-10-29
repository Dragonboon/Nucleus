class_name NucleusInteractable
extends Node
## Game-agnostic interaction endpoint.
##
## Detection, input, presentation, and actual gameplay consequences remain
## separate concerns.

signal focused(interactor: NucleusInteractor)
signal unfocused(interactor: NucleusInteractor)
signal interacted(
	interactor: NucleusInteractor,
	context: Dictionary,
)
signal interaction_canceled(interactor: NucleusInteractor)
signal interaction_limit_reached
signal availability_changed(available: bool)

@export var enabled: bool = true
@export var priority: int = 0

@export_group("Prompt")
@export var prompt_key: StringName
@export var fallback_prompt: String = "Interact"

@export_group("Limits")
@export_range(0, 1_000_000, 1, "or_greater")
var maximum_interactions: int = 0
@export var disable_when_limit_reached: bool = true

var interaction_count: int = 0
var _focused_by: Dictionary[int, NucleusInteractor] = {}


func set_enabled(active: bool) -> void:
	if enabled == active:
		return

	enabled = active
	availability_changed.emit(can_be_interacted())


func can_be_interacted(
	_interactor: NucleusInteractor = null,
) -> bool:
	if not enabled:
		return false

	return (
		maximum_interactions <= 0
		or interaction_count < maximum_interactions
	)


func interact(
	interactor: NucleusInteractor,
	context: Dictionary = {},
) -> Error:
	if not can_be_interacted(interactor):
		return ERR_UNAVAILABLE

	interaction_count += 1
	interacted.emit(
		interactor,
		context.duplicate(true),
	)

	if (
		maximum_interactions > 0
		and interaction_count >= maximum_interactions
	):
		interaction_limit_reached.emit()

		if disable_when_limit_reached:
			set_enabled(false)
		else:
			availability_changed.emit(false)

	return OK


func cancel_interaction(interactor: NucleusInteractor) -> void:
	interaction_canceled.emit(interactor)


func get_prompt_text() -> String:
	if prompt_key == &"":
		return fallback_prompt

	var translated: String = str(
		TranslationServer.translate(prompt_key)
	)

	return (
		fallback_prompt
		if translated == str(prompt_key)
		else translated
	)


func capture_state() -> Dictionary:
	return {
		"enabled": enabled,
		"interaction_count": interaction_count,
	}


func restore_state(data: Dictionary) -> void:
	interaction_count = maxi(
		0,
		int(
			data.get(
				"interaction_count",
				interaction_count,
			)
		),
	)

	set_enabled(
		bool(data.get("enabled", enabled))
	)


func _set_focused(
	interactor: NucleusInteractor,
	active: bool,
) -> void:
	if interactor == null:
		return

	var interactor_id: int = interactor.get_instance_id()

	if active:
		if _focused_by.has(interactor_id):
			return

		_focused_by[interactor_id] = interactor
		focused.emit(interactor)
		return

	if not _focused_by.has(interactor_id):
		return

	_focused_by.erase(interactor_id)
	unfocused.emit(interactor)
