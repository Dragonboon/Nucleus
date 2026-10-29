@tool
class_name NucleusSceneTransitionProfile
extends Resource
## Optional presentation policy for one NucleusSceneFlow transition.
##
## Scene Flow owns sequencing. This Resource only describes how the temporary
## screen-space transition overlay should cover and reveal the viewport.

enum Mode {
	FADE,
	CURTAIN,
	FLASH,
	SHADER,
}

enum CurtainAxis {
	HORIZONTAL,
	VERTICAL,
}

@export var mode: Mode = Mode.FADE
@export var color: Color = Color.BLACK
@export_range(0.0, 30.0, 0.01, "or_greater")
var cover_duration: float = 0.25
@export_range(0.0, 30.0, 0.01, "or_greater")
var reveal_duration: float = 0.25
@export_range(0.0, 30.0, 0.01, "or_greater")
var covered_hold_seconds: float = 0.0
@export_range(0.1, 120.0, 0.1, "or_greater")
var presentation_timeout_seconds: float = 8.0
@export var block_input: bool = true
@export_range(-128, 128, 1)
var canvas_layer: int = 96

@export_group("Curtain")
@export var curtain_axis: CurtainAxis = CurtainAxis.HORIZONTAL

@export_group("Shader")
@export var shader: Shader
@export var shader_progress_parameter: StringName = &"progress"
@export var shader_parameters: Dictionary = {}
@export var overlay_scene: PackedScene


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if cover_duration < 0.0:
		errors.append("cover_duration cannot be negative.")

	if reveal_duration < 0.0:
		errors.append("reveal_duration cannot be negative.")

	if covered_hold_seconds < 0.0:
		errors.append("covered_hold_seconds cannot be negative.")

	if presentation_timeout_seconds <= 0.0:
		errors.append("presentation_timeout_seconds must be greater than zero.")

	var minimum_timeout := maxf(
		cover_duration + covered_hold_seconds,
		reveal_duration,
	)
	if presentation_timeout_seconds <= minimum_timeout:
		errors.append(
			"presentation_timeout_seconds must exceed the longest visual phase."
		)

	if mode == Mode.SHADER and shader_progress_parameter == &"":
		errors.append("Shader transitions require shader_progress_parameter.")

	if overlay_scene != null and not overlay_scene.can_instantiate():
		errors.append("overlay_scene cannot be instantiated.")

	return errors


static func fade(
	p_color: Color = Color.BLACK,
	duration: float = 0.25,
) -> NucleusSceneTransitionProfile:
	var profile := NucleusSceneTransitionProfile.new()
	profile.mode = Mode.FADE
	profile.color = p_color
	profile.cover_duration = duration
	profile.reveal_duration = duration
	return profile


static func curtain(
	p_color: Color = Color.BLACK,
	duration: float = 0.35,
	axis: CurtainAxis = CurtainAxis.HORIZONTAL,
) -> NucleusSceneTransitionProfile:
	var profile := NucleusSceneTransitionProfile.new()
	profile.mode = Mode.CURTAIN
	profile.color = p_color
	profile.cover_duration = duration
	profile.reveal_duration = duration
	profile.curtain_axis = axis
	return profile


static func flash(
	p_color: Color = Color.WHITE,
	cover_time: float = 0.06,
	reveal_time: float = 0.18,
) -> NucleusSceneTransitionProfile:
	var profile := NucleusSceneTransitionProfile.new()
	profile.mode = Mode.FLASH
	profile.color = p_color
	profile.cover_duration = cover_time
	profile.reveal_duration = reveal_time
	return profile


static func tiled(
	p_color: Color = Color.BLACK,
	duration: float = 0.4,
) -> NucleusSceneTransitionProfile:
	var profile := NucleusSceneTransitionProfile.new()
	profile.mode = Mode.SHADER
	profile.color = p_color
	profile.cover_duration = duration
	profile.reveal_duration = duration
	profile.shader_parameters = {
		&"tile_count": Vector2(18.0, 10.0),
		&"softness": 0.08,
		&"seed": 1.0,
	}
	return profile
