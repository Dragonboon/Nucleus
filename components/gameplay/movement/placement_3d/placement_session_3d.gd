class_name NucleusPlacementSession3D
extends Node
## Scene-owned preview/edit session. Input, economy, save and RPC remain game-owned.
## Screen previews use bounded, incremental validation; every commit is rechecked.

signal preview_updated(valid: bool, reason: StringName, transforms: Array[Transform3D])
signal placement_confirmed(roots: Array[Node3D], was_edit: bool)
signal placement_cancelled(was_edit: bool)
signal placement_rejected(reason: StringName)
signal removal_requested(root: Node3D)
signal variant_changed(variant_id: StringName, index: int)

enum Mode { IDLE, SINGLE, CHAIN, EDIT, PATH, EDIT_GROUP, DUPLICATE, DUPLICATE_GROUP }

@export var world_parent: Node3D
@export var camera: Camera3D
## Optional alternatives for SINGLE previews. Other modes retain their behavior.
@export var variant_set: NucleusPlacementVariantSet3D
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
@export_range(1, 512, 1) var max_group_count: int = 32
## Limits pairwise clearance checks after physical placement checks finish.
@export_range(1, 8192, 1) var max_pairs_per_tick: int = 512

@export_group("Default snap")
## Applied only when the asset inherits snapping. The asset can force ON/OFF.
@export var snap_enabled_by_default: bool = false
@export var snap_grid_step: Vector2 = Vector2.ONE
@export var snap_grid_origin: Vector2 = Vector2.ZERO
## Explicit player-facing free mode. Overrides legacy and asset-forced grid snap.
## Defaults to false so existing projects retain their original profile rules.
@export var force_free_placement: bool = false

## Game policy: (Array[Transform3D], Array[NucleusPlaceable3D]) -> Error.
var admission: Callable
var mode: Mode = Mode.IDLE
var last_reason: StringName = &""
var is_candidate_valid: bool = false

var _variant_index: int = -1
var _scene: PackedScene
var _roots: Array[Node3D] = []
var _placeables: Array[NucleusPlaceable3D] = []
var _saved_visuals: Array[Array] = []
var _previous_transforms: Array[Transform3D] = []
var _internal_supports: Dictionary[int, int] = {}
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
var _pair_i: int = 0
var _pair_j: int = 1
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


## Changes the session default; active previews revalidate without a stale green state.
func set_snap_defaults(
	enabled: bool,
	step: Vector2 = Vector2.ONE,
	origin: Vector2 = Vector2.ZERO,
	free_override: Variant = null,
) -> Error:
	if not NucleusPlacementSolver3D.valid_grid(step, origin):
		return ERR_INVALID_PARAMETER
	if free_override != null and typeof(free_override) != TYPE_BOOL:
		return ERR_INVALID_PARAMETER
	if _confirm_pending:
		return ERR_BUSY
	snap_enabled_by_default = enabled
	snap_grid_step = step
	snap_grid_origin = origin
	if free_override != null:
		force_free_placement = bool(free_override)
	if mode != Mode.IDLE:
		_refresh_from_current_hit()
	return OK


func get_snap_settings(profile: NucleusPlacementProfile3D = null) -> Dictionary:
	# A direct user request for free placement beats profile-level forced snap.
	# Do not mutate the shared profile resource to achieve this.
	if force_free_placement:
		return {
			"enabled": false,
			"step": snap_grid_step,
			"origin": snap_grid_origin,
			"source": &"free_override",
		}
	var target := profile
	if target == null and not _placeables.is_empty():
		target = _placeables[0].profile
	if target == null:
		return {
			"enabled": snap_enabled_by_default,
			"step": snap_grid_step,
			"origin": snap_grid_origin,
			"source": &"session",
		}
	return target.resolve_snap(snap_enabled_by_default, snap_grid_step, snap_grid_origin)


func begin_new(scene: PackedScene) -> Error:
	if not _valid_world() or scene == null:
		return ERR_UNCONFIGURED
	cancel()
	_scene = scene
	_variant_index = -1
	var added := _append_preview()
	if added != OK:
		_clear_all_new()
		_clear_state()
		return added
	mode = Mode.SINGLE
	set_physics_process(camera != null)
	return OK


