@tool
class_name NucleusTargetAreaSensor3D
extends Area3D
## Native Area3D overlap sensor that feeds one NucleusTargetingAgent.

@export var agent: NucleusTargetingAgent:
	set(value):
		agent = value
		update_configuration_warnings()

@export var sensor_enabled: bool = true:
	set(value):
		if sensor_enabled == value:
			return

		sensor_enabled = value
		update_configuration_warnings()

		if Engine.is_editor_hint() or not is_node_ready():
			return

		if sensor_enabled:
			call_deferred("_seed_overlaps")
		elif _tracker:
			_tracker.clear()

@export var detect_bodies: bool = true:
	set(value):
		detect_bodies = value
		update_configuration_warnings()

@export var detect_areas: bool = true:
	set(value):
		detect_areas = value
		update_configuration_warnings()

var _tracker: NucleusTargetSensorTracker


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if agent == null:
		agent = NucleusTargetResolver.find_agent(self)

	if agent == null:
		NucleusLog.error(
			"%s requires a NucleusTargetingAgent." % get_path(),
			&"TargetAreaSensor3D",
		)
		return

	_tracker = NucleusTargetSensorTracker.new(
		agent,
		self,
	)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	call_deferred("_seed_overlaps")


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	if _tracker:
		_tracker.clear()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if agent == null:
		warnings.append(
			"agent is not assigned. Runtime auto-resolution will search the "
			+ "nearby hierarchy; assign it explicitly when that is ambiguous."
		)

	if not detect_bodies and not detect_areas:
		warnings.append(
			"Both detect_bodies and detect_areas are disabled; this sensor "
			+ "cannot register candidates."
		)

	if not _has_collision_shape():
		warnings.append(
			"Add an enabled CollisionShape3D so the Area3D can sense overlaps."
		)

	return warnings


func _has_collision_shape() -> bool:
	for child: Node in get_children():
		if child is CollisionShape3D:
			if not (child as CollisionShape3D).disabled:
				return true

	return false


func _seed_overlaps() -> void:
	if not sensor_enabled or _tracker == null or not monitoring:
		return

	if detect_bodies:
		for body: Node in get_overlapping_bodies():
			_register(body)

	if detect_areas:
		for area: Area3D in get_overlapping_areas():
			_register(area)


func _register(source: Node) -> void:
	if not sensor_enabled or _tracker == null:
		return

	_tracker.register_source(source)


func _unregister(source: Node) -> void:
	if _tracker == null:
		return

	_tracker.unregister_source(source)


func _on_body_entered(body: Node3D) -> void:
	if detect_bodies:
		_register(body)


func _on_body_exited(body: Node3D) -> void:
	if detect_bodies:
		_unregister(body)


func _on_area_entered(area: Area3D) -> void:
	if detect_areas:
		_register(area)


func _on_area_exited(area: Area3D) -> void:
	if detect_areas:
		_unregister(area)
