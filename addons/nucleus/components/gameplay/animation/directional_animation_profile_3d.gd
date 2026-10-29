@tool
class_name NucleusDirectionalAnimationProfile3D
extends Resource
## Semantic clips for one directional locomotion gait.
##
## Intended for strafe/lock-on/shooter locomotion. Gameplay movement and facing
## policy remain owned by the consuming game.

@export_group("Required")
@export var idle_animation: StringName
@export var forward_animation: StringName
@export var backward_animation: StringName
@export var left_animation: StringName
@export var right_animation: StringName

@export_group("Optional diagonals")
@export var forward_left_animation: StringName
@export var forward_right_animation: StringName
@export var backward_left_animation: StringName
@export var backward_right_animation: StringName

@export_group("Velocity mapping")
@export_range(0.01, 1000.0, 0.01, "or_greater")
var reference_speed: float = 5.0


func get_validation_errors(
	animation_player: AnimationPlayer = null,
) -> PackedStringArray:
	var errors := PackedStringArray()

	for entry: Dictionary in [
		{"label": "idle_animation", "value": idle_animation},
		{"label": "forward_animation", "value": forward_animation},
		{"label": "backward_animation", "value": backward_animation},
		{"label": "left_animation", "value": left_animation},
		{"label": "right_animation", "value": right_animation},
	]:
		if StringName(entry["value"]) == &"":
			errors.append("%s is required" % String(entry["label"]))

	if reference_speed <= 0.0:
		errors.append("reference_speed must be greater than zero")

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
		forward_animation,
		backward_animation,
		left_animation,
		right_animation,
		forward_left_animation,
		forward_right_animation,
		backward_left_animation,
		backward_right_animation,
	]:
		if clip_name != &"" and clip_name not in clips:
			clips.append(clip_name)

	return clips


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
		"forward_animation",
		names,
		PackedStringArray([
			"forward",
			"walk forward",
			"run forward",
			"move forward",
		]),
		overwrite,
	)
	changed += _suggest_field(
		"backward_animation",
		names,
		PackedStringArray([
			"backward",
			"backwards",
			"walk back",
			"run back",
		]),
		overwrite,
	)
	changed += _suggest_field(
		"left_animation",
		names,
		PackedStringArray([
			"strafe left",
			"left strafe",
			"walk left",
			"run left",
		]),
		overwrite,
	)
	changed += _suggest_field(
		"right_animation",
		names,
		PackedStringArray([
			"strafe right",
			"right strafe",
			"walk right",
			"run right",
		]),
		overwrite,
	)
	changed += _suggest_field(
		"forward_left_animation",
		names,
		PackedStringArray(["forward left", "front left"]),
		overwrite,
	)
	changed += _suggest_field(
		"forward_right_animation",
		names,
		PackedStringArray(["forward right", "front right"]),
		overwrite,
	)
	changed += _suggest_field(
		"backward_left_animation",
		names,
		PackedStringArray(["backward left", "back left"]),
		overwrite,
	)
	changed += _suggest_field(
		"backward_right_animation",
		names,
		PackedStringArray(["backward right", "back right"]),
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

		for alias_index: int in range(aliases.size()):
			var alias := _normalize_name(aliases[alias_index])
			var score := 2147483647

			if normalized == alias:
				score = alias_index * 10
			elif normalized.ends_with(" " + alias):
				score = 100 + alias_index * 10 + normalized.length()
			elif normalized.contains(alias):
				score = 200 + alias_index * 10 + normalized.length()

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
