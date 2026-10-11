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
	var stride: int = 7 if profile.roadbed_enabled else 2
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
		var v: float = traveled / profile.uv_repeat_meters
		if profile.roadbed_enabled:
			var shoulder: float = profile.shoulder_width
			var full_half: float = half_width + shoulder
			var center_height: float = (left.y + right.y) * 0.5
			var outer_left: Vector3 = center - across * full_half
			var outer_right: Vector3 = center + across * full_half
			if surface_sampler != null:
				var hit_left: NucleusSurfaceSample3D = surface_sampler.sample(outer_left)
				var hit_right: NucleusSurfaceSample3D = surface_sampler.sample(outer_right)
				if hit_left == null or hit_right == null:
					return _fail(ERR_UNAVAILABLE)
				outer_left.y = hit_left.position.y + profile.surface_offset
				outer_right.y = hit_right.position.y + profile.surface_offset
			else:
				outer_left.y = center_height
				outer_right.y = center_height
			outer_left.y -= profile.shoulder_drop
			outer_right.y -= profile.shoulder_drop
			var crown: Vector3 = center
			crown.y = center_height + profile.crown_height
			var lower_left: Vector3 = outer_left - Vector3.UP * profile.roadbed_thickness
			var lower_right: Vector3 = outer_right - Vector3.UP * profile.roadbed_thickness
			var section: Array[Vector3] = [
				outer_left, left, crown, right, outer_right,
				lower_left, lower_right,
			]
			for j in range(section.size()):
				if not section[j].is_finite():
					return _fail(ERR_INVALID_DATA)
				positions.append(mesh_from_world * section[j])
				var u: float = [
					0.0, shoulder / (full_half * 2.0),
					0.5, 1.0 - shoulder / (full_half * 2.0), 1.0,
					0.0, 1.0,
				][j]
				uvs.append(Vector2(u, v))
			if i > 0:
				var prev: int = (i - 1) * stride
				var next: int = i * stride
				for lane in range(4):
					_append_quad(indices, prev + lane, prev + lane + 1,
						next + lane, next + lane + 1)
				_append_quad(indices, prev + 5, prev, next + 5, next)
				_append_quad(indices, prev + 4, prev + 6, next + 4, next + 6)
				_append_quad(indices, prev + 6, prev + 5, next + 6, next + 5)
		else:
			positions.append(mesh_from_world * left)
			positions.append(mesh_from_world * right)
			uvs.append(Vector2(0.0, v))
			uvs.append(Vector2(1.0, v))
			if i > 0:
				var previous: int = 2 * (i - 1)
				var current: int = 2 * i
				_append_quad(indices, previous, previous + 1, current, current + 1)

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


static func _append_quad(
	indices: PackedInt32Array,
	a: int,
	b: int,
	c: int,
	d: int,
) -> void:
	indices.append_array(PackedInt32Array([a, b, c, b, d, c]))


static func _fail(error: Error) -> Dictionary:
	return {"error": error}
