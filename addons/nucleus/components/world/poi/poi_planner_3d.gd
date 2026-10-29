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
	var region_end: Vector2 = minimum + size
	var grid_minimum: Vector2 = (minimum / recipe.grid_spacing).floor()
	var grid_end: Vector2 = (region_end / recipe.grid_spacing).ceil()
	# Vector2i has 32-bit components. Reserve room for the neighbor halo before casting.
	if (
		not region_end.is_finite()
		or grid_minimum.x < -2147483000.0 or grid_minimum.y < -2147483000.0
		or grid_end.x > 2147483000.0 or grid_end.y > 2147483000.0
	):
		return {"error": ERR_INVALID_PARAMETER, "points": []}
	var extent: Vector2 = grid_end - grid_minimum
	if (
		extent.x < 1.0 or extent.y < 1.0
		or extent.x > recipe.max_cells_per_region or extent.y > recipe.max_cells_per_region
		or extent.x * extent.y > recipe.max_cells_per_region
	):
		return {"error": ERR_OUT_OF_MEMORY, "points": []}
	var first := Vector2i(grid_minimum)
	var last := Vector2i(grid_end) - Vector2i.ONE
	var output: Array[Dictionary] = []
	# Cache eligible descriptors, including the halo: query each cell at most once.
	var candidates: Dictionary = {}
	for z in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, z)
			var point: Vector2 = _candidate(cell, recipe)
			if not Rect2(minimum, size).has_point(point):
				continue
			var own: Dictionary = _evaluate(cell, recipe, biomes, surface, candidates)
			if own["error"] != OK:
				return {"error": own["error"], "points": []}
			if not own.has("descriptor"):
				continue
			var priority: float = _hash(recipe.seed, x, z, 59)
			var suppressed: bool = false
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dz == 0:
						continue
					var other := Vector2i(x + dx, z + dz)
					if point.distance_to(_candidate(other, recipe)) >= recipe.minimum_separation:
						continue
					var competing: float = _hash(recipe.seed, other.x, other.y, 59)
					if competing < priority or (
						competing == priority and (
							other.y > z or (other.y == z and other.x > x)
						)
					):
						continue
					var rival: Dictionary = _evaluate(other, recipe, biomes, surface, candidates)
					if rival["error"] != OK:
						return {"error": rival["error"], "points": []}
					if rival.has("descriptor"):
						suppressed = true
						break
				if suppressed:
					break
			if suppressed:
				continue
			if output.size() >= recipe.max_results_per_region:
				return {"error": ERR_OUT_OF_MEMORY, "points": []}
			output.append(own["descriptor"])
	return {"error": OK, "points": output}


static func _evaluate(
	cell: Vector2i,
	recipe: NucleusPOIDistributionProfile3D,
	biomes: NucleusBiomeComposer3D,
	surface: Callable,
	cache: Dictionary,
) -> Dictionary:
	if cache.has(cell):
		return cache[cell]
	var result: Dictionary = {"error": OK}
	cache[cell] = result
	if _hash(recipe.seed, cell.x, cell.y, 43) >= recipe.density:
		return result
	var point: Vector2 = _candidate(cell, recipe)
	var sample: Variant = surface.call(point)
	if not sample is Dictionary:
		result["error"] = ERR_INVALID_DATA
		return result
	# A sampler may have holes or finite bounds; absence is not malformed data.
	if sample.is_empty():
		return result
	var raw_height: Variant = sample.get("height")
	var raw_slope: Variant = sample.get("slope")
	if (
		(not raw_height is float and not raw_height is int)
		or (not raw_slope is float and not raw_slope is int)
	):
		result["error"] = ERR_INVALID_DATA
		return result
	var height: float = float(raw_height)
	var slope: float = float(raw_slope)
	if not is_finite(height) or not is_finite(slope) or slope < 0.0 or slope > 90.0:
		result["error"] = ERR_INVALID_DATA
		return result
	var biome: Dictionary = biomes.resolve_at(point, height, slope)
	if biome.is_empty():
		return result
	var eligible: Array[NucleusPOIType3D] = []
	var largest_weight: float = 0.0
	for option: NucleusPOIType3D in recipe.types:
		if option.accepts(biome["biome_id"], height, slope):
			eligible.append(option)
			largest_weight = maxf(largest_weight, option.weight)
	if eligible.is_empty():
		return result
	# Normalization keeps a collection of individually finite weights finite.
	var weight_sum: float = 0.0
	for option: NucleusPOIType3D in eligible:
		weight_sum += option.weight / largest_weight
	var threshold: float = _hash(recipe.seed, cell.x, cell.y, 71) * weight_sum
	var chosen: NucleusPOIType3D = eligible.back()
	for option: NucleusPOIType3D in eligible:
		threshold -= option.weight / largest_weight
		if threshold < 0.0:
			chosen = option
			break
	result["descriptor"] = {
		"id": "%d:%d:%d" % [recipe.seed, cell.x, cell.y],
		"poi_id": chosen.poi_id,
		"biome_id": biome["biome_id"],
		"position": Vector3(point.x, height, point.y),
		"cell": cell,
	}
	return result
