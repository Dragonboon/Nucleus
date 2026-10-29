@tool
class_name NucleusAnimationStarterProfile3D
extends Resource
## Semantic clip selection for a conventional 3D character starter graph.
##
## The profile references animations already owned by AnimationPlayer. It does not
## duplicate, rename, retarget, or modify imported animation resources.

@export_group("Locomotion")
@export var idle_animation: StringName
@export var walk_animation: StringName
@export var run_animation: StringName
@export_range(0.01, 1000.0, 0.01, "or_greater")
var walk_speed: float = 2.0
@export_range(0.01, 1000.0, 0.01, "or_greater")
var run_speed: float = 5.0

@export_group("Air states")
@export var jump_animation: StringName
@export var fall_animation: StringName
@export var land_animation: StringName

@export_group("Transitions")
@export_range(0.0, 5.0, 0.01, "or_greater")
var crossfade_time: float = 0.12


func get_validation_errors(
	animation_player: AnimationPlayer = null,
) -> PackedStringArray:
	var errors := PackedStringArray()

	if idle_animation == &"":
		errors.append("idle_animation is required")
	if walk_animation == &"":
		errors.append("walk_animation is required")
	if run_animation == &"":
		errors.append("run_animation is required")

	if walk_speed <= 0.0:
		errors.append("walk_speed must be greater than zero")
	if run_speed <= walk_speed:
		errors.append("run_speed must be greater than walk_speed")
	if crossfade_time < 0.0:
		errors.append("crossfade_time cannot be negative")

	if animation_player != null:
		for clip_name: StringName in get_configured_clips():
			if not animation_player.has_animation(clip_name):
				errors.append(
					"AnimationPlayer does not contain '%s'." % clip_name
				)

	return errors


func get_configured_clips() -> Array[StringName]:
	var clips: Array[StringName] = []

	for clip_name: StringName in [
		idle_animation,
		walk_animation,
		run_animation,
		jump_animation,
		fall_animation,
		land_animation,
	]:
		if clip_name != &"" and clip_name not in clips:
			clips.append(clip_name)

	return clips


## Fills blank semantic slots using conservative name matching.
##
## Returns the number of fields changed. Existing authored values are preserved
## unless [param overwrite] is true.
func suggest_common_clips(
	animation_player: AnimationPlayer,
	overwrite: bool = false,
) -> int:
	if animation_player == null:
		return 0

	var names := animation_player.get_animation_list()
	var changed := 0

	changed += _suggest_field(
		"idle_animation",
		names,
		PackedStringArray(["idle"]),
		overwrite,
	)
	changed += _suggest_field(
		"walk_animation",
		names,
		PackedStringArray(["walk"]),
		overwrite,
	)
	changed += _suggest_field(
		"run_animation",
		names,
		PackedStringArray(["run", "jog", "sprint"]),
		overwrite,
	)
	changed += _suggest_field(
		"jump_animation",
		names,
		PackedStringArray(["jump", "takeoff", "take off"]),
		overwrite,
	)
	changed += _suggest_field(
		"fall_animation",
		names,
		PackedStringArray(["fall", "falling", "airborne"]),
		overwrite,
	)
	changed += _suggest_field(
		"land_animation",
		names,
		PackedStringArray(["land", "landing"]),
		overwrite,
	)

	if changed > 0:
		emit_changed()

	return changed


func _suggest_field(
	property_name: StringName,
	names: PackedStringArray,
	aliases: PackedStringArray,
	overwrite: bool,
) -> int:
	var current := StringName(str(get(property_name)))

	if current != &"" and not overwrite:
		return 0

	var match_name := _find_best_match(names, aliases)

	if match_name == &"":
		return 0

	set(property_name, match_name)
	return 1


func _find_best_match(
	names: PackedStringArray,
	aliases: PackedStringArray,
) -> StringName:
	var best: StringName = &""
	var best_score := 2147483647

	for raw_name: String in names:
		if raw_name == "RESET":
			continue

		var normalized := _normalize_name(raw_name)
		var tokens := normalized.split(" ", false)

		for alias_index: int in range(aliases.size()):
			var alias := aliases[alias_index].to_lower()
			var score := 2147483647

			if normalized == alias:
				score = alias_index * 10
			elif alias in tokens:
				score = 100 + alias_index * 10 + normalized.length()
			elif normalized.ends_with(" " + alias):
				score = 200 + alias_index * 10 + normalized.length()
			elif normalized.contains(alias):
				score = 300 + alias_index * 10 + normalized.length()

			if score < best_score:
				best_score = score
				best = StringName(raw_name)

	return best


func _normalize_name(value: String) -> String:
	var normalized := value.to_lower().strip_edges()

	for separator: String in ["/", "\\", "_", "-", ".", ":"]:
		normalized = normalized.replace(separator, " ")

	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")

	return normalized