## Begin the configured catalog at its default, or at a specified stable ID.
func begin_variants(
	catalog: NucleusPlacementVariantSet3D,
	variant_id: StringName = &"",
) -> Error:
	if catalog == null or not catalog.validate().is_empty():
		return ERR_INVALID_DATA
	var index: int = catalog.get_default_index()
	if variant_id != &"":
		index = catalog.find_index(variant_id)
	if index < 0 or index >= catalog.variants.size():
		return ERR_DOES_NOT_EXIST
	var result: Error = begin_new(catalog.variants[index].scene)
	if result != OK:
		return result
	variant_set = catalog
	_variant_index = index
	_placeables[0].variant_id = get_variant_id()
	variant_changed.emit(get_variant_id(), index)
	return OK


func get_variant_id() -> StringName:
	if variant_set == null or _variant_index < 0:
		return &""
	if _variant_index >= variant_set.variants.size():
		return &""
	return variant_set.variants[_variant_index].variant_id


func select_variant(variant_id: StringName) -> Error:
	if _variant_index < 0 or variant_set == null:
		return ERR_UNAVAILABLE
	if not variant_set.validate().is_empty():
		return ERR_UNCONFIGURED
	var index: int = variant_set.find_index(variant_id)
	if index < 0:
		return ERR_DOES_NOT_EXIST
	return _switch_variant(index)


func cycle_variant(direction: int = 1) -> Error:
	if _variant_index < 0 or variant_set == null:
		return ERR_UNAVAILABLE
	if not variant_set.validate().is_empty():
		return ERR_UNCONFIGURED
	if direction == 0:
		return ERR_INVALID_PARAMETER
	var size: int = variant_set.variants.size()
	return _switch_variant(posmod(_variant_index + signi(direction), size))


## Prepare and validate the candidate before replacing the previous preview.
func _switch_variant(index: int) -> Error:
	if mode != Mode.SINGLE:
		return ERR_UNAVAILABLE
	if _confirm_pending:
		return ERR_BUSY
	if index == _variant_index:
		return OK
	var candidate_scene: PackedScene = variant_set.variants[index].scene
	var instance: Node = candidate_scene.instantiate()
	if not instance is Node3D:
		if instance != null:
			instance.free()
		return ERR_INVALID_DATA
	var root: Node3D = instance as Node3D
	var component: NucleusPlaceable3D = NucleusPlaceable3D.find_in(root)
	if component == null or component.profile == null:
		root.free()
		return ERR_INVALID_DATA
	if not component.profile.validate().is_empty():
		root.free()
		return ERR_INVALID_DATA
	if component.target != null and component.target != root:
		root.free()
		return ERR_INVALID_DATA
	var previous_transform: Transform3D = _roots[0].global_transform
	world_parent.add_child(root)
	if component.get_root() != root:
		root.free()
		return ERR_INVALID_DATA
	root.global_transform = previous_transform
	var saved: Array = _preview_on(root)
	# The previous candidate was not committed: replace only the session-owned
	# preview, preserve cursor and yaw, and restart physical validation.
	_preview_off(_saved_visuals[0])
	_roots[0].free()
	_roots[0] = root
	_placeables[0] = component
	_saved_visuals[0] = saved
	_scene = candidate_scene
	_variant_index = index
	component.variant_id = get_variant_id()
	_preview_feedback_state = -1
	is_candidate_valid = false
	last_reason = &"checking"
	_refresh_from_current_hit()
	if _current_hit.is_empty():
		_set_invalid(&"no_surface")
	variant_changed.emit(get_variant_id(), index)
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
	# Lower origins first so a member resting on another selected member
	# can use the already validated support transform during group movement.
	var ordered_items := items.duplicate()
	ordered_items.sort_custom(
		func(a: NucleusPlaceable3D, b: NucleusPlaceable3D) -> bool:
			return a.get_root().global_position.y < b.get_root().global_position.y
	)
	roots.clear()
	for component: NucleusPlaceable3D in ordered_items:
		roots.append(component.get_root())
	var supports := _find_internal_supports(roots)
	if not bool(supports.get("valid", false)):
		return ERR_UNAVAILABLE
	cancel()
	_internal_supports = supports["indices"]
	var pivot := Vector3.ZERO
	for root: Node3D in roots:
		pivot += root.global_position
	_group_pivot = pivot / float(roots.size())
	for index: int in range(ordered_items.size()):
		_roots.append(roots[index])
		_placeables.append(ordered_items[index])
		_previous_transforms.append(roots[index].global_transform)
		_saved_visuals.append(_preview_on(roots[index]))
	_initial_heading = _heading_of(_previous_transforms[0].basis)
	_yaw = _initial_heading
	mode = Mode.EDIT if roots.size() == 1 else Mode.EDIT_GROUP
	set_physics_process(camera != null)
	return OK


