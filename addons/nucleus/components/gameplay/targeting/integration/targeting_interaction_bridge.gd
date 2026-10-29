class_name NucleusTargetingInteractionBridge
extends Node
## Feeds the selected Targetable into the existing NucleusInteractor candidate
## pipeline by reusing NucleusInteractionCandidateTracker.

@export var agent: NucleusTargetingAgent
@export var interactor: NucleusInteractor
@export var only_when_locked: bool = false

var _tracker: NucleusInteractionCandidateTracker


func _ready() -> void:
	_resolve_dependencies()

	if agent == null or interactor == null:
		NucleusLog.error(
			"%s requires TargetingAgent and Interactor." % get_path(),
			&"TargetInteractionBridge",
		)
		return

	_tracker = NucleusInteractionCandidateTracker.new(
		interactor
	)

	agent.current_changed.connect(_on_current_changed)
	agent.target_locked.connect(_on_lock_changed)
	agent.target_unlocked.connect(_on_lock_changed)

	_refresh_bridge()


func _exit_tree() -> void:
	if _tracker:
		_tracker.clear()

	if agent == null:
		return

	if agent.current_changed.is_connected(_on_current_changed):
		agent.current_changed.disconnect(_on_current_changed)

	if agent.target_locked.is_connected(_on_lock_changed):
		agent.target_locked.disconnect(_on_lock_changed)

	if agent.target_unlocked.is_connected(_on_lock_changed):
		agent.target_unlocked.disconnect(_on_lock_changed)


func _refresh_bridge() -> void:
	if _tracker == null:
		return

	_tracker.clear()

	if (
		agent == null
		or agent.current == null
		or (
			only_when_locked
			and not agent.is_locked()
		)
	):
		return

	_tracker.register_source(agent.current)


func _on_current_changed(
	_current: NucleusTargetable,
	_previous: NucleusTargetable,
) -> void:
	_refresh_bridge()


func _on_lock_changed(
	_target: NucleusTargetable,
) -> void:
	_refresh_bridge()


func _resolve_dependencies() -> void:
	if agent == null:
		agent = NucleusTargetResolver.find_agent(self)

	if interactor:
		return

	var root: Node = get_parent()

	while root:
		if root is NucleusInteractor:
			interactor = root as NucleusInteractor
			return

		for node: Node in NucleusNodeUtils.descendants(root):
			if node is NucleusInteractor:
				interactor = node as NucleusInteractor
				return

		root = root.get_parent()
