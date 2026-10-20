@tool
class_name NucleusSpriteSequenceProfile2D
extends Resource
## Persistent editable profile for pre-sliced frame sequences.

@export var source_directory: String
@export var character_id: String = "character"
@export var clips: Array[NucleusSpriteSequenceClip2D] = []


func validate() -> PackedStringArray:
	var issues := PackedStringArray()
	if character_id.is_empty() or ".." in character_id:
		issues.append("Character identifier is invalid.")
	if clips.is_empty():
		issues.append("Create at least one animation.")
	var names: Dictionary = {}
	for clip: NucleusSpriteSequenceClip2D in clips:
		if clip == null:
			issues.append("A clip is null.")
			continue
		if names.has(clip.animation_name):
			issues.append("Duplicate clip name: %s" % clip.animation_name)
		names[clip.animation_name] = true
		issues.append_array(clip.validate())
	return issues
