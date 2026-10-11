class_name NucleusPlacementSession3D
extends Node
## Scene-owned preview/edit session for authored placeables.
## No input actions, world registry, currency, saving, UndoRedo or RPC are owned here.
## Consumer code calls begin_*/rotate_*/confirm/cancel on its own authority.

signal preview_updated(valid: bool, reason: StringName, transforms: Array[Transform3D])
signal placement_confirmed(roots: Array[Node3D], was_edit: bool)
signal placement_cancelled(was_edit: bool)
signal placement_rejected(reason: StringName)
signal removal_requested(root: Node3D)

enum Mode { IDLE, SINGLE, CHAIN, EDIT }

@export var world_parent: Node3D
@export var camera: Camera3D
@export_range(0.1, 1000.0, 1.0, "or_greater") var ray_distance: float = 100.0
@export var valid_preview_material: Material
@export var invalid_preview_material: Material

## A game-owned callback to reject costs, permissions and network authority.
## Signature: (Array[Transform3D], Array[NucleusPlaceable3D]) -> Error.
var admission: Callable

var mode: Mode = Mode.IDLE
var last_reason: StringName = &""
var is_candidate_valid: bool = false

var _scene: PackedScene
var _roots: Array[Node3D] = []
var _placeables: Array[NucleusPlaceable3D] = []
var _saved_visuals: Array[Array] = []
var _previous_transform: Transform3D = Transform3D.IDENTITY
var _chain_anchor: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _current_hit: Dictionary = {}
var _transforms: Array[Transform3D] = []
var _preview_feedback_state: int = -1


func _ready() -> void:
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if mode != Mode.IDLE and camera != null:
		update_from_screen(get_viewport().get_mouse_position())


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
	var profile := _placeables[0].profile
	if not profile.allow_chains:
		cancel()
		return ERR_UNAVAILABLE
	_chain_anchor = anchor
	mode = Mode.CHAIN
	return OK


func begin_edit(placeable: NucleusPlaceable3D) -> Error:
	if placeable == null or not is_instance_valid(placeable):
		return ERR_INVALID_PARAMETER
	if (
		placeable.profile == null
		or (not placeable.profile.can_move and not placeable.profile.can_rotate)
	):
		return ERR_UNAVAILABLE
	var root := placeable.get_root()
	if root in _roots:
		return ERR_BUSY
	if (
		root == null
		or not root.is_inside_tree()
		or (not root.is_ancestor_of(placeable) and root != placeable)
	):
		return ERR_INVALID_PARAMETER
	if not placeable.profile.validate().is_empty():
		return ERR_INVALID_DATA
	cancel()
	_previous_transform = root.global_transform
	_roots.append(root)
	_placeables.append(placeable)
	_saved_visuals.append(_preview_on(root))
	_yaw = _heading_of(root.global_basis)
	mode = Mode.EDIT
	set_physics_process(camera != null)
	return OK


## Optional wrapper for game-owned input routing. Does not consume InputMap.
func update_from_screen(screen_position: Vector2) -> bool:
	if mode == Mode.IDLE or camera == null or not is_finite(ray_distance):
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
	return update_from_hit(hit)


