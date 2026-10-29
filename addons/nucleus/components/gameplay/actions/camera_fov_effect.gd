class_name NucleusCameraFovEffect
extends NucleusActionEffect
## Drives an existing NucleusCameraFov3D when an action commits.

@export var camera_fov: NucleusCameraFov3D
@export_range(1.0, 179.0, 0.1)
var target_fov: float = 75.0
@export var instant: bool = false
@export var reset_to_base: bool = false


func _ready() -> void:
	if camera_fov == null:
		camera_fov = _find_camera_fov()

	if camera_fov == null:
		NucleusLog.error(
			"%s requires a NucleusCameraFov3D." % get_path(),
			&"CameraFovEffect",
		)


func can_apply(_context: Dictionary) -> Error:
	return OK if camera_fov else ERR_UNCONFIGURED


func apply(context: Dictionary) -> Error:
	var error: Error = can_apply(context)

	if error != OK:
		return error

	if reset_to_base:
		camera_fov.reset_fov(instant)
	else:
		camera_fov.set_target_fov(
			target_fov,
			instant,
		)

	return OK


func _find_camera_fov() -> NucleusCameraFov3D:
	var root: Node = get_parent()

	while root:
		for node: Node in NucleusNodeUtils.descendants(root):
			if node is NucleusCameraFov3D:
				return node as NucleusCameraFov3D

		root = root.get_parent()

	return null
