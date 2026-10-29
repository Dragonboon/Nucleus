class_name NucleusBiomeSurfaceQuery3D
extends RefCounted
## Read-only bridge from Nucleus surfaces to biome/POI/scatter contracts.
## Callbacks are synchronous and belong on the main thread.

var surface: NucleusSurfaceSampler3D
var biomes: NucleusBiomeComposer3D
var _scratch := NucleusSurfaceSample3D.new()


func _init(
	surface_sampler: NucleusSurfaceSampler3D = null,
	biome_composer: NucleusBiomeComposer3D = null,
) -> void:
	surface = surface_sampler
	biomes = biome_composer


## POIPlanner3D surface contract: {"height": float, "slope": degrees}.
func sample_poi(world_xz: Vector2) -> Dictionary:
	if (
		not world_xz.is_finite() or not is_instance_valid(surface)
		or not surface.is_inside_tree()
	):
		return {}
	if not surface.sample_into(
		Vector3(world_xz.x, 0.0, world_xz.y), _scratch
	):
		return {}
	var slope: float = rad_to_deg(acos(clampf(
		_scratch.normal.dot(Vector3.UP), -1.0, 1.0
	)))
	return {"height": _scratch.position.y, "slope": slope}


func sample_biome(world_xz: Vector2) -> Dictionary:
	if biomes == null:
		return {}
	var info: Dictionary = sample_poi(world_xz)
	if info.is_empty():
		return {}
	return biomes.resolve_at(world_xz, info["height"], info["slope"])


## Returns 0 or 1; a stable authored biome_id maps to scatter acceptance.
func density_for_biome(world_xz: Vector2, biome_id: StringName) -> float:
	if biome_id == &"":
		return 0.0
	var match_info: Dictionary = sample_biome(world_xz)
	return 1.0 if match_info.get("biome_id", &"") == biome_id else 0.0