## Starts a movable preview of detached, already instantiated PackedScene roots.
## The caller retains ownership if validation fails. On success the session owns
## every preview until confirm() or cancel(). Stable IDs are assigned by the game
## only after a confirmed placement. Original world objects are never moved.
func begin_duplicate(detached_roots: Array[Node3D]) -> Error:
	if not _valid_world() or detached_roots.is_empty():
		return ERR_INVALID_PARAMETER
	if detached_roots.size() > maxi(max_group_count, 1):
		return ERR_OUT_OF_MEMORY
	for root: Node3D in detached_roots:
		if root == null or not is_instance_valid(root) or root.get_parent() != null:
			return ERR_INVALID_PARAMETER
		var component := NucleusPlaceable3D.find_in(root)
		if component == null or component.profile == null:
			return ERR_INVALID_DATA
		if not component.profile.validate().is_empty() or not component.profile.can_move:
			return ERR_UNAVAILABLE
		if component.target != null and component.target != root:
			return ERR_INVALID_DATA
	cancel()
	var sum := Vector3.ZERO
	for root: Node3D in detached_roots:
		var authored := root.transform
		world_parent.add_child(root)
		root.global_transform = authored
		_roots.append(root)
		_placeables.append(NucleusPlaceable3D.find_in(root))
		_previous_transforms.append(root.global_transform)
		_saved_visuals.append(_preview_on(root))
		sum += root.global_position
	_group_pivot = sum / float(_roots.size())
	_initial_heading = _heading_of(_previous_transforms[0].basis)
	_yaw = _initial_heading
	mode = Mode.DUPLICATE if _roots.size() == 1 else Mode.DUPLICATE_GROUP
	set_physics_process(camera != null)
	return OK

## Detect dependencies within a selection without requiring game-specific
## object hierarchies. Each supported child keeps its original relative pose.
func _find_internal_supports(roots: Array[Node3D]) -> Dictionary:
	var indices: Dictionary[int, int] = {}
	for i: int in range(roots.size()):
		var root := roots[i]
		var component := NucleusPlaceable3D.find_in(root)
		var profile := component.profile
		# Most selected items are independent. A cheap X/Z broadphase avoids
		# issuing hundreds of physics raycasts for distant ground pieces.
		var potential := false
		for j: int in range(i):
			var below := roots[j]
			var below_profile := NucleusPlaceable3D.find_in(below).profile
			var reach := maxf(
				maxf(below_profile.support_half_extents.x,
					below_profile.support_half_extents.y),
				maxf(profile.support_half_extents.x, profile.support_half_extents.y),
			) + 1.0
			if (
				root.global_position.y > below.global_position.y + 0.1
				and absf(root.global_position.x - below.global_position.x) <= reach
				and absf(root.global_position.z - below.global_position.z) <= reach
			):
				potential = true
				break
		if not potential:
			continue
		var query := PhysicsRayQueryParameters3D.create(
			root.global_position + Vector3.UP * 0.12,
			root.global_position - Vector3.UP * profile.support_cast_below,
			profile.support_mask,
			NucleusPlaceable3D.collision_rids(root),
		)
		query.collide_with_areas = false
		var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var underneath := NucleusPlaceable3D.find_for_collider(hit.get("collider"))
		if underneath == null or underneath.get_root() not in roots:
			continue
		var j := roots.find(underneath.get_root())
		if j >= i:
			return {"valid": false}
		if not (
			underneath.profile.kind in profile.supported_by_kinds
			and profile.kind in underneath.profile.accepts_on_top_kinds
		):
			return {"valid": false}
		indices[i] = j
	return {"valid": true, "indices": indices}


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
	# One free piece needs continuous cursor tracking, not a 65 ms step cadence.
	# Keep the throttle for chains and large groups, where the physics budget matters.
	var continuous := _continuous_free_preview()
	var tolerance := 0.001 if continuous else cursor_tolerance
	if not _validation_pending and _hit_changed(hit, _candidate_hit, tolerance):
		if (
			continuous
			or _last_batch_usec < 0
			or now - _last_batch_usec >= preview_interval_ms * 1000
		):
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


