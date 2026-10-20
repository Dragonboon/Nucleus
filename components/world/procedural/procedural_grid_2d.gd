class_name NucleusProceduralGrid2D
extends RefCounted
## Seed-stable cell data; TileMapLayer and stream lifecycle remain independent.

const MAX_REGION_CELLS: int = 65536

var seed: int = 1
var region_size: Vector2i = Vector2i(16, 16)
var noise: FastNoiseLite
var threshold: float = 0.0


func generate(region: Vector2i) -> PackedByteArray:
	if region_size.x <= 0 or region_size.y <= 0:
		return PackedByteArray()
	var count := region_size.x * region_size.y
	if count > MAX_REGION_CELLS:
		return PackedByteArray()
	var result := PackedByteArray()
	result.resize(count)
	for y in range(region_size.y):
		for x in range(region_size.x):
			var gx := region.x * region_size.x + x
			var gy := region.y * region_size.y + y
			var value: float
			if noise != null:
				# Callers should provide a configured immutable FastNoiseLite resource.
				value = noise.get_noise_2d(float(gx), float(gy))
			else:
				value = _hash_noise(gx, gy)
			result[y * region_size.x + x] = 1 if value >= threshold else 0
	return result


func region_for_cell(cell: Vector2i) -> Vector2i:
	if region_size.x <= 0 or region_size.y <= 0:
		return Vector2i.ZERO
	return Vector2i(
		floori(float(cell.x) / float(region_size.x)),
		floori(float(cell.y) / float(region_size.y)),
	)


func _hash_noise(x: int, y: int) -> float:
	# Deterministic fallback, including negative coordinates.
	var value := (x * 73856093) ^ (y * 19349663) ^ seed
	value = (value ^ (value >> 16)) * 2246822519
	value = (value ^ (value >> 13)) * 3266489917
	value = value ^ (value >> 16)
	return float(value & 65535) / 32767.5 - 1.0
