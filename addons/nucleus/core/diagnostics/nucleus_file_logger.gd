class_name NucleusFileLogger
extends Logger
## Thread-safe runtime file logger backed by Godot's Logger API.
##
## The logger only captures engine output. It never prints from inside Logger
## callbacks, preventing recursive logging.

const LOG_FILE_PREFIX: String = "nucleus_"
const LOG_FILE_EXTENSION: String = ".log"
const MAX_LOG_FILES: int = 10
const MAX_BUFFERED_LINES: int = 16

var _log_directory: String
var _file: FileAccess
var _mutex: Mutex = Mutex.new()
var _buffer: PackedStringArray = []
var _is_closed: bool = false


func _init(log_directory: String = "") -> void:
	_log_directory = (
		log_directory
		if not log_directory.is_empty()
		else NucleusPaths.logs_directory()
	)

	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		_log_directory
	)

	if directory_error not in [OK, ERR_ALREADY_EXISTS]:
		return

	_prune_old_logs()

	var log_path: String = _log_directory.path_join(
		_create_log_file_name()
	)
	_file = FileAccess.open(log_path, FileAccess.WRITE)

	if _file:
		_write_header()


func _log_message(
	message: String,
	is_error: bool,
) -> void:
	if not is_ready():
		return

	var severity: String = "STDERR" if is_error else "INFO"
	var formatted_message: String = _format_message(
		severity,
		message.trim_suffix("\n"),
	)

	_enqueue(formatted_message, is_error)


func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		script_backtraces: Array[ScriptBacktrace],
) -> void:
	if not is_ready():
		return

	var severity: String = _get_error_severity(error_type)
	var message_parts: PackedStringArray = []

	if not rationale.is_empty():
		message_parts.append(rationale)

	if not code.is_empty():
		message_parts.append(code)

	if not file.is_empty():
		message_parts.append(
			"%s:%d @ %s()" % [
				file,
				line,
				function,
			]
		)

	for backtrace: ScriptBacktrace in script_backtraces:
		message_parts.append(str(backtrace))

	var formatted_message: String = _format_message(
		severity,
		"\n".join(message_parts),
	)

	_enqueue(
		formatted_message,
		error_type != ERROR_TYPE_WARNING,
	)


## Returns whether the logger has a writable backing file.
func is_ready() -> bool:
	return (
		not _is_closed
		and _file != null
		and _file.is_open()
	)


## Writes all queued log lines to disk.
func flush() -> void:
	_mutex.lock()
	_flush_locked()
	_mutex.unlock()


## Flushes and closes the backing file.
func close() -> void:
	_mutex.lock()

	if _is_closed:
		_mutex.unlock()
		return

	_flush_locked()

	if _file:
		_file.close()
		_file = null

	_is_closed = true
	_mutex.unlock()


func _enqueue(
	message: String,
	flush_immediately: bool = false,
) -> void:
	_mutex.lock()

	if not is_ready():
		_mutex.unlock()
		return

	_buffer.append(message)

	if (
		flush_immediately
		or _buffer.size() >= MAX_BUFFERED_LINES
	):
		_flush_locked()

	_mutex.unlock()


func _flush_locked() -> void:
	if not is_ready() or _buffer.is_empty():
		return

	for message: String in _buffer:
		if not _file.store_line(message):
			break

	_buffer.clear()
	_file.flush()


func _write_header() -> void:
	var project_name: String = str(
		ProjectSettings.get_setting(
			"application/config/name",
			"Unnamed Project",
		)
	)
	var project_version: String = str(
		ProjectSettings.get_setting(
			"application/config/version",
			"",
		)
	)
	var engine_version: Dictionary = Engine.get_version_info()

	_file.store_line("# Nucleus runtime log")
	_file.store_line("# Project: %s" % project_name)

	if not project_version.is_empty():
		_file.store_line("# Version: %s" % project_version)

	_file.store_line(
		"# Godot: %s"
		% engine_version.get("string", "unknown")
	)
	_file.store_line("# Platform: %s" % OS.get_name())
	_file.store_line("# Process ID: %d" % OS.get_process_id())
	_file.store_line(
		"# Started: %s"
		% Time.get_datetime_string_from_system()
	)
	_file.store_line("")
	_file.flush()


func _create_log_file_name() -> String:
	var datetime: String = Time.get_datetime_string_from_system()
	datetime = datetime.replace(":", "-").replace("T", "_")

	var process_id: int = OS.get_process_id()
	var unique_suffix: int = int(
		Time.get_unix_time_from_system() * 1000.0
	)

	return "%s%s_pid-%d_%d%s" % [
		LOG_FILE_PREFIX,
		datetime,
		process_id,
		unique_suffix,
		LOG_FILE_EXTENSION,
	]


func _prune_old_logs() -> void:
	var directory: DirAccess = DirAccess.open(_log_directory)

	if directory == null:
		return

	var log_files: Array[String] = []

	for file_name: String in directory.get_files():
		if (
			file_name.begins_with(LOG_FILE_PREFIX)
			and file_name.ends_with(LOG_FILE_EXTENSION)
		):
			log_files.append(file_name)

	log_files.sort()

	while log_files.size() >= MAX_LOG_FILES:
		var oldest_file: String = log_files.pop_front()
		directory.remove(oldest_file)


func _format_message(
	severity: String,
	message: String,
) -> String:
	return "[%s] [%s] %s" % [
		Time.get_datetime_string_from_system(),
		severity,
		message,
	]


func _get_error_severity(error_type: int) -> String:
	match error_type:
		ERROR_TYPE_WARNING:
			return "WARNING"
		ERROR_TYPE_SCRIPT:
			return "SCRIPT_ERROR"
		ERROR_TYPE_SHADER:
			return "SHADER_ERROR"
		_:
			return "ERROR"
