extends RefCounted
## Synthetic clips only: no game art or gameplay dependencies.

static func frames(settings: NucleusDirectionalSpriteProfile2D) -> SpriteFrames:
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	var texture := GradientTexture2D.new()
	texture.width = 8
	texture.height = 8
	var groups: Array[PackedStringArray] = [settings.idle_clips, settings.move_clips]
	for clips: PackedStringArray in settings.action_clips.values():
		groups.append(clips)
	for group_index in groups.size():
		for clip: String in groups[group_index]:
			result.add_animation(clip)
			result.set_animation_loop(clip, group_index < 2)
			result.set_animation_speed(clip, 20.0)
			result.add_frame(clip, texture)
			result.add_frame(clip, texture)
	return result


static func profile(eight: bool = false) -> NucleusDirectionalSpriteProfile2D:
	var result := NucleusDirectionalSpriteProfile2D.new()
	var directions: PackedStringArray = ["r", "d", "l", "u"]
	if eight:
		directions = ["r", "dr", "d", "dl", "l", "ul", "u", "ur"]
	result.idle_clips.clear()
	result.move_clips.clear()
	var actions := PackedStringArray()
	var terminal := PackedStringArray()
	for direction: String in directions:
		result.idle_clips.append("rest_" + direction)
		result.move_clips.append("move_" + direction)
		actions.append("use_" + direction)
		terminal.append("end_" + direction)
	result.action_clips[&"use"] = actions
	result.action_clips[&"end"] = terminal
	return result
