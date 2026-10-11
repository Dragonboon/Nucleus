class_name NucleusMeshSliceBackend3D
extends RefCounted
## Bounded, synchronous plane cut of a closed triangle mesh with ONE simple loop.
## Returns two independent ArrayMeshes or {"reason": StringName}. No Node writes.
## Unsupported: skinned/custom vertex streams, cut holes and coplanar vertices.

const MAX_TRIANGLES: int = 8192
const MAX_SEGMENTS: int = 4096
const MAX_SURFACES: int = 32
const EPSILON: float = 0.00001


static func slice(
	mesh: Mesh,
	plane_point: Vector3,
	plane_normal: Vector3,
	cap_material: Material = null,
) -> Dictionary:
	if mesh == null or not plane_point.is_finite() or not plane_normal.is_finite():
		return _failure(&"invalid_input")
	if plane_normal.length_squared() < 0.000001:
		return _failure(&"invalid_plane")
	if mesh.get_surface_count() < 1 or mesh.get_surface_count() > MAX_SURFACES:
		return _failure(&"surface_limit")
	if mesh.get_blend_shape_count() > 0:
		return _failure(&"blend_shapes_unsupported")
	var normal: Vector3 = plane_normal.normalized()
	var epsilon: float = maxf(EPSILON, mesh.get_aabb().size.length() * 0.000001)
	var side_a: Array[Dictionary] = []
	var side_b: Array[Dictionary] = []
	var segments: Array[PackedVector3Array] = []
	var surfaces: Array[Dictionary] = []
	var triangles: int = 0

	for surface_index in range(mesh.get_surface_count()):
		if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			return _failure(&"non_triangle_surface")
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		for attribute in [
			Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS,
			Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1,
			Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3,
		]:
			if arrays[attribute] != null and not arrays[attribute].is_empty():
				return _failure(&"vertex_format_unsupported")
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var vertex_count: int = indices.size() if not indices.is_empty() else positions.size()
		if vertex_count < 3 or vertex_count % 3 != 0:
			return _failure(&"invalid_triangles")
		triangles += vertex_count / 3
		if triangles > MAX_TRIANGLES:
			return _failure(&"triangle_limit")
		var positive: Array[Dictionary] = []
		var negative: Array[Dictionary] = []
		for offset in range(0, vertex_count, 3):
			var ids := PackedInt32Array()
			for corner in range(3):
				var id: int = indices[offset + corner] if not indices.is_empty() else offset + corner
				if id < 0 or id >= positions.size():
					return _failure(&"invalid_indices")
				ids.append(id)
			var face_normal: Vector3 = (
				positions[ids[1]] - positions[ids[0]]
			).cross(positions[ids[2]] - positions[ids[0]]).normalized()
			var triangle: Array[Dictionary] = []
			var positive_count: int = 0
			for id in ids:
				var position: Vector3 = positions[id]
				if not position.is_finite():
					return _failure(&"invalid_vertex")
				var distance: float = normal.dot(position - plane_point)
				if absf(distance) <= epsilon:
					return _failure(&"coplanar_vertex")
				if distance > 0.0:
					positive_count += 1
				var vertex_normal: Vector3 = normals[id] if normals.size() == positions.size() else face_normal
				var uv: Vector2 = uvs[id] if uvs.size() == positions.size() else Vector2.ZERO
				triangle.append({"position": position, "normal": vertex_normal, "uv": uv})
			if positive_count == 3:
				_add_polygon(positive, triangle)
			elif positive_count == 0:
				_add_polygon(negative, triangle)
			else:
				_add_polygon(
					positive, _clip(triangle, plane_point, normal, true)
				)
				_add_polygon(
					negative, _clip(triangle, plane_point, normal, false)
				)
				var segment: PackedVector3Array = _segment(triangle, plane_point, normal)
				if segment.size() != 2 or segments.size() >= MAX_SEGMENTS:
					return _failure(&"segment_limit")
				segments.append(segment)
		side_a.append({"vertices": positive, "material": mesh.surface_get_material(surface_index)})
		side_b.append({"vertices": negative, "material": mesh.surface_get_material(surface_index)})
	if segments.is_empty():
		return _failure(&"no_intersection")
	var ring: Array[Vector3] = _single_ring(segments, epsilon)
	if ring.size() < 3:
		return _failure(&"open_or_complex_contour")

	var axis_u: Vector3 = normal.cross(Vector3.UP)
	if axis_u.length_squared() < 0.001:
		axis_u = normal.cross(Vector3.RIGHT)
	axis_u = axis_u.normalized()
	var axis_v: Vector3 = normal.cross(axis_u)
	var polygon := PackedVector2Array()
	for point in ring:
		polygon.append(Vector2(
			(point - plane_point).dot(axis_u),
			(point - plane_point).dot(axis_v),
		))
	var cap_indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	if cap_indices.size() != (ring.size() - 2) * 3:
		return _failure(&"cap_triangulation_failed")
	var cap_a: Array[Dictionary] = []
	var cap_b: Array[Dictionary] = []
	for index in range(0, cap_indices.size(), 3):
		var p0: Vector3 = ring[cap_indices[index]]
		var p1: Vector3 = ring[cap_indices[index + 1]]
		var p2: Vector3 = ring[cap_indices[index + 2]]
		if (p1 - p0).cross(p2 - p0).dot(normal) < 0.0:
			var swap: Vector3 = p1
			p1 = p2
			p2 = swap
		for p in [p0, p1, p2]:
			cap_b.append(_cap_vertex(p, normal, plane_point, axis_u, axis_v))
		for p in [p0, p2, p1]:
			cap_a.append(_cap_vertex(p, -normal, plane_point, axis_u, axis_v))
	side_a.append({"vertices": cap_a, "material": cap_material})
	side_b.append({"vertices": cap_b, "material": cap_material})
	var positive_mesh: ArrayMesh = _build_mesh(side_a)
	var negative_mesh: ArrayMesh = _build_mesh(side_b)
	if positive_mesh.get_surface_count() == 0 or negative_mesh.get_surface_count() == 0:
		return _failure(&"empty_half")
	return {
		"reason": &"ok",
		"positive": positive_mesh,
		"negative": negative_mesh,
		"cut_vertices": ring.size(),
	}