## Lightweight HUD/debug readout; no new diagnostics owner or polling of physics.
func get_validation_progress() -> Vector2i:
	if not _validation_pending:
		return Vector2i.ZERO
	var count := _pending_entries.size()
	if _pending_index < count:
		return Vector2i(_pending_index, count)
	if mode in [Mode.CHAIN, Mode.PATH, Mode.EDIT_GROUP, Mode.DUPLICATE_GROUP]:
		var pairs := int(float(count * (count - 1)) / 2.0)
		var done := int(float(_pair_i * (2 * count - _pair_i - 1)) / 2.0)
		done += maxi(0, _pair_j - _pair_i - 1)
		return Vector2i(count + mini(done, pairs), count + pairs)
	return Vector2i(count, count)


func _refresh_from_current_hit() -> void:
	_candidate_hit.clear()
	_last_batch_usec = -1
	_validation_pending = false
	if not _current_hit.is_empty():
		_schedule_validation(_current_hit)
		_pump_validation()


## Single-object and small-group free previews can finish within one tick.
## Longer groups/chains retain their bounded, throttled work scheduling.
func _continuous_free_preview() -> bool:
	if _placeables.is_empty() or mode == Mode.IDLE:
		return false
	if bool(get_snap_settings(_placeables[0].profile).get("enabled", false)):
		return false
	return (
		mode in [Mode.SINGLE, Mode.DUPLICATE]
		or mode == Mode.EDIT
		or (mode == Mode.EDIT_GROUP and _roots.size() <= max_checks_per_tick)
	)


func _hit_changed(
	next_hit: Dictionary,
	previous_hit: Dictionary,
	tolerance: float = -1.0,
) -> bool:
	if next_hit.is_empty() or previous_hit.is_empty():
		return next_hit.is_empty() != previous_hit.is_empty()
	if next_hit.get("collider") != previous_hit.get("collider"):
		return true
	var a: Vector3 = next_hit.get("position", Vector3.ZERO)
	var b: Vector3 = previous_hit.get("position", Vector3.ZERO)
	var threshold := cursor_tolerance if tolerance < 0.0 else tolerance
	return a.distance_squared_to(b) > threshold * threshold


