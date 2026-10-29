class_name NucleusPlatformProvider
extends Node
## Base adapter contract for an external platform SDK/provider.
##
## Subclasses override availability, metadata, capabilities and protected
## initialize/shutdown hooks. Nucleus intentionally does not standardize
## achievements, stats, commerce, cloud, or lobby method signatures here.

signal initialized
signal initialization_failed(error: Error)
signal shutdown_completed
signal identity_changed(user: NucleusPlatformUser)
signal capabilities_changed

var _initialized: bool = false


func initialize() -> Error:
	if _initialized:
		return OK

	if not is_available():
		initialization_failed.emit(ERR_UNAVAILABLE)
		return ERR_UNAVAILABLE

	var error: Error = _initialize_provider()

	if error != OK:
		initialization_failed.emit(error)
		return error

	_initialized = true
	initialized.emit()
	return OK


func shutdown() -> void:
	if not _initialized:
		return

	_shutdown_provider()
	_initialized = false
	shutdown_completed.emit()


func is_available() -> bool:
	return false


func is_initialized() -> bool:
	return _initialized


func get_provider_id() -> StringName:
	return &""


func get_local_user() -> NucleusPlatformUser:
	return NucleusPlatformUser.new()


func get_capabilities() -> Array[StringName]:
	var capabilities: Array[StringName] = []
	return capabilities


func has_capability(capability: StringName) -> bool:
	return (
		capability != &""
		and capability in get_capabilities()
	)


func notify_identity_changed() -> void:
	identity_changed.emit(
		get_local_user()
	)


func notify_capabilities_changed() -> void:
	capabilities_changed.emit()


func _initialize_provider() -> Error:
	return OK


func _shutdown_provider() -> void:
	pass
