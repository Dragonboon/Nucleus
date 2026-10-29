class_name NucleusMobileOrientationPolicy
extends Node
## Scene-owned mobile orientation policy over DisplayServer.

enum Mode {
	PROJECT_DEFAULT,
	LANDSCAPE,
	PORTRAIT,
	REVERSE_LANDSCAPE,
	REVERSE_PORTRAIT,
	SENSOR_LANDSCAPE,
	SENSOR_PORTRAIT,
	SENSOR,
}

@export var mode: Mode = Mode.PROJECT_DEFAULT
@export var restore_previous_on_exit: bool = true

var _previous_orientation: int = DisplayServer.SCREEN_LANDSCAPE
var _applied: bool = false


@warning_ignore("int_as_enum_without_cast")
func _ready() -> void:
	if not NucleusPlatform.supports_orientation():
		return

	_previous_orientation = DisplayServer.screen_get_orientation()

	if mode == Mode.PROJECT_DEFAULT:
		return

	DisplayServer.screen_set_orientation(
		_to_display_orientation(mode)
	)
	_applied = true


@warning_ignore("int_as_enum_without_cast")
func _exit_tree() -> void:
	if (
		restore_previous_on_exit
		and _applied
		and NucleusPlatform.supports_orientation()
	):
		DisplayServer.screen_set_orientation(_previous_orientation)


func _to_display_orientation(value: Mode) -> int:
	match value:
		Mode.LANDSCAPE:
			return DisplayServer.SCREEN_LANDSCAPE
		Mode.PORTRAIT:
			return DisplayServer.SCREEN_PORTRAIT
		Mode.REVERSE_LANDSCAPE:
			return DisplayServer.SCREEN_REVERSE_LANDSCAPE
		Mode.REVERSE_PORTRAIT:
			return DisplayServer.SCREEN_REVERSE_PORTRAIT
		Mode.SENSOR_LANDSCAPE:
			return DisplayServer.SCREEN_SENSOR_LANDSCAPE
		Mode.SENSOR_PORTRAIT:
			return DisplayServer.SCREEN_SENSOR_PORTRAIT
		Mode.SENSOR:
			return DisplayServer.SCREEN_SENSOR
		_:
			return DisplayServer.screen_get_orientation()
