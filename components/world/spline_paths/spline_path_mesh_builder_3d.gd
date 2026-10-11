class_name NucleusSplinePathMeshBuilder3D
extends RefCounted
## Synchronous, bounded ribbon builder using native Curve3D baked samples.
## Pure geometry computation, except optional read-only surface sampling.
## Input curve remains untouched; errors never return partial meshes.

const MIN_SEGMENT: float = 0.00001


static func build(
	curve: Curve3D,
	profile: NucleusSplinePathProfile3D,
	curve_to_world: Transform3D = Transform3D.IDENTITY,
	mesh_to_world: Transform3D = Transform3D.IDENTITY,
	surface_sampler: NucleusSurfaceSampler3D = null,
) -> Dictionary:
	if curve == null or profile == null or not profile.validate().is_empty():
		return _fail(ERR_INVALID_PARAMETER)
	if not curve_to_world.is_finite() or not mesh_to_world.is_finite():
		return _fail(ERR_INVALID_PARAMETER)
	if absf(mesh_to_world.basis.determinant()) < MIN_SEGMENT:
		return _fail(ERR_INVALID_PARAMETER)
	if curve.point_count < 2:
		return _fail(ERR_INVALID_DATA)
	if surface_sampler != null and not surface_sampler.is_inside_tree():
		return _fail(ERR_UNAVAILABLE)

	var length: float = curve.get_baked_length()
	if not is_finite(length) or length < MIN_SEGMENT:
		return _fail(ERR_INVALID_DATA)
	var segments: int = maxi(1, int(ceil(length / profile.sample_spacing)))
	if segments + 1 > profile.max_sections:
		return _fail(ERR_OUT_OF_MEMORY)

	var mesh_from_world: Transform3D = mesh_to_world.affine_inverse()
	var positions := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var previous_center := Vector3.ZERO
	var traveled: float = 0.0
	var last_heading := Vector3.ZERO
	for i in range(segments + 1):
		var offset: float = length * float(i) / float(segments)
		var center: Vector3 = curve_to_world * curve.sample_baked(offset, true)
		var ahead: float = minf(length, offset + profile.sample_spacing * 0.25)
		var behind: float = maxf(0.0, offset - profile.sample_spacing * 0.25)
		var tangent: Vector3 = curve_to_world.basis * (
			curve.sample_baked(ahead, true) - curve.sample_baked(behind, true)
		)
		tangent.y = 0.0
		if not center.is_finite() or not tangent.is_finite():
			return _fail(ERR_INVALID_DATA)
		if tangent.length_squared() < MIN_SEGMENT:
			return _fail(ERR_INVALID_DATA)
		var heading: Vector3 = tangent.normalized()
		if i > 0 and last_heading.dot(heading) < -0.5:
			return _fail(ERR_INVALID_DATA)
		last_heading = heading
		var across: Vector3 = heading.cross(Vector3.UP)
		var half_width: float = profile.width * 0.5
		var left: Vector3 = center - across * half_width
		var right: Vector3 = center + across * half_width
		if surface_sampler != null:
			var left_hit: NucleusSurfaceSample3D = surface_sampler.sample(left)
			var right_hit: NucleusSurfaceSample3D = surface_sampler.sample(right)
			if left_hit == null or right_hit == null:
				return _fail(ERR_UNAVAILABLE)
			left.y = left_hit.position.y
			right.y = right_hit.position.y
		left.y += profile.surface_offset
		right.y += profile.surface_offset
		if not left.is_finite() or not right.is_finite():
			return _fail(ERR_INVALID_DATA)
		var middle: Vector3 = (left + right) * 0.5
		if i > 0:
			var advance: float = previous_center.distance_to(middle)
			if not is_finite(advance) or advance < MIN_SEGMENT:
				return _fail(ERR_INVALID_DATA)
			traveled += advance
		previous_center = middle
		positions.append(mesh_from_world * left)
		positions.append(mesh_from_world * right)
		var v: float = traveled / profile.uv_repeat_meters
		uvs.append(Vector2(0.0, v))
		uvs.append(Vector2(1.0, v))
		if i > 0:
			var a: int = 2 * (i - 1)
			var b: int = a + 1
			var c: int = 2 * i
			var d: int = c + 1
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))

	var normals := PackedVector3Array()
	normals.resize(positions.size())
	for triangle in range(0, indices.size(), 3):
		var a: int = indices[triangle]
		var b: int = indices[triangle + 1]
		var c: int = indices[triangle + 2]
		var cross: Vector3 = (positions[b] - positions[a]).cross(
			positions[c] - positions[a]
		)
		if not cross.is_finite() or cross.length_squared() < MIN_SEGMENT * MIN_SEGMENT:
			return _fail(ERR_INVALID_DATA)
		normals[a] += cross
		normals[b] += cross
		normals[c] += cross
	for i in range(normals.size()):
		if normals[i].length_squared() < MIN_SEGMENT * MIN_SEGMENT:
			return _fail(ERR_INVALID_DATA)
		normals[i] = normals[i].normalized()

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {
		"error": OK,
		"mesh": mesh,
		"sections": segments + 1,
		"length": traveled,
	}


static func _fail(error: Error) -> Dictionary:
	return {"error": error}
