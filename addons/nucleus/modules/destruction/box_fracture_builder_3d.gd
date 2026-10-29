class_name NucleusBoxFractureBuilder3D
extends RefCounted
## Real block meshes and collision proxies, NOT arbitrary mesh slicing.


static func build(size: Vector3, counts: Vector3i) -> NucleusFracturePattern3D:
	var result := NucleusFracturePattern3D.new()
	if not size.is_finite() or size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return result
	if counts.x <= 0 or counts.y <= 0 or counts.z <= 0:
		return result
	if counts.x > 16 or counts.y > 16 or counts.z > 16:
		return result
	if counts.x * counts.y * counts.z > 128:
		return result
	var step := Vector3(
		size.x / float(counts.x), size.y / float(counts.y), size.z / float(counts.z)
	)
	for z in range(counts.z):
		for y in range(counts.y):
			for x in range(counts.x):
				var shard := NucleusFractureShard3D.new()
				var geometry := BoxMesh.new()
				geometry.size = step
				var shape := BoxShape3D.new()
				shape.size = step
				shard.mesh = geometry
				shard.collision_shape = shape
				shard.local_transform = Transform3D(Basis.IDENTITY, Vector3(
					step.x * (float(x) + 0.5) - size.x * 0.5,
					step.y * (float(y) + 0.5) - size.y * 0.5,
					step.z * (float(z) + 0.5) - size.z * 0.5
				))
				result.shards.append(shard)
	return result
