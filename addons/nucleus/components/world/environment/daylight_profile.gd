@tool
class_name NucleusDaylightProfile
extends Resource
## Rendering policy sampled by NucleusDaylightDriver3D.
##
## Optional curves are normalized 0..1 response curves over one 24-hour day.
## When a celestial state is supplied, analytical fallbacks use its actual
## sun/moon elevation factors instead of assuming presentation state from time.

@export_group("Sun")
@export_range(0.0, 16.0, 0.01, "or_greater")
var sun_energy_max: float = 1.0
@export var sun_energy_curve: Curve
@export var sun_color_gradient: Gradient
## Legacy direct-clock orbit settings. A NucleusCelestialDriver3D source owns
## celestial rotation when the daylight driver is wired through celestial state.
@export var sun_rotation_offset_degrees: float = 90.0
@export var sun_yaw_degrees: float = -30.0
@export var sun_roll_degrees: float = 0.0
@export var manage_sun_shadows: bool = true
@export_range(0.0, 16.0, 0.001, "or_greater")
var sun_shadow_energy_threshold: float = 0.01

@export_group("Moon")
@export_range(0.0, 16.0, 0.01, "or_greater")
var moon_energy_max: float = 0.12
@export var moon_energy_curve: Curve
@export var moon_color_gradient: Gradient
## Legacy direct-clock orbit settings. A NucleusCelestialDriver3D source owns
## celestial rotation when the daylight driver is wired through celestial state.
@export var moon_rotation_offset_degrees: float = 270.0
@export var moon_yaw_degrees: float = -30.0
@export var moon_roll_degrees: float = 0.0
@export var manage_moon_shadows: bool = true
@export_range(0.0, 16.0, 0.001, "or_greater")
var moon_shadow_energy_threshold: float = 0.01

@export_group("Environment")
@export_range(0.0, 16.0, 0.01, "or_greater")
var night_background_energy: float = 0.2
@export_range(0.0, 16.0, 0.01, "or_greater")
var day_background_energy: float = 1.0
@export var background_energy_curve: Curve
@export_range(0.0, 16.0, 0.01, "or_greater")
var night_ambient_energy: float = 0.25
@export_range(0.0, 16.0, 0.01, "or_greater")
var day_ambient_energy: float = 1.0
@export var ambient_energy_curve: Curve


func sample_sun_energy(normalized_time: float) -> float:
	var factor: float = _sample_factor(
		sun_energy_curve,
		normalized_time,
		_daylight_factor(normalized_time),
	)
	return factor * sun_energy_max


func sample_moon_energy(normalized_time: float) -> float:
	var factor: float = _sample_factor(
		moon_energy_curve,
		normalized_time,
		_night_factor(normalized_time),
	)
	return factor * moon_energy_max


func sample_sun_energy_for_state(
	state: NucleusCelestialState3D,
) -> float:
	if state == null:
		return 0.0

	var factor: float = _sample_factor(
		sun_energy_curve,
		state.normalized_day_time,
		state.daylight_factor,
	)
	return factor * sun_energy_max


func sample_moon_energy_for_state(
	state: NucleusCelestialState3D,
) -> float:
	if state == null:
		return 0.0

	var factor: float = _sample_factor(
		moon_energy_curve,
		state.normalized_day_time,
		state.night_factor,
	)
	return factor * moon_energy_max


func sample_sun_color(normalized_time: float) -> Color:
	if sun_color_gradient == null:
		return Color.WHITE

	return sun_color_gradient.sample(
		_normalize_time(normalized_time)
	)


func sample_moon_color(normalized_time: float) -> Color:
	if moon_color_gradient == null:
		return Color.WHITE

	return moon_color_gradient.sample(
		_normalize_time(normalized_time)
	)


func sample_background_energy(normalized_time: float) -> float:
	var factor: float = _sample_factor(
		background_energy_curve,
		normalized_time,
		_daylight_factor(normalized_time),
	)
	return lerpf(
		night_background_energy,
		day_background_energy,
		factor,
	)


func sample_ambient_energy(normalized_time: float) -> float:
	var factor: float = _sample_factor(
		ambient_energy_curve,
		normalized_time,
		_daylight_factor(normalized_time),
	)
	return lerpf(
		night_ambient_energy,
		day_ambient_energy,
		factor,
	)


func sample_background_energy_for_state(
	state: NucleusCelestialState3D,
) -> float:
	if state == null:
		return night_background_energy

	var factor: float = _sample_factor(
		background_energy_curve,
		state.normalized_day_time,
		state.daylight_factor,
	)
	return lerpf(
		night_background_energy,
		day_background_energy,
		factor,
	)


func sample_ambient_energy_for_state(
	state: NucleusCelestialState3D,
) -> float:
	if state == null:
		return night_ambient_energy

	var factor: float = _sample_factor(
		ambient_energy_curve,
		state.normalized_day_time,
		state.daylight_factor,
	)
	return lerpf(
		night_ambient_energy,
		day_ambient_energy,
		factor,
	)


func _sample_factor(
	curve: Curve,
	normalized_time: float,
	fallback: float,
) -> float:
	if curve == null:
		return clampf(fallback, 0.0, 1.0)

	return clampf(
		curve.sample_baked(_normalize_time(normalized_time)),
		0.0,
		1.0,
	)


func _daylight_factor(normalized_time: float) -> float:
	var phase: float = TAU * _normalize_time(normalized_time)
	return maxf(0.0, -cos(phase))


func _night_factor(normalized_time: float) -> float:
	var phase: float = TAU * _normalize_time(normalized_time)
	return maxf(0.0, cos(phase))


func _normalize_time(value: float) -> float:
	return fposmod(value, 1.0)