func _schedule_validation(hit: Dictionary) -> void:
	_candidate_hit = hit.duplicate()
	_last_batch_usec = Time.get_ticks_usec()
	_pending_entries.clear()
	_pending_transforms.clear()
	_pending_index = 0
	_pair_i = 0
	_pair_j = 1
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
				profile.chain_curve_subdivisions, profile.chain_curve_tension,
			)
			for step: Dictionary in layout:
				result.append({
					"position": step["position"], "yaw": step["yaw"], "profile": profile,
				})
	elif mode in [Mode.EDIT_GROUP, Mode.DUPLICATE, Mode.DUPLICATE_GROUP]:
		var rotation := Basis(Vector3.UP, _yaw - _initial_heading)
		var first_origin := _previous_transforms[0].origin
		var destination_pivot := point + (_group_pivot - first_origin)
		var snap := get_snap_settings(profile)
		if bool(snap.get("enabled", false)):
			destination_pivot = NucleusPlacementSolver3D.snap_horizontal(
				destination_pivot, snap["step"], snap["origin"],
			)
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
		var snap := get_snap_settings(profile)
		var visuals: Dictionary = (
			placeable.get_visual_bounds()
			if profile.origin_mode == NucleusPlacementProfile3D.OriginMode.VISUAL_BOTTOM
			else {}
		)
		if (
			mode in [Mode.EDIT_GROUP, Mode.DUPLICATE, Mode.DUPLICATE_GROUP]
			or (mode == Mode.EDIT and not profile.can_move)
		):
			# Group positions already share one quantized pivot, retaining offsets.
			# Rotation-only editing must not translate an existing object.
			snap = {"enabled": false}
		var result: Dictionary
		if mode == Mode.SINGLE or mode == Mode.EDIT:
			if mode == Mode.EDIT and not profile.can_move:
				result = NucleusPlacementSolver3D.evaluate_at(
					space, profile, entry["position"], entry["yaw"], exclusions, snap, visuals,
				)
			else:
				result = NucleusPlacementSolver3D.evaluate_hit(
					space, profile, _candidate_hit, entry["yaw"], exclusions, snap, visuals,
				)
		elif mode == Mode.EDIT_GROUP and _internal_supports.has(_pending_index):
			# Reattach stacked members to their moved support, preserving exactly
			# the relative transform, including vertical offset and orientation.
			var parent_index: int = _internal_supports[_pending_index]
			var relative: Transform3D = (
				_previous_transforms[parent_index].affine_inverse()
				* _previous_transforms[_pending_index]
			)
			var transformed: Transform3D = _pending_transforms[parent_index] * relative
			var free := NucleusPlacementQueries3D.is_transform_free(
				space, profile.clearance_shape,
				transformed * Transform3D(Basis.IDENTITY, profile.clearance_offset),
				profile.obstacle_mask, exclusions, true, profile.check_areas,
				profile.collision_margin,
			)
			result = {"valid": free, "reason": &"" if free else &"occupied",
				"transform": transformed}
		else:
			result = NucleusPlacementSolver3D.evaluate_at(
				space, profile, entry["position"], entry["yaw"], exclusions, snap, visuals,
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
	if mode in [Mode.CHAIN, Mode.PATH, Mode.EDIT_GROUP, Mode.DUPLICATE_GROUP]:
		var pair_result := _pump_pair_clearance(max_pairs_per_tick)
		if pair_result == &"checking":
			return
		if pair_result != &"":
			_reject_batch(pair_result)
			return
	_validation_pending = false
	_transforms = _pending_transforms.duplicate()
	is_candidate_valid = true
	last_reason = &""
	_set_preview_feedback(true)
	preview_updated.emit(true, &"", _transforms.duplicate())
	if _confirm_pending:
		_complete_confirm()


## Broadphase + SAT, spread over ticks so selecting hundreds of objects or
## extending a long curved chain cannot create an unbounded final-frame spike.
## A supporter and its supported child retain their original relative pose.
func _pump_pair_clearance(budget: int) -> StringName:
	var total := _pending_transforms.size()
	var is_chain := mode in [Mode.CHAIN, Mode.PATH]
	var done := 0
	while _pair_i < total:
		if _pair_j >= total:
			_pair_i += 1
			_pair_j = _pair_i + 1
			continue
		var i := _pair_i
		var j := _pair_j
		_pair_j += 1
		done += 1
		if not is_chain and _internal_supports.get(j, -1) == i:
			if done >= budget:
				return &"checking"
			continue
		var first := _placeables[i].profile
		var second := _placeables[j].profile
		var a := first.clearance_shape as BoxShape3D
		var b := second.clearance_shape as BoxShape3D
		if a == null or b == null:
			return &"group_self_overlap" if not is_chain else &"chain_self_overlap"
		var xform_a := _pending_transforms[i]
		var xform_b := _pending_transforms[j]
		# Conservative horizontal bounding circles; cheap for distant pairs.
		var radius_a := Vector2(a.size.x, a.size.z).length() * 0.5
		var radius_b := Vector2(b.size.x, b.size.z).length() * 0.5
		var delta := (xform_a * first.clearance_offset) - (
			xform_b * second.clearance_offset
		)
		if Vector2(delta.x, delta.z).length_squared() <= (radius_a + radius_b) ** 2:
			if NucleusPlacementChain3D.box_footprints_overlap(
				xform_a, xform_b, a.size, first.clearance_offset, 0.01,
				b.size, second.clearance_offset,
			):
				return &"chain_self_overlap" if is_chain else &"group_self_overlap"
		if done >= budget:
			return &"checking"
	return &""


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
	_internal_supports.clear()
	_path_controls.clear()
	_pending_entries.clear()
	_pending_transforms.clear()
	_pending_index = 0
	_pair_i = 0
	_pair_j = 1
	_validation_pending = false
	_confirm_pending = false
	_last_batch_usec = -1
	_candidate_hit.clear()
	_transforms.clear()
	_current_hit.clear()
	_scene = null
	_variant_index = -1
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
