class_name NucleusHandheldSettingsAdvisor
extends RefCounted
## A read-only preview plus explicit consent and conditional undo.
## No automatic tuning, TDP, display refresh, controller or SDK operations.

const RECOMMENDED: StringName = &"balanced"


static func suggested_profile_id(hardware: Dictionary) -> StringName:
	if (
		bool(hardware.get("is_handheld", false))
		and hardware.get("family", &"unknown") != &"unknown"
		and hardware.get("confidence", &"unknown") == &"confirmed"
	):
		return RECOMMENDED
	return &""


## Preflight every value against the active catalog; do not silently clamp.
static func preview(
	profile: NucleusHandheldTuningProfile,
	settings: NucleusSettingsService,
) -> Dictionary:
	if profile == null or not profile.validate().is_empty():
		return {"error": ERR_INVALID_PARAMETER, "changes": []}
	if not is_instance_valid(settings) or not settings.is_initialized():
		return {"error": ERR_UNCONFIGURED, "changes": []}
	var changes: Array[Dictionary] = []
	for key: StringName in [
		NucleusSettingIds.GRAPHICS_MAX_FPS,
		NucleusSettingIds.GRAPHICS_RENDER_SCALE,
	]:
		var definition: NucleusSettingDefinition = settings.get_definition(key)
		if definition == null:
			return {"error": ERR_DOES_NOT_EXIST, "changes": []}
		var value: Variant = profile.to_settings()[key]
		if not definition.accepts_value(value):
			return {"error": ERR_INVALID_DATA, "changes": []}
		var normalized: Variant = definition.normalize_value(value)
		if normalized != value:
			return {"error": ERR_INVALID_DATA, "changes": []}
		changes.append({
			"id": key, "current": settings.get_value(key), "suggested": value,
			"changed": settings.get_value(key) != value,
		})
	return {"error": OK, "changes": changes, "profile_id": profile.profile_id}


## Requires affirmative user intent. Preview snapshot blocks stale writes.
## The *last* set_value marks dirty; the existing Settings service owns saving.
static func apply_profile(
	profile: NucleusHandheldTuningProfile,
	settings: NucleusSettingsService,
	approved: bool = false,
	expected: Dictionary = {},
) -> Dictionary:
	if not approved:
		return {"error": ERR_UNAVAILABLE}
	var plan: Dictionary = preview(profile, settings)
	if plan["error"] != OK:
		return plan
	var before: Dictionary = {}
	var after: Dictionary = {}
	var changes: Array[Dictionary] = []
	for entry: Dictionary in plan["changes"]:
		var key: StringName = entry["id"]
		if expected.has(key) and expected[key] != entry["current"]:
			return {"error": ERR_BUSY}
		if not entry["changed"]:
			continue
		before[key] = entry["current"]
		after[key] = entry["suggested"]
		changes.append(entry)
	for i in range(changes.size()):
		var change: Dictionary = changes[i]
		var key: StringName = change["id"]
		var result: Error = settings.set_value(
			key, change["suggested"], i == changes.size() - 1
		)
		if result != OK:
			# Defensive rollback if a consuming game rejects a mid-batch write.
			_restore_values(settings, before)
			return {"error": result}
	return {
		"error": OK,
		"previous_values": before,
		"applied_values": after,
		"changed_count": changes.size(),
	}


## Undo only when no intervening user/config edits occurred.
static func revert_if_unchanged(
	settings: NucleusSettingsService,
	previous_values: Dictionary,
	applied_values: Dictionary,
	approved: bool = false,
) -> Error:
	if not approved:
		return ERR_UNAVAILABLE
	if not is_instance_valid(settings) or not settings.is_initialized():
		return ERR_UNCONFIGURED
	if previous_values.size() != applied_values.size():
		return ERR_INVALID_PARAMETER
	for key: Variant in previous_values:
		if (
			key not in [
				NucleusSettingIds.GRAPHICS_MAX_FPS,
				NucleusSettingIds.GRAPHICS_RENDER_SCALE,
			]
			or not applied_values.has(key)
		):
			return ERR_INVALID_PARAMETER
		var definition: NucleusSettingDefinition = settings.get_definition(key)
		if definition == null or not definition.accepts_value(previous_values[key]):
			return ERR_INVALID_DATA
		if settings.get_value(key) != applied_values[key]:
			return ERR_BUSY
	return _restore_values(settings, previous_values)


static func _restore_values(settings: NucleusSettingsService, values: Dictionary) -> Error:
	var keys: Array = values.keys()
	for i in range(keys.size()):
		var key: StringName = keys[i]
		var result: Error = settings.set_value(key, values[key], i == keys.size() - 1)
		if result != OK:
			return result
	return OK
