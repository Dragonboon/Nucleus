class_name NucleusActivityGate
extends Node
## Explicitly gates expensive scene activity while preserving authored baselines.
##
## The game decides when an entity is relevant. This component only applies the
## requested active/inactive state; it does not infer distance or gameplay rules.

signal activity_changed(active: bool)

@export var target: Node
@export var start_active: bool = true

@export_group("Managed state")
@export var manage_process_mode: bool = true
@export var manage_visibility: bool = false
@export var manage_particle_emission: bool = false
@export var manage_rigid_body_sleep: bool = false

var _active: bool = true
var _baseline_captured: bool = false
var _baseline_process_mode: int = Node.PROCESS_MODE_INHERIT
var _has_visibility: bool = false
var _baseline_visible: bool = true
var _particle_emission: Dictionary = {}
var _rigid_sleeping: Dictionary = {}


func _ready() -> void:
	if target == null:
		target = get_parent()

	if target == null:
		NucleusLog.error(
			"%s requires a target or parent." % get_path(),
			&"ActivityGate",
		)
		return

	_capture_baseline()
	_apply_active_state(start_active, true)


func set_active(value: bool) -> void:
	_apply_active_state(value, false)


func is_active() -> bool:
	return _active


## Rebuilds the authored baseline after an intentional runtime reconfiguration.
## Recapture is only valid while active so disabled state is never stored as the
## new baseline by accident.
func recapture_baseline() -> Error:
	if not _active:
		return ERR_BUSY
	_capture_baseline(true)
	return OK


func _apply_active_state(value: bool, force: bool) -> void:
	if target == null:
		return

	if not _baseline_captured:
		_capture_baseline()

	if _active == value and not force:
		return

	_active = value

	if _active:
		_restore_baseline()
	else:
		_apply_inactive_state()

	activity_changed.emit(_active)


func _capture_baseline(force: bool = false) -> void:
	if _baseline_captured and not force:
		return
	if target == null:
		return

	_particle_emission.clear()
	_rigid_sleeping.clear()

	if manage_process_mode:
		_baseline_process_mode = int(target.process_mode)

	_has_visibility = false
	if manage_visibility:
		if target is CanvasItem:
			_has_visibility = true
			_baseline_visible = (target as CanvasItem).visible
		elif target is Node3D:
			_has_visibility = true
			_baseline_visible = (target as Node3D).visible

	if manage_particle_emission or manage_rigid_body_sleep:
		for node: Node in NucleusNodeUtils.descendants(target, true):
			if manage_particle_emission:
				if node is GPUParticles2D:
					_particle_emission[node] = (node as GPUParticles2D).emitting
				elif node is GPUParticles3D:
					_particle_emission[node] = (node as GPUParticles3D).emitting
				elif node is CPUParticles2D:
					_particle_emission[node] = (node as CPUParticles2D).emitting
				elif node is CPUParticles3D:
					_particle_emission[node] = (node as CPUParticles3D).emitting

			if manage_rigid_body_sleep:
				if node is RigidBody2D:
					_rigid_sleeping[node] = (node as RigidBody2D).sleeping
				elif node is RigidBody3D:
					_rigid_sleeping[node] = (node as RigidBody3D).sleeping

	_baseline_captured = true


func _restore_baseline() -> void:
	if target == null:
		return

	if manage_process_mode:
		target.process_mode = _baseline_process_mode as Node.ProcessMode

	if manage_visibility and _has_visibility:
		if target is CanvasItem:
			(target as CanvasItem).visible = _baseline_visible
		elif target is Node3D:
			(target as Node3D).visible = _baseline_visible

	if manage_particle_emission:
		for node: Variant in _particle_emission:
			if not is_instance_valid(node):
				continue
			_set_particle_emitting(
				node as Node,
				bool(_particle_emission[node]),
			)

	if manage_rigid_body_sleep:
		for node: Variant in _rigid_sleeping:
			if not is_instance_valid(node):
				continue
			if node is RigidBody2D:
				(node as RigidBody2D).sleeping = bool(_rigid_sleeping[node])
			elif node is RigidBody3D:
				(node as RigidBody3D).sleeping = bool(_rigid_sleeping[node])


func _apply_inactive_state() -> void:
	if target == null:
		return

	if manage_particle_emission:
		for node: Variant in _particle_emission:
			if is_instance_valid(node):
				_set_particle_emitting(node as Node, false)

	if manage_rigid_body_sleep:
		for node: Variant in _rigid_sleeping:
			if not is_instance_valid(node):
				continue
			if node is RigidBody2D:
				(node as RigidBody2D).sleeping = true
			elif node is RigidBody3D:
				(node as RigidBody3D).sleeping = true

	if manage_visibility and _has_visibility:
		if target is CanvasItem:
			(target as CanvasItem).visible = false
		elif target is Node3D:
			(target as Node3D).visible = false

	if manage_process_mode:
		target.process_mode = Node.PROCESS_MODE_DISABLED


func _set_particle_emitting(node: Node, value: bool) -> void:
	if node is GPUParticles2D:
		(node as GPUParticles2D).emitting = value
	elif node is GPUParticles3D:
		(node as GPUParticles3D).emitting = value
	elif node is CPUParticles2D:
		(node as CPUParticles2D).emitting = value
	elif node is CPUParticles3D:
		(node as CPUParticles3D).emitting = value
