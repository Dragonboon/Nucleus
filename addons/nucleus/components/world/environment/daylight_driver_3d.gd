@tool
class_name NucleusDaylightDriver3D
extends Node
## Applies a NucleusDaylightProfile to native Godot lighting/environment nodes.
##
## The preferred path consumes NucleusCelestialDriver3D state. Direct clock
## wiring remains supported for compatibility with existing scenes.
##
## The driver is presentation-only. It does not own time, weather, sky shaders,
## calendars, astronomy, or gameplay rules.

@export var celestial_driver: NucleusCelestialDriver3D:
	set(value):
		if celestial_driver == value:
			return

		_disconnect_sources()
		celestial_driver = value
		update_configuration_warnings()
		_connect_sources()
		_apply_if_runtime()

@export var clock: NucleusWorldClock:
	set(value):
		if clock == value:
			return

		_disconnect_sources()
		clock = value
		update_configuration_warnings()
		_connect_sources()
		_apply_if_runtime()

@export var profile: NucleusDaylightProfile:
	set(value):
		profile = value
		update_configuration_warnings()
		_apply_if_runtime()

@export_group("Targets")
@export var sun: DirectionalLight3D:
	set(value):
		sun = value
		update_configuration_warnings()
		_apply_if_runtime()

@export var moon: DirectionalLight3D:
	set(value):
		moon = value
		update_configuration_warnings()
		_apply_if_runtime()

@export var world_environment: WorldEnvironment:
	set(value):
		world_environment = value
		update_configuration_warnings()
		_apply_if_runtime()

@export_group("Runtime")
@export var enabled: bool = true:
	set(value):
		enabled = value
		_apply_if_runtime()


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if celestial_driver == null and clock == null:
		clock = get_parent() as NucleusWorldClock

	_connect_sources()
	apply_now()


func _exit_tree() -> void:
	_disconnect_sources()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	var parent_clock: NucleusWorldClock = get_parent() as NucleusWorldClock

	if (
		celestial_driver == null
		and clock == null
		and parent_clock == null
	):
		warnings.append(
			"Assign celestial_driver/clock or parent under NucleusWorldClock."
		)

	if profile == null:
		warnings.append("Assign a NucleusDaylightProfile.")

	if sun == null and moon == null and world_environment == null:
		warnings.append(
			"Assign at least one sun, moon, or WorldEnvironment target."
		)

	if (
		world_environment != null
		and world_environment.environment == null
	):
		warnings.append(
			"WorldEnvironment has no Environment resource assigned."
		)

	return warnings


func set_enabled(value: bool) -> void:
	enabled = value

	if enabled:
		apply_now()


func apply_now() -> Error:
	if not enabled:
		return OK

	if profile == null:
		return ERR_UNCONFIGURED

	if sun == null and moon == null and world_environment == null:
		return ERR_UNCONFIGURED

	if celestial_driver != null:
		if not celestial_driver.has_state():
			var refresh_error: Error = (
				celestial_driver.refresh_now()
			)

			if refresh_error != OK:
				return refresh_error

		return apply_state(celestial_driver.get_state())

	if clock == null:
		return ERR_UNCONFIGURED

	var normalized_time: float = clock.get_normalized_day_time()

	_apply_legacy_sun(normalized_time)
	_apply_legacy_moon(normalized_time)
	_apply_legacy_environment(normalized_time)
	return OK


func apply_state(state: NucleusCelestialState3D) -> Error:
	if not enabled:
		return OK

	if state == null or profile == null:
		return ERR_INVALID_PARAMETER

	_apply_celestial_sun(state)
	_apply_celestial_moon(state)
	_apply_celestial_environment(state)
	return OK


