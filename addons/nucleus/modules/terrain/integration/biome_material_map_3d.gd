class_name NucleusBiomeMaterialMap3D
extends RefCounted
## Bounded, explicit CPU bake of biome base colors in world X/Z.
## Uses existing biome terrain_material references; never changes shared materials.
## Rebuild after climate/terrain changes. Texture detail and gameplay remain caller-owned.

const MAX_RESOLUTION: int = 256


static func build(
	query: NucleusBiomeSurfaceQuery3D,
	minimum: Vector2,
	size: Vector2,
	resolution: int = 64,
	fallback: Color = Color(0.35, 0.4, 0.25),
) -> Dictionary:
	if (
		query == null or query.biomes == null or not query.biomes.validate().is_empty()
		or not is_instance_valid(query.surface) or not query.surface.is_inside_tree()
		or not minimum.is_finite() or not size.is_finite()
		or size.x <= 0.0 or size.y <= 0.0
		or resolution < 2 or resolution > MAX_RESOLUTION
	):
		return {"error": ERR_INVALID_PARAMETER}
	var image := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	for z in range(resolution):
		for x in range(resolution):
			var uv := Vector2(x + 0.5, z + 0.5) / float(resolution)
			var sample: Dictionary = query.sample_biome(minimum + uv * size)
			var color: Color = fallback
			var biome: NucleusBiomeProfile3D = sample.get("profile")
			if biome != null and biome.terrain_material != null:
				color = biome.terrain_material.base_color
			image.set_pixel(x, z, color)
	return {"error": OK, "texture": ImageTexture.create_from_image(image)}
