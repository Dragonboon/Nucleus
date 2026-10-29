@tool
class_name NucleusSurfaceProvider3D
extends NucleusSurfaceSource3D
## Static 3D surface source backed by one NucleusSurfaceProfile.

@export var profile: NucleusSurfaceProfile:
	set(value):
		_disconnect_profile(profile)
		profile = value
		_connect_profile(profile)
		update_configuration_warnings()


func _ready() -> void:
	_connect_profile(profile)


func _exit_tree() -> void:
	_disconnect_profile(profile)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if profile == null:
		warnings.append("Assign a NucleusSurfaceProfile.")
		return warnings

	for error: String in profile.get_validation_errors():
		warnings.append("Surface profile: %s" % error)

	return warnings


func _resolve_surface(
	_query: NucleusSurfaceQuery3D,
) -> NucleusSurfaceProfile:
	return profile


func _connect_profile(resource: NucleusSurfaceProfile) -> void:
	if resource == null or resource.changed.is_connected(_on_profile_changed):
		return

	resource.changed.connect(_on_profile_changed)


func _disconnect_profile(resource: NucleusSurfaceProfile) -> void:
	if resource == null or not resource.changed.is_connected(_on_profile_changed):
		return

	resource.changed.disconnect(_on_profile_changed)


func _on_profile_changed() -> void:
	update_configuration_warnings()
