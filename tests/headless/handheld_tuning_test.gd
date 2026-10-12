extends "res://tests/headless/test_case.gd"

const PROFILES: Array[Resource] = [
	preload("res://modules/performance/profiles/handheld_battery.tres"),
	preload("res://modules/performance/profiles/handheld_balanced.tres"),
	preload("res://modules/performance/profiles/handheld_quality.tres"),
]

func run() -> Dictionary:
	var known: Dictionary = NucleusHandheldDetector.classify({
		"os_name": "Linux", "sys_vendor": "Valve", "product_name": "Galileo",
	})
	expect_equal(NucleusHandheldSettingsAdvisor.suggested_profile_id(known),
		&"balanced", "Confirmed handheld suggests balanced, not auto-apply.")
	expect_equal(NucleusHandheldSettingsAdvisor.suggested_profile_id({
		"family": &"rog_ally", "confidence": &"probable", "is_handheld": true,
	}), &"", "Uncertain hardware does not suggest an automatic default.")
	for resource: Resource in PROFILES:
		var profile := resource as NucleusHandheldTuningProfile
		expect_true(profile != null and profile.validate().is_empty(),
			"Bundled handheld profile validates.")
	var battery := PROFILES[0] as NucleusHandheldTuningProfile
	expect_equal(battery.to_settings()[NucleusSettingIds.GRAPHICS_MAX_FPS],
		30, "Battery profile limits FPS to 30.")
	var settings := NucleusSettingsService.new()
	expect_equal(NucleusHandheldSettingsAdvisor.preview(battery, settings)["error"],
		ERR_UNCONFIGURED, "Missing Settings initialization fails closed.")
	expect_equal(NucleusHandheldSettingsAdvisor.apply_profile(
		battery, settings, false
	)["error"], ERR_UNAVAILABLE, "No application without explicit approval.")
	settings.free()
	return finish()
