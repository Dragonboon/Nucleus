class_name NucleusPOIPlanner3D
extends RefCounted
## Deterministic world-cell landmarks; no instantiation, physics or world state.
## A one-cell halo handles competing candidates across region boundaries.

const MASK: int = 0x7fffffff


static func _hash(seed: int, x: int, z: int, salt: int) -> float:
	var v: int = (seed * 1013904223 + x * 374761393 + z * 668265263 + salt) & MASK
	v = ((v ^ (v >> 13)) * 1274126177) & MASK
	v = (v ^ (v >> 16)) & MASK
	return float(v) / float(MASK)


static func _candidate(cell: Vector2i, recipe: NucleusPOIDistributionProfile3D) -> Vector2:
	var spacing: float = recipe.grid_spacing
	var jittered := Vector2(
		_hash(recipe.seed, cell.x, cell.y, 17) - 0.5,
		_hash(recipe.seed, cell.x, cell.y, 31) - 0.5
	) * spacing * recipe.jitter
	return (Vector2(cell) + Vector2(0.5, 0.5)) * spacing + jittered


## surface: Callable(world XZ: Vector2) -> Dictionary
## Must return {height: float, slope: float}; not a scene-owned mutation.
static func plan(
	minimum: Vector2,
	size: Vector2,
	recipe: NucleusPOIDistributionProfile3D,
	biomes: NucleusBiomeComposer3D,
	surface: Callable,
) -> Dictionary:
	if (
		recipe == null or not recipe.validate().is_empty()
		or biomes == null or not biomes.validate().is_empty()
		or not minimum.is_finite() or not size.is_finite()
		or size.x <= 0.0 or size.y <= 0.0
		or not surface.is_valid()
	):
		return {"error": ERR_INVALID_PARAMETER, "points": []}
	var first := Vector2i(
		floori(minimum.x / recipe.grid_spacing),
		floori(minimum.y / recipe.grid_spacing)
	)
	var last := Vector2i(
		ceili((minimum.x + size.x) / recipe.grid_spacing) - 1,
		ceili((minimum.y + size.y) / recipe.grid_spacing) - 1
	)
	var count: int = (last.x - first.x + 1) * (last.y - first.y + 1)
	if count > recipe.max_cells_per_region or count < 1:
		return {"error": ERR_OUT_OF_MEMORY, "points": []}
	var output: Array[Dictionary] = []
	for z in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, z)
			var point: Vector2 = _candidate(cell, recipe)
			if (
				point.x < minimum.x or point.y < minimum.y
				or point.x >= minimum.x + size.x
				or point.y >= minimum.y + size.y
				or _hash(recipe.seed, x, z, 43) >= recipe.density
			):
				continue
			var priority: float = _hash(recipe.seed, x, z, 59)
			var suppressed: bool = false
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dz == 0:
						continue
					var other := Vector2i(x + dx, z + dz)
					if _hash(recipe.seed, other.x, other.y, 43) >= recipe.density:
						continue
					if point.distance_to(_candidate(other, recipe)) >= recipe.minimum_separation:
						continue
					var competing: float = _hash(recipe.seed, other.x, other.y, 59)
					if competing > priority or (
						competing == priority and (
							other.y < z or (other.y == z and other.x < x)
						)
					):
						suppressed = true
						break
				if suppressed:
					break
			if suppressed:
				continue
			var sample: Variant = surface.call(point)
			if not sample is Dictionary:
				return {"error": ERR_INVALID_DATA, "points": []}
			var height: float = float(sample.get("height", NAN))
			var slope: float = float(sample.get("slope", NAN))
			if not is_finite(height) or not is_finite(slope):
				return {"error": ERR_INVALID_DATA, "points": []}
			var biome: Dictionary = biomes.resolve_at(point, height, slope)
			if biome.is_empty():
				continue
			var eligible: Array[NucleusPOIType3D] = []
			var weight_sum: float = 0.0
			for type_profile: NucleusPOIType3D in recipe.types:
				if type_profile.accepts(biome["biome_id"], height, slope):
					eligible.append(type_profile)
					weight_sum += type_profile.weight
			if eligible.is_empty():
				continue
			var threshold: float = _hash(recipe.seed, x, z, 71) * weight_sum
			var chosen: NucleusPOIType3D = eligible[eligible.size() - 1]
			for option: NucleusPOIType3D in eligible:
				threshold -= option.weight
				if threshold < 0.0:
					chosen = option
					break
			if output.size() >= recipe.max_results_per_region:
				return {"error": ERR_OUT_OF_MEMORY, "points": []}
			output.append({
				"id": "%d:%d:%d" % [recipe.seed, x, z],
				"poi_id": chosen.poi_id,
				"biome_id": biome["biome_id"],
				"position": Vector3(point.x, height, point.y),
				"cell": cell,
			})
	return {"error": OK, "points": output}
