class_name NucleusPlacementSession3D
extends Node
## Scene-owned preview/edit session. Input, economy, save and RPC remain game-owned.
## Screen previews use bounded, incremental validation; every commit is rechecked.

signal preview_updated(valid: bool, reason: StringName, transforms: Array[Transform3D])
signal placement_confirmed(roots: Array[Node3D], was_edit: bool)
signal placement_cancelled(was_edit: bool)
signal placement_rejected(reason: StringName)
signal removal_requested(root: Node3D)

enum Mode { IDLE, SINGLE, CHAIN, EDIT, PATH, EDIT_GROUP }

@export var world_parent: Node3D
@export var camera: Camera3D
@export_range(0.1, 1000.0, 1.0, "or_greater") var ray_distance: float = 100.0
@export var valid_preview_material: Material
@export var invalid_preview_material: Material
@export var pending_preview_material: Material

@export_group("Preview budget")
## Upper bound on placement-solver evaluations and scene instances per physics tick.
@export_range(1, 32, 1) var max_checks_per_tick: int = 3
## Minimum interval between distinct cursor validation batches, in milliseconds.
@export_range(0, 250, 1) var preview_interval_ms: int = 60
## Tiny cursor jitter should not invalidate expensive physics work.
@export_range(0.0, 1.0, 0.01) var cursor_tolerance: float = 0.04
@export_range(1, 128, 1) var max_group_count: int = 32

## Game policy: (Array[Transform3D], Array[NucleusPlaceable3D]) -> Error.
var admission: Callable
var mode: Mode = Mode.IDLE
var last_reason: StringName = &""
var is_candidate_valid: bool = false

var _scene: PackedScene
var _roots: Array[Node3D] = []
var _placeables: Array[NucleusPlaceable3D] = []
var _saved_visuals: Array[Array] = []
var _previous_transforms: Array[Transform3D] = []
var _chain_anchor: Vector3 = Vector3.ZERO
var _path_controls: Array[Vector3] = []
var _yaw: float = 0.0
var _initial_heading: float = 0.0
var _group_pivot: Vector3 = Vector3.ZERO
var _current_hit: Dictionary = {}
var _candidate_hit: Dictionary = {}
var _transforms: Array[Transform3D] = []
var _preview_feedback_state: int = -1
var _pending_entries: Array[Dictionary] = []
var _pending_transforms: Array[Transform3D] = []
var _pending_index: int = 0
var _validation_pending: bool = false
var _confirm_pending: bool = false
var _last_batch_usec: int = -1


func _ready() -> void:
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if mode == Mode.IDLE:
		return
	if _confirm_pending:
		_pump_validation()
		return
	if camera != null:
		update_from_screen(get_viewport().get_mouse_position())
	elif _validation_pending:
		_pump_validation()


func begin_new(scene: PackedScene) -> Error:
	if not _valid_world() or scene == null:
		return ERR_UNCONFIGURED
	cancel()
	_scene = scene
	var added := _append_preview()
	if added != OK:
		_clear_all_new()
		_clear_state()
		return added
	mode = Mode.SINGLE
	set_physics_process(camera != null)
	return OK


func begin_chain(scene: PackedScene, anchor: Vector3) -> Error:
	if not _finite(anchor):
		return ERR_INVALID_PARAMETER
	var result := begin_new(scene)
	if result != OK:
		return result
	if not _placeables[0].profile.allow_chains:
		cancel()
		return ERR_UNAVAILABLE
	_chain_anchor = anchor
	mode = Mode.CHAIN
	return OK


## Curved chain: begin with one anchor, add bend points, then confirm at cursor.
func begin_path(scene: PackedScene, anchor: Vector3) -> Error:
	var result := begin_chain(scene, anchor)
	if result != OK:
		return result
	mode = Mode.PATH
	_path_controls = [anchor]
	return OK


