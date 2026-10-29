class_name NucleusDirectionalSpriteProfile2D
extends Resource
## Clip arrays run clockwise from right in Godot's positive-Y-down canvas.
## Four entries: right/down/left/up. Eight entries insert diagonals between them.

@export var idle_clips: PackedStringArray = ["idle_right", "idle_down", "idle_left", "idle_up"]
@export var move_clips: PackedStringArray = ["walk_right", "walk_down", "walk_left", "walk_up"]
@export var action_clips: Dictionary[StringName, PackedStringArray] = {}
@export_range(0.0, 1000.0) var start_speed: float = 3.0
@export_range(0.0, 1000.0) var stop_speed: float = 1.0
@export_range(0.0, 0.3) var direction_hysteresis: float = 0.09


func get_validation_errors(frames: SpriteFrames) -> PackedStringArray:
	var errors := PackedStringArray()
	var count := idle_clips.size()
	if count not in [4, 8] or move_clips.size() != count:
		errors.append("Locomotion requires matching arrays of four or eight directions.")
	if (not is_finite(start_speed) or not is_finite(stop_speed)
		or stop_speed < 0.0 or start_speed <= stop_speed):
		errors.append("Speeds must be finite and start_speed > stop_speed >= 0.")
	if (not is_finite(direction_hysteresis) or direction_hysteresis < 0.0
		or direction_hysteresis >= PI / float(maxi(1, count))):
		errors.append("Direction hysteresis must be smaller than half a sector.")
	if frames == null:
		errors.append("Assign SpriteFrames.")
		return errors
	_validate_clips(frames, idle_clips, true, errors)
	_validate_clips(frames, move_clips, true, errors)
	for action: StringName in action_clips:
		if action == &"" or action_clips[action].size() != count:
			errors.append("Actions require a nonempty ID and one clip per direction.")
		_validate_clips(frames, action_clips[action], false, errors)
	return errors


func _validate_clips(
	frames: SpriteFrames, clips: PackedStringArray, loop: bool, errors: PackedStringArray,
) -> void:
	for clip: String in clips:
		if clip.is_empty() or not frames.has_animation(clip):
			errors.append("Missing clip: " + clip)
			continue
		if (frames.get_frame_count(clip) == 0 or frames.get_animation_loop(clip) != loop
			or not is_finite(frames.get_animation_speed(clip))
			or frames.get_animation_speed(clip) <= 0.0):
			errors.append("Invalid frames, speed or loop mode: " + clip)
		for index in frames.get_frame_count(clip):
			if frames.get_frame_texture(clip, index) == null:
				errors.append("Missing texture: " + clip)
