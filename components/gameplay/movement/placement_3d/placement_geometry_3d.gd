class_name NucleusPlacementGeometry3D
extends RefCounted
## Visual-only bounds in the placeable root's local coordinates.
## The caller caches the result; no mesh traversal occurs per placement tick.
## Mesh AABBs approximate complex geometry: decorative overhangs count.


static func get_visual_bounds(root: Node3D) -> Dictionary:
	if root == null:
		return {"valid": false}
	var corners: Array[Vector3] = []
	_collect(root, Transform3D.IDENTITY, corners)
	if corners.is_empty():
		return {"valid": false}
	var minimum: Vector3 = corners[0]
	var maximum: Vector3 = corners[0]
	for point: Vector3 in corners:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	if not _finite(minimum) or not _finite(maximum):
		return {"valid": false}
	if (maximum - minimum).length_squared() <= 0.00000001:
		return {"valid": false}
	return {"valid": true, "bounds": AABB(minimum, maximum - minimum)}


## Returns the world-space correction that places the lowest visual point
## onto the plane at the root origin, measured along the support normal.
static func bottom_correction(bounds: AABB, basis: Basis, support_normal: Vector3) -> Vector3:
	if not _finite(support_normal) or support_normal.is_zero_approx():
		return Vector3.ZERO
	var up: Vector3 = support_normal.normalized()
	var minimum: float = INF
	for x: float in [bounds.position.x, bounds.end.x]:
		for y: float in [bounds.position.y, bounds.end.y]:
			for z: float in [bounds.position.z, bounds.end.z]:
				minimum = minf(minimum, (basis * Vector3(x, y, z)).dot(up))
	return up * -minimum if is_finite(minimum) else Vector3.ZERO


static func _collect(node: Node, transform: Transform3D, out: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			var bounds := instance.mesh.get_aabb()
			for x: float in [bounds.position.x, bounds.end.x]:
				for y: float in [bounds.position.y, bounds.end.y]:
					for z: float in [bounds.position.z, bounds.end.z]:
						out.append(transform * Vector3(x, y, z))
	for child: Node in node.get_children():
		if child is Node3D:
			_collect(child, transform * (child as Node3D).transform, out)
		else:
			_collect(child, transform, out)


static func _finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
