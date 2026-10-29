class_name NucleusPaths
extends RefCounted
## Project-specific persistent paths derived from Godot's platform abstraction.
##
## Project resources should continue using res://. These helpers are only for
## writable user data whose physical location varies by platform.

const LOGS_DIRECTORY: String = "logs"
const SAVES_DIRECTORY: String = "saves"
const SCREENSHOTS_DIRECTORY: String = "screenshots"
const SETTINGS_DIRECTORY: String = "settings"
const SETTINGS_FILE_NAME: String = "settings.cfg"


static func user_data_directory() -> String:
	return OS.get_user_data_dir()


static func logs_directory() -> String:
	return user_data_directory().path_join(LOGS_DIRECTORY)


static func saves_directory() -> String:
	return user_data_directory().path_join(SAVES_DIRECTORY)


static func screenshots_directory() -> String:
	return user_data_directory().path_join(SCREENSHOTS_DIRECTORY)


static func settings_directory() -> String:
	return user_data_directory().path_join(SETTINGS_DIRECTORY)


static func settings_file() -> String:
	return settings_directory().path_join(SETTINGS_FILE_NAME)
