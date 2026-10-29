@tool
class_name NucleusSurfaceProfile
extends Resource
## Semantic identity for a world surface.
##
## The profile deliberately contains no audio, particles, decals, friction, or
## gameplay rules. Consumers map this semantic identity to their own responses.

@export var surface_id: StringName = &""
@export var tags: Array[StringName] = []


func has_tag(tag: StringName) -> bool:
	return tag != &"" and tag in tags


func has_any_tag(query_tags: Array[StringName]) -> bool:
	for tag: StringName in query_tags:
		if has_tag(tag):
			return true

	return false


func has_all_tags(query_tags: Array[StringName]) -> bool:
	for tag: StringName in query_tags:
		if not has_tag(tag):
			return false

	return true


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary[StringName, bool] = {}

	if surface_id == &"":
		errors.append("surface_id must not be empty.")

	for index: int in range(tags.size()):
		var tag: StringName = tags[index]

		if tag == &"":
			errors.append("tags[%d] must not be empty." % index)
			continue

		if seen.has(tag):
			errors.append("tags contains duplicate value '%s'." % tag)
			continue

		seen[tag] = true

	return errors
