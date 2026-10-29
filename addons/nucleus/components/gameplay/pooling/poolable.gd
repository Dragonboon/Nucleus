class_name NucleusPoolable
extends Node
## Lifecycle adapter for a Node owned by NucleusObjectPool.
##
## The component snapshots reusable engine state once and restores it on every
## acquire. Project-specific reset/setup code should listen to acquired/released.

signal acquired(context: Dictionary)
signal released
signal release_requested

@export var target: Node

@export_group("Automatic deactivation")
@export var manage_process_modes: bool = true
@export var manage_visibility: bool = true
@export var manage_collision_shapes: bool = true
@export var reset_physics_velocity: bool = true
@export var stop_audio_on_release: bool = true
@export var stop_particles_on_release: bool = true

var _pool: NucleusObjectPool
var _active: bool = false
var _baseline_captured: bool = false

var _managed_nodes: Array[Node] = []
var _process_modes: Dictionary = {}
var _visibility: Dictionary = {}
var _collision_disabled: Dictionary = {}
var _rigid_sleeping: Dictionary = {}


func _ready() -> void:
	if target == null:
		target = get_parent()


func is_active() -> bool:
	return _active


func get_pool() -> NucleusObjectPool:
	return _pool


func request_release() -> Error:
	if _pool == null or target == null:
		return ERR_UNCONFIGURED

	release_requested.emit()
	return _pool.release(target)


## Rebuilds the reusable baseline from the target's current state.
##
## Use only while the instance is inactive and after intentionally changing the
## scene structure/runtime defaults.
func recapture_baseline() -> Error:
	if _active:
		return ERR_BUSY

	_capture_baseline(true)
	_apply_inactive_state()

	return OK


func _bind_pool(
	pool: NucleusObjectPool,
	pool_target: Node,
) -> void:
	_pool = pool
	target = pool_target
	_capture_baseline(false)
	_set_inactive(false)


func _activate(context: Dictionary) -> void:
	if not _baseline_captured:
		_capture_baseline(false)

	_restore_baseline()
	_active = true
	acquired.emit(context.duplicate(true))


func _set_inactive(emit_released: bool = true) -> void:
	if not _baseline_captured:
		_capture_baseline(false)

	_apply_inactive_state()
	var was_active: bool = _active
	_active = false

	if emit_released and was_active:
		released.emit()


func _capture_baseline(force: bool) -> void:
	if _baseline_captured and not force:
		return

	_process_modes.clear()
	_visibility.clear()
	_collision_disabled.clear()
	_rigid_sleeping.clear()

	if target == null:
		return

	_managed_nodes.assign([target])
	_managed_nodes.append_array(NucleusNodeUtils.descendants(target, true))

	for node: Node in _managed_nodes:
		if not is_instance_valid(node):
			continue
		if manage_process_modes:
			_process_modes[node] = node.process_mode

		if manage_visibility:
			if node is CanvasItem:
				_visibility[node] = (node as CanvasItem).visible
			elif node is Node3D:
				_visibility[node] = (node as Node3D).visible

		if reset_physics_velocity:
			if node is RigidBody2D:
				_rigid_sleeping[node] = (
					(node as RigidBody2D).sleeping
				)
			elif node is RigidBody3D:
				_rigid_sleeping[node] = (
					(node as RigidBody3D).sleeping
				)

		if manage_collision_shapes:
			if node is CollisionShape2D:
				_collision_disabled[node] = (
					(node as CollisionShape2D).disabled
				)
			elif node is CollisionShape3D:
				_collision_disabled[node] = (
					(node as CollisionShape3D).disabled
				)
			elif node is CollisionPolygon2D:
				_collision_disabled[node] = (
					(node as CollisionPolygon2D).disabled
				)
			elif node is CollisionPolygon3D:
				_collision_disabled[node] = (
					(node as CollisionPolygon3D).disabled
				)

	_baseline_captured = true


