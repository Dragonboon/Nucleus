class_name NucleusTargetRequirement
extends NucleusActionRequirement
## Gates a GameplayAction by the current TargetingAgent selection.

@export var agent: NucleusTargetingAgent

@export_group("Selection")
@export var require_target: bool = true
@export var require_locked_target: bool = false

@export_group("Tags")
@export var required_tags: Array[StringName] = []
@export var require_all_required_tags: bool = true
@export var blocked_tags: Array[StringName] = []

var _observed_target: NucleusTargetable


func _ready() -> void:
	if agent == null:
		agent = NucleusTargetResolver.find_agent(self)

	if agent == null:
		NucleusLog.error(
			"%s requires a NucleusTargetingAgent." % get_path(),
			&"TargetRequirement",
		)
		return

	agent.current_changed.connect(_on_targeting_changed)
	agent.target_locked.connect(_on_target_locked)
	agent.target_unlocked.connect(_on_target_unlocked)
	_observe_target(agent.current)


func _exit_tree() -> void:
	_observe_target(null)

	if agent == null:
		return

	if agent.current_changed.is_connected(_on_targeting_changed):
		agent.current_changed.disconnect(_on_targeting_changed)

	if agent.target_locked.is_connected(_on_target_locked):
		agent.target_locked.disconnect(_on_target_locked)

	if agent.target_unlocked.is_connected(_on_target_unlocked):
		agent.target_unlocked.disconnect(_on_target_unlocked)


func check(_context: Dictionary) -> Error:
	if agent == null:
		return ERR_UNCONFIGURED

	if require_locked_target and not agent.is_locked():
		return ERR_UNAVAILABLE

	var target: NucleusTargetable = agent.current

	if target == null:
		return ERR_UNAVAILABLE if require_target else OK

	if (
		not blocked_tags.is_empty()
		and target.has_any_tag(blocked_tags)
	):
		return ERR_UNAVAILABLE

	if required_tags.is_empty():
		return OK

	if require_all_required_tags:
		return (
			OK
			if target.has_all_tags(required_tags)
			else ERR_UNAVAILABLE
		)

	return (
		OK
		if target.has_any_tag(required_tags)
		else ERR_UNAVAILABLE
	)


func _on_targeting_changed(
	current: NucleusTargetable,
	_previous: NucleusTargetable,
) -> void:
	_observe_target(current)
	notify_availability_changed()


func _observe_target(target: NucleusTargetable) -> void:
	if _observed_target and is_instance_valid(_observed_target):
		if _observed_target.metadata_changed.is_connected(
			_on_target_metadata_changed
		):
			_observed_target.metadata_changed.disconnect(
				_on_target_metadata_changed
			)

		if _observed_target.availability_changed.is_connected(
			_on_target_availability_changed
		):
			_observed_target.availability_changed.disconnect(
				_on_target_availability_changed
			)

	_observed_target = target

	if _observed_target == null:
		return

	_observed_target.metadata_changed.connect(
		_on_target_metadata_changed
	)
	_observed_target.availability_changed.connect(
		_on_target_availability_changed
	)


func _on_target_metadata_changed() -> void:
	notify_availability_changed()


func _on_target_availability_changed(
	_available: bool,
) -> void:
	notify_availability_changed()


func _on_target_locked(
	_target: NucleusTargetable,
) -> void:
	notify_availability_changed()


func _on_target_unlocked(
	_target: NucleusTargetable,
) -> void:
	notify_availability_changed()
