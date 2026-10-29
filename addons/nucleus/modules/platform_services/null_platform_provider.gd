class_name NucleusNullPlatformProvider
extends NucleusPlatformProvider
## Standalone/offline provider for projects without an external platform SDK.

@export var local_user_id: String = "local"
@export var local_display_name: String = "Local Player"


func is_available() -> bool:
	return true


func get_provider_id() -> StringName:
	return &"standalone"


func get_local_user() -> NucleusPlatformUser:
	return NucleusPlatformUser.new(
		get_provider_id(),
		local_user_id,
		local_display_name,
		TranslationServer.get_locale(),
	)


func get_capabilities() -> Array[StringName]:
	var capabilities: Array[StringName] = [
		NucleusPlatformCapabilities.IDENTITY,
	]
	return capabilities
