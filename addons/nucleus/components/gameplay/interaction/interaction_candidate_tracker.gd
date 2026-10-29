class_name NucleusInteractionCandidateTracker
extends RefCounted
## Shared 2D/3D overlap bookkeeping for interaction sensors.

var interactor: NucleusInteractor

var _source_to_interactable: Dictionary[int, NucleusInteractable] = {}
var _interactable_counts: Dictionary[int, int] = {}


func _init(target_interactor: NucleusInteractor) -> void:
	interactor = target_interactor


func register_source(source: Node) -> NucleusInteractable:
	if source == null or interactor == null:
		return null

	var source_id: int = source.get_instance_id()

	if _source_to_interactable.has(source_id):
		return _source_to_interactable[source_id]

	var interactable: NucleusInteractable = _find_interactable(source)

	if interactable == null:
		return null

	_source_to_interactable[source_id] = interactable

	var interactable_id: int = interactable.get_instance_id()
	var count: int = _interactable_counts.get(
		interactable_id,
		0,
	)

	_interactable_counts[interactable_id] = count + 1

	if count == 0:
		interactor.register_candidate(interactable)

	return interactable


func unregister_source(source: Node) -> void:
	if source == null or interactor == null:
		return

	var source_id: int = source.get_instance_id()

	if not _source_to_interactable.has(source_id):
		return

	var interactable: NucleusInteractable = (
		_source_to_interactable[source_id]
	)
	_source_to_interactable.erase(source_id)

	if interactable == null or not is_instance_valid(interactable):
		return

	var interactable_id: int = interactable.get_instance_id()
	var count: int = maxi(
		0,
		int(
			_interactable_counts.get(
				interactable_id,
				1,
			)
		)
		- 1,
	)

	if count <= 0:
		_interactable_counts.erase(interactable_id)
		interactor.unregister_candidate(interactable)
	else:
		_interactable_counts[interactable_id] = count


func clear() -> void:
	if interactor:
		for interactable: NucleusInteractable in (
			_source_to_interactable.values()
		):
			if interactable and is_instance_valid(interactable):
				interactor.unregister_candidate(interactable)

	_source_to_interactable.clear()
	_interactable_counts.clear()


func _find_interactable(source: Node) -> NucleusInteractable:
	if source is NucleusInteractable:
		return source as NucleusInteractable

	for node: Node in NucleusNodeUtils.descendants(source):
		if node is NucleusInteractable:
			return node as NucleusInteractable

	for ancestor: Node in NucleusNodeUtils.ancestors(source):
		if ancestor is NucleusInteractable:
			return ancestor as NucleusInteractable

		for child: Node in ancestor.get_children():
			if child is NucleusInteractable:
				return child as NucleusInteractable

	return null