func add_path_control(point: Vector3) -> Error:
	if mode != Mode.PATH or _confirm_pending or not _finite(point):
		return ERR_UNAVAILABLE
	var limit: int = _placeables[0].profile.chain_max_control_points
	if _path_controls.size() >= limit - 1:
		return ERR_BUSY
	if _path_controls.back().distance_to(point) < 0.1:
		return ERR_INVALID_PARAMETER
	_path_controls.append(point)
	_refresh_from_current_hit()
	return OK


func remove_last_path_control() -> Error:
	if mode != Mode.PATH or _path_controls.size() <= 1 or _confirm_pending:
		return ERR_UNAVAILABLE
	_path_controls.pop_back()
	_refresh_from_current_hit()
	return OK


func get_path_controls() -> Array[Vector3]:
	return _path_controls.duplicate()


func begin_edit(placeable: NucleusPlaceable3D) -> Error:
	if placeable == null:
		return ERR_INVALID_PARAMETER
	var selected: Array[NucleusPlaceable3D] = [placeable]
	return begin_edit_many(selected)


func begin_edit_many(items: Array[NucleusPlaceable3D]) -> Error:
	if items.is_empty():
		return ERR_INVALID_PARAMETER
	if items.size() > maxi(max_group_count, 1):
		return ERR_OUT_OF_MEMORY
	var roots: Array[Node3D] = []
	for component: NucleusPlaceable3D in items:
		if component == null or not is_instance_valid(component):
			return ERR_INVALID_PARAMETER
		var profile := component.profile
		if profile == null or not profile.validate().is_empty():
			return ERR_INVALID_DATA
		if not profile.can_move and not profile.can_rotate:
			return ERR_UNAVAILABLE
		if items.size() > 1 and not profile.can_move:
			return ERR_UNAVAILABLE
		var root := component.get_root()
		if root == null or not root.is_inside_tree() or root in roots:
			return ERR_INVALID_PARAMETER
		if root != component and not root.is_ancestor_of(component):
			return ERR_INVALID_PARAMETER
		roots.append(root)
	if roots.size() > 1 and _group_contains_support_stack(roots):
		# Currently group validation excludes all member colliders. Reject
		# internal support dependencies rather than approving unsupported items.
		return ERR_UNAVAILABLE
	cancel()
	var pivot := Vector3.ZERO
	for root: Node3D in roots:
		pivot += root.global_position
	_group_pivot = pivot / float(roots.size())
	for index: int in range(items.size()):
		_roots.append(roots[index])
		_placeables.append(items[index])
		_previous_transforms.append(roots[index].global_transform)
		_saved_visuals.append(_preview_on(roots[index]))
	_initial_heading = _heading_of(_previous_transforms[0].basis)
	_yaw = _initial_heading
	mode = Mode.EDIT if roots.size() == 1 else Mode.EDIT_GROUP
	set_physics_process(camera != null)
	return OK


## Optional input wrapper. Raycast is cheap; support/collision tests are budgeted.
func update_from_screen(screen_position: Vector2) -> bool:
	if mode == Mode.IDLE or camera == null or not is_finite(ray_distance):
		return false
	if _confirm_pending:
		_pump_validation()
		return false
	var direction := camera.project_ray_normal(screen_position)
	var origin := camera.project_ray_origin(screen_position)
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * ray_distance,
		_placeables[0].profile.support_mask,
		_all_preview_rids(),
	)
	query.collide_with_areas = false
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	_current_hit = hit.duplicate()
	var now := Time.get_ticks_usec()
	if not _validation_pending and _hit_changed(hit, _candidate_hit):
		if _last_batch_usec < 0 or now - _last_batch_usec >= preview_interval_ms * 1000:
			_schedule_validation(hit)
	elif not _validation_pending and _candidate_hit.is_empty() and hit.is_empty():
		_set_invalid(&"no_surface")
	if _validation_pending:
		_pump_validation()
	return is_candidate_valid and not _validation_pending


