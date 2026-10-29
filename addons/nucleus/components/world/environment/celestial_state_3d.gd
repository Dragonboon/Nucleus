class_name NucleusCelestialState3D
extends RefCounted
## Reusable derived celestial presentation state.
##
## The state contains no calendar, astronomy, rendering nodes, or game rules.
## Sources update one instance in place so consumers can avoid per-tick payload
## allocations.

var normalized_day_time: float = 0.0

var sun_rotation_degrees: Vector3 = Vector3.ZERO
var moon_rotation_degrees: Vector3 = Vector3.ZERO

var sun_direction: Vector3 = Vector3.DOWN
var moon_direction: Vector3 = Vector3.UP

var sun_elevation_radians: float = -PI * 0.5
var moon_elevation_radians: float = PI * 0.5
var sun_azimuth_radians: float = 0.0
var moon_azimuth_radians: float = PI

var daylight_factor: float = 0.0
var night_factor: float = 1.0
var sun_above_horizon: bool = false
var moon_above_horizon: bool = true


func copy_from(other: NucleusCelestialState3D) -> void:
	if other == null:
		return

	normalized_day_time = other.normalized_day_time
	sun_rotation_degrees = other.sun_rotation_degrees
	moon_rotation_degrees = other.moon_rotation_degrees
	sun_direction = other.sun_direction
	moon_direction = other.moon_direction
	sun_elevation_radians = other.sun_elevation_radians
	moon_elevation_radians = other.moon_elevation_radians
	sun_azimuth_radians = other.sun_azimuth_radians
	moon_azimuth_radians = other.moon_azimuth_radians
	daylight_factor = other.daylight_factor
	night_factor = other.night_factor
	sun_above_horizon = other.sun_above_horizon
	moon_above_horizon = other.moon_above_horizon