## A raycast supplied by the game is also supported (touch, VR, AI, top-down).
func update_from_hit(hit: Dictionary) -> bool:
	if mode == Mode.IDLE or _placeables.is_empty():
		return false
	_current_hit = hit.duplicate()
	_transforms.clear()
	if hit.is_empty() or not hit.get("position") is Vector3:
		_set_invalid(&"no_surface")
		return false
	var profile := _placeables[0].profile
	var space := _roots[0].get_world_3d().direct_space_state
	var points: Array[Vector3] = []
	if mode == Mode.CHAIN:
		points = NucleusPlacementChain3D.points(
			_chain_anchor,
			hit["position"],
			profile.chain_spacing,
			profile.chain_max_count,
		)
		if points.is_empty():
			_set_invalid(&"chain_limit")
			return false
		var resize_result := _resize_chain(points.size())
		if resize_result != OK:
			_set_invalid(&"invalid_scene")
			return false
	else:
		points.append(hit["position"])
	var heading := _yaw
	if mode == Mode.CHAIN:
		heading = NucleusPlacementChain3D.heading(_chain_anchor, hit["position"], _yaw)
	var exclusions := _all_preview_rids()
	var first_reason: StringName = &""
	for i: int in range(points.size()):
		var result: Dictionary
		if mode == Mode.CHAIN:
			result = NucleusPlacementSolver3D.evaluate_at(
				space, profile, points[i], heading, exclusions,
			)
		elif mode == Mode.EDIT and not profile.can_move:
			result = NucleusPlacementSolver3D.evaluate_at(
				space, profile, _previous_transform.origin, heading, exclusions,
			)
		else:
			result = NucleusPlacementSolver3D.evaluate_hit(
				space, profile, hit, heading, exclusions,
			)
		if bool(result.get("valid", false)):
			var transform: Transform3D = result["transform"]
			_transforms.append(transform)
			_roots[i].global_transform = transform
		else:
			first_reason = result.get("reason", &"invalid")
			break
	if first_reason != &"":
		_set_invalid(first_reason)
		return false
	is_candidate_valid = true
	last_reason = &""
	_set_preview_feedback(true)
	preview_updated.emit(true, &"", _transforms.duplicate())
	return true


func rotate_degrees(delta: float) -> Error:
	if not is_finite(delta):
		return ERR_INVALID_PARAMETER
	if mode == Mode.IDLE:
		return ERR_UNAVAILABLE
	var profile := _placeables[0].profile
	if not profile.can_rotate:
		return ERR_UNAVAILABLE
	_yaw = wrapf(_yaw + deg_to_rad(delta), -PI, PI)
	if not _current_hit.is_empty():
		update_from_hit(_current_hit)
	return OK


func rotate_step(direction: int) -> Error:
	if mode == Mode.IDLE:
		return ERR_UNAVAILABLE
	return rotate_degrees(_placeables[0].profile.rotation_increment_degrees * signi(direction))


## Re-check against present world physics before committing a whole chain.
## Caller must still authorize on the authoritative game/server.
func confirm() -> Error:
	if mode == Mode.IDLE:
		return ERR_UNAVAILABLE
	if not update_from_hit(_current_hit) or not is_candidate_valid:
		placement_rejected.emit(last_reason)
		return ERR_UNAVAILABLE
	if admission.is_valid():
		var error: Error = admission.call(_transforms.duplicate(), _placeables.duplicate())
		if error != OK:
			placement_rejected.emit(&"game_policy")
			return error
	var edited := mode == Mode.EDIT
	var committed: Array[Node3D] = _roots.duplicate()
	for index: int in range(_roots.size()):
		_preview_off(_saved_visuals[index])
		_roots[index].global_transform = _transforms[index]
	_clear_state()
	placement_confirmed.emit(committed, edited)
	return OK


func cancel() -> void:
	if mode == Mode.IDLE:
		return
	var was_edit := mode == Mode.EDIT
	if was_edit and not _roots.is_empty() and is_instance_valid(_roots[0]):
		_roots[0].global_transform = _previous_transform
		_preview_off(_saved_visuals[0])
	else:
		_clear_all_new()
	_clear_state()
	placement_cancelled.emit(was_edit)


## A deletion is a request only: inventory, persistence, undo and permission
## checks remain with the game owner.
func request_removal(placeable: NucleusPlaceable3D) -> Error:
	if placeable == null or not is_instance_valid(placeable):
		return ERR_INVALID_PARAMETER
	if mode != Mode.IDLE:
		return ERR_BUSY
	if placeable.profile == null or not placeable.profile.can_remove:
		return ERR_UNAVAILABLE
	removal_requested.emit(placeable.get_root())
	return OK


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


func _resize_chain(count: int) -> Error:
	while _roots.size() < count:
		var err := _append_preview()
		if err != OK:
			return err
	while _roots.size() > count:
		_preview_feedback_state = -1
		_preview_off(_saved_visuals.pop_back())
		_roots.pop_back().free()
		_placeables.pop_back()
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


func _set_preview_feedback(valid: bool) -> void:
	var state := 1 if valid else 0
	if state == _preview_feedback_state:
		return
	_preview_feedback_state = state
	var material := valid_preview_material if valid else invalid_preview_material
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
