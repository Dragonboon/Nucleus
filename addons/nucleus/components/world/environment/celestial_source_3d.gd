class_name NucleusCelestialSource3D
extends Resource
## Base resource for deriving celestial state from normalized simulation time.
##
## Custom games may subclass this resource for fictional or astronomical paths.
## Nucleus does not require a calendar, latitude, longitude, or Earth-specific
## orbital model.

func sample_state(
	_normalized_day_time: float,
	_target: NucleusCelestialState3D,
) -> Error:
	return ERR_UNAVAILABLE


func get_validation_errors() -> PackedStringArray:
	return PackedStringArray()