## Synchronous programmatic entry point for AI/touch/tests. Do not call every
## physics frame for long chains; use update_from_screen() for a bounded preview.
func update_from_hit(hit: Dictionary) -> bool:
	if mode == Mode.IDLE or _confirm_pending:
		return false
	_current_hit = hit.duplicate()
	_schedule_validation(hit)
	while _validation_pending:
		_pump_validation(maxi(_pending_entries.size() + _roots.size(), 1))
	return is_candidate_valid


func rotate_degrees(delta: float) -> Error:
	if not is_finite(delta):
		return ERR_INVALID_PARAMETER
	if mode == Mode.IDLE or _confirm_pending:
		return ERR_UNAVAILABLE
	for component: NucleusPlaceable3D in _placeables:
		if not component.profile.can_rotate:
			return ERR_UNAVAILABLE
	_yaw = wrapf(_yaw + deg_to_rad(delta), -PI, PI)
	_refresh_from_current_hit()
	return OK


func rotate_step(direction: int) -> Error:
	if mode == Mode.IDLE:
		return ERR_UNAVAILABLE
	return rotate_degrees(_placeables[0].profile.rotation_increment_degrees * signi(direction))


## Confirm triggers fresh, incremental physics checks (no long synchronous spike).
## OK means accepted for validation, not committed; observe placement_confirmed.
func confirm() -> Error:
	if mode == Mode.IDLE or _current_hit.is_empty():
		return ERR_UNAVAILABLE
	if _confirm_pending:
		return ERR_BUSY
	_confirm_pending = true
	_schedule_validation(_current_hit)
	_pump_validation()
	return OK


func cancel() -> void:
	if mode == Mode.IDLE:
		return
	var was_edit := mode in [Mode.EDIT, Mode.EDIT_GROUP]
	if was_edit:
		for index: int in range(_roots.size()):
			if is_instance_valid(_roots[index]):
				_roots[index].global_transform = _previous_transforms[index]
			_preview_off(_saved_visuals[index])
	else:
		_clear_all_new()
	_clear_state()
	placement_cancelled.emit(was_edit)


func request_removal(placeable: NucleusPlaceable3D) -> Error:
	if placeable == null or not is_instance_valid(placeable):
		return ERR_INVALID_PARAMETER
	if mode != Mode.IDLE:
		return ERR_BUSY
	if placeable.profile == null or not placeable.profile.can_remove:
		return ERR_UNAVAILABLE
	removal_requested.emit(placeable.get_root())
	return OK


func _group_contains_support_stack(roots: Array[Node3D]) -> bool:
	for root: Node3D in roots:
		var component := NucleusPlaceable3D.find_in(root)
		if component == null or component.profile == null:
			return true
		var profile := component.profile
		var ray := PhysicsRayQueryParameters3D.create(
			root.global_position + Vector3.UP * 0.12,
			root.global_position - Vector3.UP * profile.support_cast_below,
			profile.support_mask,
			NucleusPlaceable3D.collision_rids(root),
		)
		var hit := root.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			continue
		var owner := NucleusPlaceable3D.find_for_collider(hit.get("collider"))
		if owner != null and owner.get_root() in roots:
			return true
	return false


## Lightweight HUD/debug readout; no new diagnostics owner or polling of physics.
func get_validation_progress() -> Vector2i:
	if not _validation_pending:
		return Vector2i.ZERO
	return Vector2i(_pending_index, _pending_entries.size())


func _refresh_from_current_hit() -> void:
	_candidate_hit.clear()
	_last_batch_usec = -1
	_validation_pending = false
	if not _current_hit.is_empty():
		_schedule_validation(_current_hit)
		_pump_validation()


func _hit_changed(next_hit: Dictionary, previous_hit: Dictionary) -> bool:
	if next_hit.is_empty() or previous_hit.is_empty():
		return next_hit.is_empty() != previous_hit.is_empty()
	if next_hit.get("collider") != previous_hit.get("collider"):
		return true
	var a: Vector3 = next_hit.get("position", Vector3.ZERO)
	var b: Vector3 = previous_hit.get("position", Vector3.ZERO)
	return a.distance_to(b) > cursor_tolerance


