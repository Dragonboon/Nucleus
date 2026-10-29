class_name NucleusUIValuePoolProgressBinding
extends Node
## Projects one NucleusValuePool ratio into NucleusUIProgressFeedback.
##
## Gameplay remains authoritative. This adapter only observes the pool and keeps
## an existing UI presentation synchronized.

@export var source: NucleusValuePool
@export var target: NucleusUIProgressFeedback
@export var animate_changes: bool = true
@export var snap_initial: bool = true


func _ready() -> void:
	if target == null:
		target = get_parent() as NucleusUIProgressFeedback

	if not _is_configured():
		NucleusLog.error(
			"%s requires a NucleusValuePool source and progress target." % get_path(),
			&"UIValuePoolBinding",
		)
		return

	source.value_changed.connect(_on_value_changed)
	source.limits_changed.connect(_on_limits_changed)

	if snap_initial:
		call_deferred("_refresh_initial")


func _exit_tree() -> void:
	if source == null or not is_instance_valid(source):
		return

	if source.value_changed.is_connected(_on_value_changed):
		source.value_changed.disconnect(_on_value_changed)

	if source.limits_changed.is_connected(_on_limits_changed):
		source.limits_changed.disconnect(_on_limits_changed)


func refresh(animated: bool = false) -> Error:
	if not _is_configured():
		return ERR_UNCONFIGURED

	return target.set_ratio(
		source.get_ratio(),
		animated,
	)


func _is_configured() -> bool:
	return source != null and target != null


func _refresh_initial() -> void:
	refresh(false)


func _on_value_changed(
	_value: float,
	_previous_value: float,
	_delta: float,
) -> void:
	refresh(animate_changes)


func _on_limits_changed(
	_minimum_value: float,
	_maximum_value: float,
	_overflow_limit: float,
) -> void:
	refresh(false)
