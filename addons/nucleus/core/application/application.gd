extends Node
## Owns application-wide lifecycle events and graceful shutdown coordination.
##
## This service owns application lifecycle only.
## Game-specific state must never be stored here.

signal focus_changed(is_focused: bool)
signal application_paused
signal application_resumed
signal back_requested
signal memory_warning_received
signal quit_requested(exit_code: int)
signal application_quitting(exit_code: int)

const LOG_CONTEXT: StringName = &"Application"

var is_quitting: bool = false

var _file_logger: NucleusFileLogger


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_install_file_logger()

	NucleusLog.info("Runtime initialized.", LOG_CONTEXT)


func _exit_tree() -> void:
	_uninstall_file_logger()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			focus_changed.emit(true)

		NOTIFICATION_APPLICATION_FOCUS_OUT:
			focus_changed.emit(false)

		NOTIFICATION_APPLICATION_PAUSED:
			application_paused.emit()
			flush_logs()

		NOTIFICATION_APPLICATION_RESUMED:
			application_resumed.emit()

		NOTIFICATION_WM_GO_BACK_REQUEST:
			back_requested.emit()

		NOTIFICATION_OS_MEMORY_WARNING:
			memory_warning_received.emit()
			flush_logs()

		NOTIFICATION_WM_CLOSE_REQUEST:
			request_quit()


## Returns whether the current platform supports closing the application from code.
##
## Browsers do not allow a game to close its own tab, and iOS applications
## should be terminated by the user rather than programmatically.
func can_quit_programmatically() -> bool:
	return NucleusPlatform.supports_programmatic_quit()


## Starts an orderly application shutdown.
##
## [signal quit_requested] is emitted synchronously so persistence services can
## commit critical state before the SceneTree is asked to quit.
func request_quit(exit_code: int = 0) -> Error:
	if is_quitting:
		return ERR_BUSY

	if not can_quit_programmatically():
		return ERR_UNAVAILABLE

	is_quitting = true
	quit_requested.emit(exit_code)
	call_deferred("_finalize_quit", exit_code)

	return OK


## Flushes the runtime log without shutting down the logger.
func flush_logs() -> void:
	if _file_logger:
		_file_logger.flush()


func _finalize_quit(exit_code: int) -> void:
	application_quitting.emit(exit_code)
	flush_logs()
	get_tree().quit(exit_code)


func _install_file_logger() -> void:
	if _file_logger:
		return

	_file_logger = NucleusFileLogger.new()

	if not _file_logger.is_ready():
		_file_logger = null
		push_warning("Nucleus: Runtime file logger could not be initialized.")
		return

	OS.add_logger(_file_logger)


func _uninstall_file_logger() -> void:
	if not _file_logger:
		return

	OS.remove_logger(_file_logger)
	_file_logger.close()
	_file_logger = null