func _restore_baseline() -> void:
	if target == null:
		return

	if manage_process_modes:
		for node: Variant in _process_modes:
			if is_instance_valid(node):
				var stored_process_mode: int = int(_process_modes[node])
				(node as Node).process_mode = stored_process_mode as Node.ProcessMode

	if manage_collision_shapes:
		for node: Variant in _collision_disabled:
			if not is_instance_valid(node):
				continue

			var disabled: bool = bool(
				_collision_disabled[node]
			)
			_set_collision_disabled(
				node as Node,
				disabled,
			)

	if reset_physics_velocity:
		for node: Variant in _rigid_sleeping:
			if not is_instance_valid(node):
				continue

			if node is RigidBody2D:
				(node as RigidBody2D).sleeping = bool(
					_rigid_sleeping[node]
				)
			elif node is RigidBody3D:
				(node as RigidBody3D).sleeping = bool(
					_rigid_sleeping[node]
				)

	if manage_visibility:
		for node: Variant in _visibility:
			if not is_instance_valid(node):
				continue

			var visible: bool = bool(_visibility[node])

			if node is CanvasItem:
				(node as CanvasItem).visible = visible
			elif node is Node3D:
				(node as Node3D).visible = visible


func _apply_inactive_state() -> void:
	if target == null:
		return

	if stop_audio_on_release:
		_stop_audio()

	if stop_particles_on_release:
		_stop_particles()

	if reset_physics_velocity:
		_reset_physics_velocity()

	if manage_collision_shapes:
		for node: Variant in _collision_disabled:
			if is_instance_valid(node):
				_set_collision_disabled(
					node as Node,
					true,
				)

	if manage_visibility:
		for node: Variant in _visibility:
			if not is_instance_valid(node):
				continue

			if node is CanvasItem:
				(node as CanvasItem).visible = false
			elif node is Node3D:
				(node as Node3D).visible = false

	if manage_process_modes:
		for node: Variant in _process_modes:
			if is_instance_valid(node):
				(node as Node).process_mode = (
					Node.PROCESS_MODE_DISABLED
				)


func _set_collision_disabled(
	node: Node,
	disabled: bool,
) -> void:
	# Deferred writes are safe even when release() originates from a physics
	# overlap/collision callback while the physics server is flushing queries.
	if (
		node is CollisionShape2D
		or node is CollisionShape3D
		or node is CollisionPolygon2D
		or node is CollisionPolygon3D
	):
		node.set_deferred(
			"disabled",
			disabled,
		)


func _reset_physics_velocity() -> void:
	for node: Node in _managed_nodes:
		if not is_instance_valid(node):
			continue
		if node is CharacterBody2D:
			(node as CharacterBody2D).velocity = Vector2.ZERO
		elif node is CharacterBody3D:
			(node as CharacterBody3D).velocity = Vector3.ZERO
		elif node is RigidBody2D:
			var body_2d := node as RigidBody2D
			body_2d.linear_velocity = Vector2.ZERO
			body_2d.angular_velocity = 0.0
			body_2d.sleeping = true
		elif node is RigidBody3D:
			var body_3d := node as RigidBody3D
			body_3d.linear_velocity = Vector3.ZERO
			body_3d.angular_velocity = Vector3.ZERO
			body_3d.sleeping = true


func _stop_audio() -> void:
	for node: Node in _managed_nodes:
		if not is_instance_valid(node):
			continue
		if node is AudioStreamPlayer:
			(node as AudioStreamPlayer).stop()
		elif node is AudioStreamPlayer2D:
			(node as AudioStreamPlayer2D).stop()
		elif node is AudioStreamPlayer3D:
			(node as AudioStreamPlayer3D).stop()


func _stop_particles() -> void:
	for node: Node in _managed_nodes:
		if not is_instance_valid(node):
			continue
		if node is GPUParticles2D:
			(node as GPUParticles2D).emitting = false
		elif node is GPUParticles3D:
			(node as GPUParticles3D).emitting = false
		elif node is CPUParticles2D:
			(node as CPUParticles2D).emitting = false
		elif node is CPUParticles3D:
			(node as CPUParticles3D).emitting = false