func _apply_celestial_sun(
	state: NucleusCelestialState3D,
) -> void:
	if sun == null:
		return

	var energy: float = profile.sample_sun_energy_for_state(state)
	sun.rotation_degrees = state.sun_rotation_degrees
	sun.light_energy = energy
	sun.light_color = profile.sample_sun_color(
		state.normalized_day_time
	)

	if profile.manage_sun_shadows:
		sun.shadow_enabled = (
			energy > profile.sun_shadow_energy_threshold
		)


func _apply_celestial_moon(
	state: NucleusCelestialState3D,
) -> void:
	if moon == null:
		return

	var energy: float = profile.sample_moon_energy_for_state(state)
	moon.rotation_degrees = state.moon_rotation_degrees
	moon.light_energy = energy
	moon.light_color = profile.sample_moon_color(
		state.normalized_day_time
	)

	if profile.manage_moon_shadows:
		moon.shadow_enabled = (
			energy > profile.moon_shadow_energy_threshold
		)


func _apply_celestial_environment(
	state: NucleusCelestialState3D,
) -> void:
	if world_environment == null:
		return

	var environment: Environment = world_environment.environment
	if environment == null:
		return

	environment.background_energy_multiplier = (
		profile.sample_background_energy_for_state(state)
	)
	environment.ambient_light_energy = (
		profile.sample_ambient_energy_for_state(state)
	)


func _apply_legacy_sun(normalized_time: float) -> void:
	if sun == null:
		return

	var energy: float = profile.sample_sun_energy(normalized_time)
	sun.rotation_degrees = Vector3(
		profile.sun_rotation_offset_degrees
			+ normalized_time * 360.0,
		profile.sun_yaw_degrees,
		profile.sun_roll_degrees,
	)
	sun.light_energy = energy
	sun.light_color = profile.sample_sun_color(normalized_time)

	if profile.manage_sun_shadows:
		sun.shadow_enabled = (
			energy > profile.sun_shadow_energy_threshold
		)


func _apply_legacy_moon(normalized_time: float) -> void:
	if moon == null:
		return

	var energy: float = profile.sample_moon_energy(normalized_time)
	moon.rotation_degrees = Vector3(
		profile.moon_rotation_offset_degrees
			+ normalized_time * 360.0,
		profile.moon_yaw_degrees,
		profile.moon_roll_degrees,
	)
	moon.light_energy = energy
	moon.light_color = profile.sample_moon_color(normalized_time)

	if profile.manage_moon_shadows:
		moon.shadow_enabled = (
			energy > profile.moon_shadow_energy_threshold
		)


func _apply_legacy_environment(normalized_time: float) -> void:
	if world_environment == null:
		return

	var environment: Environment = world_environment.environment
	if environment == null:
		return

	environment.background_energy_multiplier = (
		profile.sample_background_energy(normalized_time)
	)
	environment.ambient_light_energy = (
		profile.sample_ambient_energy(normalized_time)
	)


func _apply_if_runtime() -> void:
	if not is_inside_tree() or Engine.is_editor_hint():
		return

	if enabled:
		apply_now()


func _connect_sources() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return

	if celestial_driver != null:
		if not celestial_driver.state_changed.is_connected(
			_on_celestial_state_changed
		):
			celestial_driver.state_changed.connect(
				_on_celestial_state_changed
			)
		return

	if clock == null:
		return

	if not clock.time_changed.is_connected(_on_clock_time_changed):
		clock.time_changed.connect(_on_clock_time_changed)


func _disconnect_sources() -> void:
	if celestial_driver != null:
		if celestial_driver.state_changed.is_connected(
			_on_celestial_state_changed
		):
			celestial_driver.state_changed.disconnect(
				_on_celestial_state_changed
			)

	if clock != null:
		if clock.time_changed.is_connected(_on_clock_time_changed):
			clock.time_changed.disconnect(_on_clock_time_changed)


func _on_celestial_state_changed(
	state: NucleusCelestialState3D,
) -> void:
	apply_state(state)


func _on_clock_time_changed(
	_previous_total_seconds: float,
	_total_seconds: float,
) -> void:
	apply_now()
