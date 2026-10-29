class_name NucleusCameraFollow2D
extends Node
## Target-switching adapter for Godot's native Camera2D.
##
## Camera2D already owns smoothing, drag margins, limits, zoom, and rotation
## smoothing. Nucleus only supplies scene-owned target following and snapping.

signal target_changed(
	target: Node2D,
	previous_target: Node2D,
)

@export var camera: Camera2D
@export var target: Node2D
@export var offset: Vector2 = Vector2.ZERO
@export var enabled: bool = true
@export var follow_physics_priority: int = 100


func _ready() -> void:
	process_physics_priority = follow_physics_priority

	if camera == null:
		camera = get_parent() as Camera2D

	if camera == null:
		NucleusLog.error(
			"%s requires a Camera2D." % get_path(),
			&"CameraFollow2D",
		)
		return

	if target:
		snap_to_target()


func _physics_process(_delta: float) -> void:
	if not enabled or camera == null or target == null:
		return

	camera.global_position = target.global_position + offset


func set_target(
	new_target: Node2D,
	snap: bool = true,
) -> void:
	if target == new_target:
		return

	var previous_target: Node2D = target
	target = new_target

	if snap and target:
		snap_to_target()

	target_changed.emit(
		target,
		previous_target,
	)


func snap_to_target() -> void:
	if camera == null or target == null:
		return

	camera.global_position = target.global_position + offset
	camera.reset_smoothing()
	camera.reset_physics_interpolation()
