@tool
class_name NucleusPOIDistributionProfile3D
extends Resource
## Region-independent coarse global lattice of optional world landmarks.

const MAX_TYPES: int = 32
const MAX_CELLS: int = 4096

@export var seed: int = 1337
@export_range(1.0, 1024.0, 1.0) var grid_spacing: float = 24.0
@export_range(0.0, 1.0, 0.01) var density: float = 0.4
@export_range(0.0, 1.0, 0.01) var jitter: float = 0.75
@export_range(0.0, 2048.0, 1.0) var minimum_separation: float = 18.0
@export_range(1, 4096, 1) var max_cells_per_region: int = 1024
@export_range(1, 1024, 1) var max_results_per_region: int = 128
@export var types: Array[NucleusPOIType3D] = []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(grid_spacing) or grid_spacing < 1.0:
		errors.append("POI grid_spacing must be at least 1.")
	if not is_finite(density) or density < 0.0 or density > 1.0:
		errors.append("POI density must be within [0, 1].")
	if not is_finite(jitter) or jitter < 0.0 or jitter > 1.0:
		errors.append("POI jitter must be within [0, 1].")
	if (
		not is_finite(minimum_separation) or minimum_separation < 0.0
		or minimum_separation > grid_spacing
	):
		errors.append("POI separation must be within [0, grid_spacing].")
	if max_cells_per_region < 1 or max_cells_per_region > MAX_CELLS:
		errors.append("POI cell budget is out of bounds.")
	if max_results_per_region < 1 or max_results_per_region > 1024:
		errors.append("POI result budget is out of bounds.")
	if types.is_empty() or types.size() > MAX_TYPES:
		errors.append("Provide between 1 and 32 POI types.")
	var identities: Dictionary = {}
	for i in range(types.size()):
		var poi: NucleusPOIType3D = types[i]
		if poi == null:
			errors.append("types[%d] is null." % i)
			continue
		for issue: String in poi.validate():
			errors.append("types[%d]: %s" % [i, issue])
		if identities.has(poi.poi_id):
			errors.append("Duplicate POI ID '%s'." % poi.poi_id)
		identities[poi.poi_id] = true
	return errors
