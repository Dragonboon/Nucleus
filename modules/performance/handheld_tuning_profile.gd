@tool
class_name NucleusHandheldTuningProfile
extends Resource
## User-approved performance starting point. Never applied by the detector.
## Only settings already owned by NucleusSettingsService are represented.

@export var profile_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_range(15, 120, 1) var max_fps: int = 60
@export_range(0.25, 1.0, 0.05) var render_scale: float = 1.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if profile_id == &"":
		errors.append("profile_id must be stable and non-empty.")
	if display_name.strip_edges().is_empty():
		errors.append("display_name cannot be empty.")
	if max_fps < 15 or max_fps > 120:
		errors.append("max_fps must be between 15 and 120.")
	if not is_finite(render_scale) or render_scale < 0.25 or render_scale > 1.0:
		errors.append("render_scale must be finite and between 0.25 and 1.0.")
	return errors


## The consumer can inspect these two values; they are not applied here.
func to_settings() -> Dictionary:
	return {
		NucleusSettingIds.GRAPHICS_MAX_FPS: max_fps,
		NucleusSettingIds.GRAPHICS_RENDER_SCALE: render_scale,
	}
