class_name NucleusTargetSensorTracker
extends RefCounted
## Collider/source bookkeeping shared by 2D/3D targeting sensors.
##
## Multiple colliders for one Targetable count as one registration per sensor.

var agent: NucleusTargetingAgent
var registration_source: Object

var _source_to_target: Dictionary[int, NucleusTargetable] = {}
var _target_counts: Dictionary[int, int] = {}


func _init(
	target_agent: NucleusTargetingAgent,
	source_owner: Object,
) -> void:
	agent = target_agent
	registration_source = source_owner


func register_source(source: Node) -> NucleusTargetable:
	if source == null or agent == null:
		return null

	var source_id: int = source.get_instance_id()

	if _source_to_target.has(source_id):
		return _source_to_target[source_id]

	var target: NucleusTargetable = (
		NucleusTargetResolver.find_targetable(source)
	)

	if target == null:
		return null

	_source_to_target[source_id] = target

	var target_id: int = target.get_instance_id()
	var count: int = int(
		_target_counts.get(
			target_id,
			0,
		)
	)
	_target_counts[target_id] = count + 1

	if count == 0:
		agent.register_candidate(
			target,
			registration_source,
		)

	return target


func unregister_source(source: Node) -> void:
	if source == null or agent == null:
		return

	var source_id: int = source.get_instance_id()

	if not _source_to_target.has(source_id):
		return

	var target: NucleusTargetable = _source_to_target[source_id]
	_source_to_target.erase(source_id)

	if target == null or not is_instance_valid(target):
		return

	var target_id: int = target.get_instance_id()
	var count: int = maxi(
		0,
		int(
			_target_counts.get(
				target_id,
				1,
			)
		)
		- 1,
	)

	if count <= 0:
		_target_counts.erase(target_id)
		agent.unregister_candidate(
			target,
			registration_source,
		)
	else:
		_target_counts[target_id] = count


func replace_single_source(source: Node) -> NucleusTargetable:
	clear()

	if source == null:
		return null

	return register_source(source)


func clear() -> void:
	if agent:
		var unique_targets: Array[NucleusTargetable] = []

		for target: NucleusTargetable in _source_to_target.values():
			if (
				target
				and is_instance_valid(target)
				and target not in unique_targets
			):
				unique_targets.append(target)

		for target: NucleusTargetable in unique_targets:
			agent.unregister_candidate(
				target,
				registration_source,
			)

	_source_to_target.clear()
	_target_counts.clear()
