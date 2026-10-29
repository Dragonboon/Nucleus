extends RefCounted
## Internal scene composition helper for one generated terrain patch.

const MeshBuilder := preload(
	"res://addons/nucleus/modules/terrain/terrain_mesh_builder.gd"
)


static func build_patch(
	profile: NucleusTerrainProfile,
	material: Material,
	position: Vector3,
	scale: float = 1.0,
	force_island: bool = false,
	resolution_override: int = 0,
	with_collision: bool = true,
	include_lods: bool = true,
	material_overlay: Material = null,
) -> Dictionary:
	var mesh_result := MeshBuilder.build_mesh(
		profile,
		position,
		scale,
		resolution_override,
		force_island,
		include_lods,
	)

	if mesh_result.get("error", FAILED) != OK:
		return mesh_result

	var patch := Node3D.new()
	patch.position = position
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = mesh_result["mesh"]
	mesh_instance.material_override = material
	mesh_instance.material_overlay = material_overlay
	mesh_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if profile.cast_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	patch.add_child(mesh_instance)

	if with_collision and profile.collision_mode != NucleusTerrainProfile.CollisionMode.DISABLED:
		var collision_error := _add_collision(
			patch,
			mesh_instance,
			profile,
			position,
			scale,
			force_island,
		)
		if collision_error != OK:
			patch.free()
			return {"error": collision_error}

	return {
		"error": OK,
		"node": patch,
		"mesh": mesh_instance.mesh,
	}


static func _add_collision(
	patch: Node3D,
	mesh_instance: MeshInstance3D,
	profile: NucleusTerrainProfile,
	position: Vector3,
	scale: float,
	force_island: bool,
) -> Error:
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = profile.collision_layer
	body.collision_mask = profile.collision_mask
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"

	if profile.collision_mode == NucleusTerrainProfile.CollisionMode.HEIGHTMAP:
		var shape_result := MeshBuilder.build_heightmap_shape(
			profile,
			position,
			scale,
			force_island,
		)
		if shape_result.get("error", FAILED) != OK:
			return shape_result.get("error", FAILED)

		var uniform_scale: float = shape_result["uniform_scale"]
		collision.shape = shape_result["shape"]
		collision.scale = Vector3.ONE * uniform_scale
	else:
		collision.shape = mesh_instance.mesh.create_trimesh_shape()
		if collision.shape == null:
			return ERR_CANT_CREATE

	body.add_child(collision)
	patch.add_child(body)
	return OK
