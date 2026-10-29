class_name NucleusLog
extends RefCounted
## Stateless logging facade for Nucleus and game code.
##
## Messages are emitted through Godot's normal output API. If
## [NucleusFileLogger] is installed, Godot forwards the same output to it.
##
## Debug/info verbosity and call-site decoration are process-local conveniences.
## Warnings and errors are never suppressed by the minimum-level filter.

enum Level {
	DEBUG,
	INFO,
	WARNING,
	ERROR,
}

static var _minimum_level: int = Level.DEBUG
static var _include_callsite: bool = false


## Emits a development-only diagnostic message.
static func debug(
	message: String,
	context: StringName = &"",
) -> void:
	if not is_level_enabled(Level.DEBUG):
		return

	print("[DEBUG] %s" % _with_metadata(message, context))


## Emits a regular informational message.
static func info(
	message: String,
	context: StringName = &"",
) -> void:
	if not is_level_enabled(Level.INFO):
		return

	print(_with_metadata(message, context))


## Emits a Godot warning.
static func warning(
	message: String,
	context: StringName = &"",
) -> void:
	push_warning(_with_metadata(message, context))


## Emits a Godot error.
static func error(
	message: String,
	context: StringName = &"",
) -> void:
	push_error(_with_metadata(message, context))


## Formats bounded diagnostic data before emitting a debug message.
static func debug_data(
	label: String,
	value: Variant,
	context: StringName = &"",
	options: Dictionary = {},
) -> void:
	if not is_level_enabled(Level.DEBUG):
		return

	debug(
		_format_labeled_data(label, value, options),
		context,
	)


## Formats bounded diagnostic data before emitting an info message.
static func info_data(
	label: String,
	value: Variant,
	context: StringName = &"",
	options: Dictionary = {},
) -> void:
	if not is_level_enabled(Level.INFO):
		return

	info(
		_format_labeled_data(label, value, options),
		context,
	)


## Formats bounded diagnostic data before emitting a warning.
static func warning_data(
	label: String,
	value: Variant,
	context: StringName = &"",
	options: Dictionary = {},
) -> void:
	warning(
		_format_labeled_data(label, value, options),
		context,
	)


## Formats bounded diagnostic data before emitting an error.
static func error_data(
	label: String,
	value: Variant,
	context: StringName = &"",
	options: Dictionary = {},
) -> void:
	error(
		_format_labeled_data(label, value, options),
		context,
	)


## Sets the minimum verbosity for debug/info messages.
##
## WARNING and ERROR remain enabled regardless of this value.
static func set_minimum_level(level: int) -> Error:
	if level not in [
		Level.DEBUG,
		Level.INFO,
		Level.WARNING,
		Level.ERROR,
	]:
		return ERR_INVALID_PARAMETER

	_minimum_level = level
	return OK


static func get_minimum_level() -> int:
	return _minimum_level


## Enables optional file/line/function decoration in debug builds.
static func set_include_callsite(enabled: bool) -> void:
	_include_callsite = enabled


static func get_include_callsite() -> bool:
	return _include_callsite


## Returns whether producing a message at this level is useful.
##
## Warning/error always return true because Nucleus never suppresses them.
static func is_level_enabled(level: int) -> bool:
	match level:
		Level.DEBUG:
			return (
				OS.is_debug_build()
				and _minimum_level <= Level.DEBUG
			)
		Level.INFO:
			return _minimum_level <= Level.INFO
		Level.WARNING, Level.ERROR:
			return true
		_:
			return false


static func _format_labeled_data(
	label: String,
	value: Variant,
	options: Dictionary,
) -> String:
	var formatted: String = NucleusLogFormatter.format(
		value,
		options,
	)

	if label.is_empty():
		return formatted

	if formatted.contains("\n"):
		return "%s:\n%s" % [label, formatted]

	return "%s: %s" % [label, formatted]


static func _with_metadata(
	message: String,
	context: StringName,
) -> String:
	var contextual: String = _with_context(message, context)

	if not _include_callsite or not OS.is_debug_build():
		return contextual

	var callsite: String = _resolve_callsite()

	if callsite.is_empty():
		return contextual

	if context == &"":
		return "%s %s" % [callsite, message]

	return "[%s] %s %s" % [
		context,
		callsite,
		message,
	]


static func _resolve_callsite() -> String:
	var stack: Array = get_stack()

	for frame_value: Variant in stack:
		if not frame_value is Dictionary:
			continue

		var frame: Dictionary = frame_value as Dictionary
		var source: String = str(frame.get("source", ""))

		if source.is_empty():
			continue

		if source.ends_with(
			"/core/diagnostics/nucleus_log.gd"
		):
			continue

		var line: int = int(frame.get("line", 0))
		var function_name: String = str(
			frame.get("function", "")
		)
		var file_name: String = source.get_file()

		if file_name.is_empty():
			continue

		if function_name.is_empty():
			return "[%s:%d]" % [file_name, line]

		return "[%s:%d @ %s()]" % [
			file_name,
			line,
			function_name,
		]

	return ""


static func _with_context(
	message: String,
	context: StringName,
) -> String:
	if context == &"":
		return message

	return "[%s] %s" % [context, message]
