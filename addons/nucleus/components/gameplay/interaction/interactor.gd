class_name NucleusInteractor
extends Node
## Owns interaction candidates and the currently selected interactable.
##
## Detection adapters register candidates. Input adapters call
## [method interact_current]. This keeps device routing out of world detection.

signal candidate_added(interactable: NucleusInteractable)
signal candidate_removed(interactable: NucleusInteractable)
signal current_changed(
	current: NucleusInteractable,
	previous: NucleusInteractable,
)
signal interaction_attempted(
	interactable: NucleusInteractable,
	error: Error,
)

@export var enabled: bool = true

var current: NucleusInteractable

var _candidates: Array[NucleusInteractable] = []


func register_candidate(
	interactable: NucleusInteractable,
) -> Error:
	if interactable == null:
		return ERR_INVALID_PARAMETER

	if interactable in _candidates:
		return ERR_ALREADY_EXISTS

	_candidates.append(interactable)

	if not interactable.availability_changed.is_connected(
		_on_candidate_availability_changed
	):
		interactable.availability_changed.connect(
			_on_candidate_availability_changed
		)

	candidate_added.emit(interactable)
	refresh_selection()

	return OK


func unregister_candidate(
	interactable: NucleusInteractable,
) -> void:
	var index: int = _candidates.find(interactable)

	if index == -1:
		return

	_candidates.remove_at(index)

	if interactable and interactable.availability_changed.is_connected(
		_on_candidate_availability_changed
	):
		interactable.availability_changed.disconnect(
			_on_candidate_availability_changed
		)

	candidate_removed.emit(interactable)
	refresh_selection()


func clear_candidates() -> void:
	for interactable: NucleusInteractable in _candidates.duplicate():
		unregister_candidate(interactable)


func refresh_selection() -> void:
	_prune_invalid_candidates()

	var best: NucleusInteractable

	for candidate: NucleusInteractable in _candidates:
		if not candidate.can_be_interacted(self):
			continue

		if best == null or candidate.priority > best.priority:
			best = candidate

	set_current(best)


func set_current(interactable: NucleusInteractable) -> Error:
	if interactable and interactable not in _candidates:
		return ERR_DOES_NOT_EXIST

	if current == interactable:
		return OK

	var previous: NucleusInteractable = current

	if previous and is_instance_valid(previous):
		previous._set_focused(self, false)

	current = interactable

	if current and is_instance_valid(current):
		current._set_focused(self, true)

	current_changed.emit(current, previous)

	return OK


func interact_current(
	context: Dictionary = {},
) -> Error:
	if not enabled:
		return ERR_UNAVAILABLE

	refresh_selection()

	if current == null:
		return ERR_DOES_NOT_EXIST

	var interactable: NucleusInteractable = current
	var error: Error = interactable.interact(
		self,
		context,
	)

	interaction_attempted.emit(
		interactable,
		error,
	)

	refresh_selection()

	return error


func cancel_current() -> void:
	if current:
		current.cancel_interaction(self)


func get_candidates() -> Array[NucleusInteractable]:
	_prune_invalid_candidates()
	return _candidates.duplicate()


func _prune_invalid_candidates() -> void:
	for index: int in range(_candidates.size() - 1, -1, -1):
		var candidate: NucleusInteractable = _candidates[index]

		if candidate and is_instance_valid(candidate):
			continue

		_candidates.remove_at(index)

	if current and not is_instance_valid(current):
		current = null


func _on_candidate_availability_changed(
	_available: bool,
) -> void:
	refresh_selection()
