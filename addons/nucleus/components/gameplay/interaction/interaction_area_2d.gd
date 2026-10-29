class_name NucleusInteractionArea2D
extends Area2D
## 2D overlap adapter that feeds candidates into [NucleusInteractor].

@export var interactor: NucleusInteractor
@export var enabled: bool = true

var _tracker: NucleusInteractionCandidateTracker


func _init() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0


func _ready() -> void:
	if interactor == null:
		interactor = _find_interactor()

	if interactor == null:
		NucleusLog.error(
			"%s requires a NucleusInteractor." % get_path(),
			&"Interaction2D",
		)
		return

	_tracker = NucleusInteractionCandidateTracker.new(interactor)

	area_entered.connect(_tracker.register_source)
	area_exited.connect(_tracker.unregister_source)
	body_entered.connect(_tracker.register_source)
	body_exited.connect(_tracker.unregister_source)

	set_enabled(enabled)


func _exit_tree() -> void:
	if _tracker:
		_tracker.clear()


func set_enabled(active: bool) -> void:
	enabled = active
	set_deferred("monitoring", active)

	if not active and _tracker:
		_tracker.clear()


func _find_interactor() -> NucleusInteractor:
	var parent: Node = get_parent()

	if parent == null:
		return null

	if parent is NucleusInteractor:
		return parent as NucleusInteractor

	for node: Node in NucleusNodeUtils.descendants(parent):
		if node is NucleusInteractor:
			return node as NucleusInteractor

	return null
