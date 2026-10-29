class_name NucleusHaptics
extends RefCounted
## Cross-device vibration policy using the existing vibration preference.


static func pulse(
	strength: float = 0.5,
	duration_seconds: float = 0.12,
	player_input: NucleusLocalPlayerInput = null,
) -> Error:
	if not NucleusSettings.get_bool(
		NucleusSettingIds.INPUT_VIBRATION_ENABLED,
		true,
	):
		return ERR_UNAVAILABLE

	var normalized_strength: float = clampf(strength, 0.0, 1.0)
	var normalized_duration: float = maxf(duration_seconds, 0.0)

	if player_input and player_input.is_gamepad():
		return player_input.start_vibration(
			normalized_strength,
			normalized_strength,
			normalized_duration,
		)

	if NucleusInput.active_source == NucleusInputTypes.Source.GAMEPAD:
		return NucleusInput.start_vibration(
			normalized_strength,
			normalized_strength,
			normalized_duration,
		)

	if NucleusPlatform.supports_handheld_haptics():
		Input.vibrate_handheld(
			roundi(normalized_duration * 1000.0),
			normalized_strength,
		)
		return OK

	return ERR_UNAVAILABLE