## Returns null on failure. Call slice() for the diagnostic reason.
static func to_pattern(result: Dictionary) -> NucleusFracturePattern3D:
	if result.get("reason") != &"ok":
		return null
	var pattern := NucleusFracturePattern3D.new()
	for key in ["positive", "negative"]:
		var shard := NucleusFractureShard3D.new()
		shard.mesh = result[key]
		pattern.shards.append(shard)
	return pattern


static func _failure(reason: StringName) -> Dictionary:
	return {"reason": reason}


static func _interpolate(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var na: Vector3 = a["normal"]
	var nb: Vector3 = b["normal"]
	var ua: Vector2 = a["uv"]
	var ub: Vector2 = b["uv"]
	return {
		"position": (a["position"] as Vector3).lerp(b["position"], t),
		"normal": na.lerp(nb, t).normalized(),
		"uv": ua.lerp(ub, t),
	}


static func _clip(
	triangle: Array[Dictionary],
	origin: Vector3,
	normal: Vector3,
	keep_positive: bool,
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(3):
		var a: Dictionary = triangle[i]
		var b: Dictionary = triangle[(i + 1) % 3]
		var da: float = normal.dot((a["position"] as Vector3) - origin)
		var db: float = normal.dot((b["position"] as Vector3) - origin)
		var a_inside: bool = da > 0.0 if keep_positive else da < 0.0
		var b_inside: bool = db > 0.0 if keep_positive else db < 0.0
		if a_inside:
			result.append(a)
		if a_inside != b_inside:
			result.append(_interpolate(a, b, da / (da - db)))
	return result


static func _segment(
	triangle: Array[Dictionary],
	origin: Vector3,
	normal: Vector3,
) -> PackedVector3Array:
	var segment := PackedVector3Array()
	for i in range(3):
		var a: Vector3 = triangle[i]["position"]
		var b: Vector3 = triangle[(i + 1) % 3]["position"]
		var da: float = normal.dot(a - origin)
		var db: float = normal.dot(b - origin)
		if (da > 0.0) != (db > 0.0):
			segment.append(a.lerp(b, da / (da - db)))
	return segment


static func _add_polygon(output: Array[Dictionary], polygon: Array[Dictionary]) -> void:
	if polygon.size() < 3:
		return
	for i in range(1, polygon.size() - 1):
		output.append(polygon[0])
		output.append(polygon[i])
		output.append(polygon[i + 1])


static func _key(point: Vector3, epsilon: float) -> Vector3i:
	return Vector3i(
		roundi(point.x / epsilon),
		roundi(point.y / epsilon),
		roundi(point.z / epsilon),
	)


static func _single_ring(segments: Array[PackedVector3Array], epsilon: float) -> Array[Vector3]:
	var locations: Dictionary = {}
	var links: Dictionary = {}
	for segment in segments:
		var a: Vector3i = _key(segment[0], epsilon)
		var b: Vector3i = _key(segment[1], epsilon)
		if a == b:
			return []
		locations[a] = segment[0]
		locations[b] = segment[1]
		if not links.has(a):
			links[a] = []
		if not links.has(b):
			links[b] = []
		if links[a].has(b) or links[b].has(a):
			return []
		links[a].append(b)
		links[b].append(a)
	for point in links:
		if links[point].size() != 2:
			return []
	var start: Vector3i = links.keys()[0]
	var current: Vector3i = start
	var previous: Vector3i = start
	var visited: Dictionary = {}
	var ring: Array[Vector3] = []
	while not visited.has(current):
		visited[current] = true
		ring.append(locations[current])
		var neighbors: Array = links[current]
		var next: Vector3i = neighbors[0]
		if next == previous and current != start:
			next = neighbors[1]
		previous = current
		current = next
	if current != start or ring.size() != links.size():
		return []
	return ring


static func _cap_vertex(
	position: Vector3,
	normal: Vector3,
	origin: Vector3,
	axis_u: Vector3,
	axis_v: Vector3,
) -> Dictionary:
	return {
		"position": position,
		"normal": normal,
		"uv": Vector2(
			(position - origin).dot(axis_u),
			(position - origin).dot(axis_v),
		),
	}


static func _build_mesh(surfaces: Array[Dictionary]) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface in surfaces:
		var vertices: Array[Dictionary] = surface["vertices"]
		if vertices.is_empty():
			continue
		var positions := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		for vertex in vertices:
			positions.append(vertex["position"])
			normals.append(vertex["normal"])
			uvs.append(vertex["uv"])
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material: Material = surface["material"]
		if material != null:
			mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh
