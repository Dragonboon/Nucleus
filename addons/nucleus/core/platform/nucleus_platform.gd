class_name NucleusPlatform
extends RefCounted
## Stateless runtime platform capability queries.
##
## Prefer feature/capability checks over scattering platform-name comparisons
## throughout Core modules.


static func get_name() -> String:
	return OS.get_name()


static func is_web() -> bool:
	return OS.has_feature("web")


static func is_android() -> bool:
	return OS.has_feature("android")


static func is_ios() -> bool:
	return OS.has_feature("ios")


static func is_native_mobile() -> bool:
	return OS.has_feature("mobile")


static func is_web_mobile() -> bool:
	return (
		OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)


static func is_mobile_host() -> bool:
	return is_native_mobile() or is_web_mobile()


static func supports_touchscreen() -> bool:
	return DisplayServer.has_feature(
		DisplayServer.FEATURE_TOUCHSCREEN
	)


static func supports_orientation() -> bool:
	return DisplayServer.has_feature(
		DisplayServer.FEATURE_ORIENTATION
	)


static func supports_handheld_haptics() -> bool:
	return is_android() or is_ios() or is_web()


static func supports_threads() -> bool:
	return OS.has_feature("threads")


static func supports_programmatic_quit() -> bool:
	return not is_web() and not is_ios()


static func uses_managed_window_mode() -> bool:
	return is_web() or is_native_mobile()


static func is_user_data_persistent() -> bool:
	return OS.is_userfs_persistent()


## Detects PC handheld hardware without conflating Steam, Windows or Linux.
static func get_handheld_info() -> Dictionary:
	return NucleusHandheldDetector.detect()


## Includes confirmed and probable hardware. Inspect confidence before policy.
static func is_pc_handheld() -> bool:
	return bool(get_handheld_info()["is_handheld"])