func _schedule_validation(hit: Dictionary) -> void:
	_candidate_hit = hit.duplicate()
	_last_batch_usec = Time.get_ticks_usec()
	_pending_entries.clear()
	_pending_transforms.clear()
	_pending_index = 0
	_validation_pending = false
	_transforms.clear()
	if hit.is_empty() or not hit.get("position") is Vector3:
		_set_invalid(&"no_surface")
		if _confirm_pending:
			_confirm_pending = false
			placement_rejected.emit(last_reason)
		return
	var candidate: Array[Dictionary] = _layout_entries(hit)
	if candidate.is_empty():
		_set_invalid(&"chain_limit")
		if _confirm_pending:
			_confirm_pending = false
			placement_rejected.emit(last_reason)
		return
	_pending_entries = candidate
	_validation_pending = true
	is_candidate_valid = false
	last_reason = &"checking"
	_set_preview_feedback(false, true)
	var empty: Array[Transform3D] = []
	preview_updated.emit(false, &"checking", empty)
	# Cheap positioning keeps existing previews visually responsive while physics
	# catches up. This is never an accepted/green placement.
	for index: int in range(mini(_roots.size(), candidate.size())):
		_roots[index].global_position = candidate[index]["position"]


func _layout_entries(hit: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var point: Vector3 = hit["position"]
	var profile := _placeables[0].profile
	if mode in [Mode.CHAIN, Mode.PATH]:
		if mode == Mode.CHAIN:
			var positions := NucleusPlacementChain3D.points(
				_chain_anchor, point, profile.chain_spacing, profile.chain_max_count,
			)
			var yaw := NucleusPlacementChain3D.heading(_chain_anchor, point, _yaw)
			for p: Vector3 in positions:
				result.append({"position": p, "yaw": yaw, "profile": profile})
		else:
			var controls := _path_controls.duplicate()
			if controls.is_empty():
				return result
			if controls.back().distance_to(point) > 0.01:
				controls.append(point)
			if controls.size() > profile.chain_max_control_points:
				return result
			var layout := NucleusPlacementChain3D.path_layout(
				controls, profile.chain_spacing, profile.chain_max_count,
				profile.chain_curve_subdivisions,
			)
			for step: Dictionary in layout:
				result.append({
					"position": step["position"], "yaw": step["yaw"], "profile": profile,
				})
	elif mode == Mode.EDIT_GROUP:
		var rotation := Basis(Vector3.UP, _yaw - _initial_heading)
		var first_origin := _previous_transforms[0].origin
		var destination_pivot := point + (_group_pivot - first_origin)
		for index: int in range(_previous_transforms.size()):
			var previous: Transform3D = _previous_transforms[index]
			result.append({
				"position": destination_pivot + rotation * (previous.origin - _group_pivot),
				"yaw": _heading_of(previous.basis) + _yaw - _initial_heading,
				"profile": _placeables[index].profile,
			})
	else:
		if mode == Mode.EDIT and not profile.can_move:
			point = _previous_transforms[0].origin
		result.append({"position": point, "yaw": _yaw, "profile": profile})
	return result


func _pump_validation(limit: int = -1) -> void:
	if not _validation_pending:
		return
	var budget := maxi(limit if limit > 0 else max_checks_per_tick, 1)
	var space := _roots[0].get_world_3d().direct_space_state
	var exclusions := _all_preview_rids()
	var count := _pending_entries.size()
	var work := 0
	while _pending_index < count and work < budget:
		if _pending_index >= _roots.size():
			var added := _append_preview()
			if added != OK:
				_reject_batch(&"invalid_scene")
				return
			exclusions.append_array(NucleusPlaceable3D.collision_rids(_roots.back()))
			if pending_preview_material != null:
				_apply_material(_roots.back(), pending_preview_material)
		var entry: Dictionary = _pending_entries[_pending_index]
		var placeable: NucleusPlaceable3D = _placeables[_pending_index]
		var profile: NucleusPlacementProfile3D = placeable.profile
		var result: Dictionary
		if mode == Mode.SINGLE or mode == Mode.EDIT:
			if mode == Mode.EDIT and not profile.can_move:
				result = NucleusPlacementSolver3D.evaluate_at(
					space, profile, entry["position"], entry["yaw"], exclusions,
				)
			else:
				result = NucleusPlacementSolver3D.evaluate_hit(
					space, profile, _candidate_hit, entry["yaw"], exclusions,
				)
		else:
			result = NucleusPlacementSolver3D.evaluate_at(
				space, profile, entry["position"], entry["yaw"], exclusions,
			)
		work += 1
		if not bool(result.get("valid", false)):
			_reject_batch(result.get("reason", &"invalid"))
			return
		var transform: Transform3D = result["transform"]
		_pending_transforms.append(transform)
		_roots[_pending_index].global_transform = transform
		_pending_index += 1
	# Destroy excess previews gradually, too: freeing dozens in one tick stutters.
	while _pending_index == count and _roots.size() > count and work < budget:
		_preview_off(_saved_visuals.pop_back())
		_roots.pop_back().free()
		_placeables.pop_back()
		work += 1
	if _pending_index != count or _roots.size() != count:
		return
	if mode in [Mode.CHAIN, Mode.PATH] and not _chain_has_clearance():
		_reject_batch(&"chain_self_overlap")
		return
	if mode == Mode.EDIT_GROUP and not _group_has_clearance():
		_reject_batch(&"group_self_overlap")
		return
	_validation_pending = false
	_transforms = _pending_transforms.duplicate()
	is_candidate_valid = true
	last_reason = &""
	_set_preview_feedback(true)
	preview_updated.emit(true, &"", _transforms.duplicate())
	if _confirm_pending:
		_complete_confirm()


func _chain_has_clearance() -> bool:
	var shape := _placeables[0].profile.clearance_shape as BoxShape3D
	if shape == null:
		return true
	var offset := _placeables[0].profile.clearance_offset
	for i: int in range(_pending_transforms.size()):
		for j: int in range(i + 1, _pending_transforms.size()):
			if NucleusPlacementChain3D.box_footprints_overlap(
				_pending_transforms[i], _pending_transforms[j], shape.size, offset,
			):
				return false
	return true


func _group_has_clearance() -> bool:
	for i: int in range(_pending_transforms.size()):
		var first := _placeables[i].profile
		var first_box := first.clearance_shape as BoxShape3D
		if first_box == null:
			return false
		for j: int in range(i + 1, _pending_transforms.size()):
			var second := _placeables[j].profile
			var second_box := second.clearance_shape as BoxShape3D
			if second_box == null:
				return false
			if NucleusPlacementChain3D.box_footprints_overlap(
				_pending_transforms[i], _pending_transforms[j],
				first_box.size, first.clearance_offset, 0.01,
				second_box.size, second.clearance_offset,
			):
				return false
	return true


func _reject_batch(reason: StringName) -> void:
	_validation_pending = false
	_set_invalid(reason)
	if _confirm_pending:
		_confirm_pending = false
		placement_rejected.emit(reason)


func _complete_confirm() -> void:
	if not _confirm_pending or not is_candidate_valid:
		return
	if admission.is_valid():
		var policy_error: Error = admission.call(
			_transforms.duplicate(), _placeables.duplicate()
		)
		if policy_error != OK:
			_confirm_pending = false
			_set_invalid(&"game_policy")
			placement_rejected.emit(&"game_policy")
			return
	var edited := mode in [Mode.EDIT, Mode.EDIT_GROUP]
	var committed: Array[Node3D] = _roots.duplicate()
	for index: int in range(_roots.size()):
		_preview_off(_saved_visuals[index])
		_roots[index].global_transform = _transforms[index]
	_clear_state()
	placement_confirmed.emit(committed, edited)


func _valid_world() -> bool:
	if world_parent == null:
		world_parent = get_parent() as Node3D
	return world_parent != null and world_parent.is_inside_tree()


func _append_preview() -> Error:
	if _scene == null:
		return ERR_INVALID_PARAMETER
	var instance := _scene.instantiate()
	if not instance is Node3D:
		if instance != null:
			instance.free()
		return ERR_INVALID_DATA
	var root := instance as Node3D
	var placeable := NucleusPlaceable3D.find_in(root)
	if placeable == null or placeable.profile == null or not placeable.profile.validate().is_empty():
		root.free()
		return ERR_INVALID_DATA
	if placeable.target != null and placeable.target != root:
		root.free()
		return ERR_INVALID_DATA
	world_parent.add_child(root)
	if placeable.get_root() != root:
		root.free()
		return ERR_INVALID_DATA
	_roots.append(root)
	_placeables.append(placeable)
	_saved_visuals.append(_preview_on(root))
	_preview_feedback_state = -1
	return OK


func _all_preview_rids() -> Array[RID]:
	var result: Array[RID] = []
	for root: Node3D in _roots:
		result.append_array(NucleusPlaceable3D.collision_rids(root))
	return result

func _preview_on(root: Node) -> Array:
	var saved: Array = []
	_capture_preview_nodes(root, saved)
	return saved


func _capture_preview_nodes(node: Node, saved: Array) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		saved.append({
			"node": mesh,
			"property": &"material_override",
			"value": mesh.material_override,
		})
	if node is CollisionObject3D:
		var collision := node as CollisionObject3D
		saved.append({
			"node": collision,
			"property": &"collision_layer",
			"value": collision.collision_layer,
		})
		collision.collision_layer = 0
	if node is RigidBody3D:
		var body := node as RigidBody3D
		saved.append({"node": body, "property": &"freeze", "value": body.freeze})
		body.freeze = true
	for child: Node in node.get_children():
		_capture_preview_nodes(child, saved)


func _preview_off(saved: Array) -> void:
	for entry: Dictionary in saved:
		var target: Object = entry["node"]
		if is_instance_valid(target):
			target.set(entry["property"], entry["value"])


func _set_preview_feedback(valid: bool, pending: bool = false) -> void:
	var state := 2 if pending else (1 if valid else 0)
	if state == _preview_feedback_state:
		return
	_preview_feedback_state = state
	var material := (
		pending_preview_material if pending
		else (valid_preview_material if valid else invalid_preview_material)
	)
	if material == null:
		for saved: Array in _saved_visuals:
			for entry: Dictionary in saved:
				if entry["property"] == &"material_override":
					var mesh: Object = entry["node"]
					if is_instance_valid(mesh):
						mesh.set(&"material_override", entry["value"])
		return
	for root: Node3D in _roots:
		_apply_material(root, material)


func _apply_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child: Node in node.get_children():
		_apply_material(child, material)


func _set_invalid(reason: StringName) -> void:
	is_candidate_valid = false
	last_reason = reason
	_set_preview_feedback(false)
	var empty: Array[Transform3D] = []
	preview_updated.emit(false, reason, empty)


func _clear_all_new() -> void:
	for index: int in range(_roots.size()):
		_preview_off(_saved_visuals[index])
		if is_instance_valid(_roots[index]):
			_roots[index].free()


func _clear_state() -> void:
	_roots.clear()
	_placeables.clear()
	_saved_visuals.clear()
	_previous_transforms.clear()
	_path_controls.clear()
	_pending_entries.clear()
	_pending_transforms.clear()
	_pending_index = 0
	_validation_pending = false
	_confirm_pending = false
	_last_batch_usec = -1
	_candidate_hit.clear()
	_transforms.clear()
	_current_hit.clear()
	_scene = null
	_preview_feedback_state = -1
	is_candidate_valid = false
	last_reason = &""
	mode = Mode.IDLE
	set_physics_process(false)


func _exit_tree() -> void:
	cancel()


static func _heading_of(basis: Basis) -> float:
	var forward := basis * Vector3.FORWARD
	return atan2(-forward.x, -forward.z)


static func _finite(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)
