class_name NucleusScatterBatch3D
extends MultiMeshInstance3D
## One bounded native rendering batch. No animation or physics ownership.
## Instances and bounds are authored once, not updated every frame.

const MAX_BATCH_INSTANCES: int = 512


func configure(
	variant: NucleusScatterVariant3D,
	world_transforms: Array[Transform3D],
) -> Error:
	if variant == null or not variant.is_usable():
		return ERR_INVALID_PARAMETER
	if world_transforms.size() > MAX_BATCH_INSTANCES:
		return ERR_OUT_OF_MEMORY
	var mesh_bounds: AABB = variant.mesh.get_aabb()
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = variant.mesh
	multi.instance_count = world_transforms.size()
	var local_inverse: Transform3D = global_transform.affine_inverse()
	var min_corner: Vector3 = Vector3.ZERO
	var max_corner: Vector3 = Vector3.ZERO
	var has_bounds: bool = false
	for index: int in range(world_transforms.size()):
		var relative: Transform3D = local_inverse * world_transforms[index]
		multi.set_instance_transform(index, relative)
		# Conservative per-instance bound includes the source mesh's offset and rotation.
		for corner: int in range(8):
			var mesh_point: Vector3 = mesh_bounds.position + Vector3(
				mesh_bounds.size.x if (corner & 1) != 0 else 0.0,
				mesh_bounds.size.y if (corner & 2) != 0 else 0.0,
				mesh_bounds.size.z if (corner & 4) != 0 else 0.0,
			)
			var transformed_point: Vector3 = relative * mesh_point
			if not has_bounds:
				min_corner = transformed_point
				max_corner = transformed_point
				has_bounds = true
			else:
				min_corner = min_corner.min(transformed_point)
				max_corner = max_corner.max(transformed_point)
	if has_bounds:
		multi.custom_aabb = AABB(min_corner, max_corner - min_corner).grow(0.1)
	multimesh = multi
	material_override = variant.material_override
	cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if variant.cast_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	visibility_range_end = maxf(variant.visibility_end, 0.0)
	return OK
