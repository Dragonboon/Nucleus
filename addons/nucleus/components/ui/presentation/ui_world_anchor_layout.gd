class_name NucleusUIWorldAnchorLayout
extends Node
## Scene-owned update budget + overlap avoidance for 3D-to-HUD anchors.
## The order of anchors is the presentation priority (first wins).

@export var overlay: Control
@export var anchors: Array[NucleusUIWorldAnchor3D] = []

@export_group("Admission")
@export_range(1, 512, 1) var maximum_projection_checks: int = 96
@export_range(1, 256, 1) var maximum_visible_labels: int = 48
@export_range(0.0, 1.0, 0.005) var update_interval: float = 0.0

@export_group("Separation")
@export_range(0.0, 100.0, 0.5) var padding: float = 4.0
@export_range(0.0, 500.0, 1.0) var maximum_lift: float = 80.0
@export_range(1.0, 100.0, 1.0) var lift_step: float = 8.0

var _elapsed: float = 0.0
var _visible_count: int = 0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if update_interval <= 0.0:
		refresh_layout()
		return

	_elapsed += delta
	if _elapsed < update_interval:
		return

	_elapsed = 0.0
	refresh_layout()


func _exit_tree() -> void:
	for anchor: NucleusUIWorldAnchor3D in anchors:
		if is_instance_valid(anchor):
			anchor.reset_layout()


func get_visible_count() -> int:
	return _visible_count


## Bounded project/sort-free placement pass. O(N) hides beyond its budget.
func refresh_layout() -> int:
	_visible_count = 0
	if not is_instance_valid(overlay) or not overlay.is_inside_tree():
		_hide_anchors()
		return 0

	if overlay.size.x <= 0.0 or overlay.size.y <= 0.0:
		_hide_anchors()
		return 0

	var items: Array[Dictionary] = []
	var accepted: Array[NucleusUIWorldAnchor3D] = []
	var seen: Dictionary = {}
	var checked: int = 0

	for anchor: NucleusUIWorldAnchor3D in anchors:
		if not is_instance_valid(anchor):
			continue

		var identity: int = anchor.get_instance_id()
		if seen.has(identity):
			continue
		seen[identity] = true

		if anchor.overlay != overlay or checked >= maximum_projection_checks:
			anchor.apply_layout(Vector2.ZERO, false)
			continue

		checked += 1
		if not anchor.refresh_projection():
			continue

		if accepted.size() >= maximum_visible_labels:
			anchor.apply_layout(anchor.get_base_position(), false)
			continue

		if anchor.visual == null:
			continue

		accepted.append(anchor)
		items.append({
			"position": anchor.get_base_position(),
			"size": anchor.visual.size,
		})

	var placements: Array[Dictionary] = NucleusUIWorldAnchorLayoutSolver.solve(
		items,
		Rect2(Vector2.ZERO, overlay.size),
		padding,
		maximum_lift,
		lift_step,
	)

	for index: int in range(accepted.size()):
		var placement: Dictionary = placements[index]
		var show: bool = bool(placement["visible"])
		var position: Vector2 = placement["position"]
		accepted[index].apply_layout(position, show)
		if show:
			_visible_count += 1

	return _visible_count


func _hide_anchors() -> void:
	for anchor: NucleusUIWorldAnchor3D in anchors:
		if is_instance_valid(anchor):
			anchor.apply_layout(Vector2.ZERO, false)
