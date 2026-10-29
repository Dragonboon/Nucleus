@tool
class_name NucleusBiomeComposer3D
extends Resource
## Stateless biome lookup in world X/Z; no terrain or scatter generation.
## Authored FastNoiseLite seeds own climate determinism.

const MAX_BIOMES: int = 32

@export var temperature_noise: FastNoiseLite
@export var moisture_noise: FastNoiseLite
@export_range(0.0, 1.0, 0.01) var base_temperature: float = 0.5
@export_range(0.0, 1.0, 0.01) var base_moisture: float = 0.5
@export_range(0.0, 1.0, 0.01) var temperature_amplitude: float = 0.5
@export_range(0.0, 1.0, 0.01) var moisture_amplitude: float = 0.5
@export var biomes: Array[NucleusBiomeProfile3D] = []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if biomes.is_empty() or biomes.size() > MAX_BIOMES:
		errors.append("Provide between 1 and 32 biome profiles.")
	var identities: Dictionary = {}
	for i in range(biomes.size()):
		var biome: NucleusBiomeProfile3D = biomes[i]
		if biome == null:
			errors.append("biomes[%d] is null." % i)
			continue
		for issue: String in biome.validate():
			errors.append("biomes[%d]: %s" % [i, issue])
		if identities.has(biome.biome_id):
			errors.append("Duplicate biome_id '%s'." % biome.biome_id)
		identities[biome.biome_id] = true
	for value: float in [
		base_temperature, base_moisture,
		temperature_amplitude, moisture_amplitude,
	]:
		if not is_finite(value) or value < 0.0 or value > 1.0:
			errors.append("Climate base and amplitude must be in [0, 1].")
			break
	return errors


## Values are supplied explicitly so games can compose their own climate fields.
## Highest priority wins; ties preserve authoring order. No match is explicit.
func resolve_values(
	temperature: float,
	moisture: float,
	height: float,
	slope_degrees: float,
) -> Dictionary:
	if not _finite_fields(temperature, moisture, height, slope_degrees):
		return {}
	var selected: NucleusBiomeProfile3D
	for biome: NucleusBiomeProfile3D in biomes:
		if biome == null or not biome.accepts(
			temperature, moisture, height, slope_degrees
		):
			continue
		if selected == null or biome.priority > selected.priority:
			selected = biome
	if selected == null:
		return {}
	return {
		"biome_id": selected.biome_id,
		"profile": selected,
		"temperature": temperature,
		"moisture": moisture,
	}


## Optional noise maps sample globally, independently of region traversal.
func resolve_at(
	world_xz: Vector2,
	height: float,
	slope_degrees: float,
) -> Dictionary:
	if not world_xz.is_finite():
		return {}
	var temperature: float = base_temperature
	var moisture: float = base_moisture
	if temperature_noise != null:
		temperature += temperature_noise.get_noise_2d(
			world_xz.x, world_xz.y
		) * temperature_amplitude
	if moisture_noise != null:
		moisture += moisture_noise.get_noise_2d(
			world_xz.x, world_xz.y
		) * moisture_amplitude
	return resolve_values(
		clampf(temperature, 0.0, 1.0),
		clampf(moisture, 0.0, 1.0),
		height, slope_degrees
	)


static func _finite_fields(
	temperature: float, moisture: float, height: float, slope: float,
) -> bool:
	return (
		is_finite(temperature) and is_finite(moisture)
		and is_finite(height) and is_finite(slope)
		and temperature >= 0.0 and temperature <= 1.0
		and moisture >= 0.0 and moisture <= 1.0
		and slope >= 0.0 and slope <= 90.0
	)
