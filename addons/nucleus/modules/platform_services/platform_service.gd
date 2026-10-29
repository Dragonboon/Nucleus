class_name NucleusPlatformService
extends Node
## Optional provider-neutral platform lifecycle/identity facade.
##
## Keep provider-specific SDK functionality in an adapter or use the SDK
## directly for features Nucleus does not standardize.

signal provider_changed(provider: NucleusPlatformProvider)
signal provider_ready(provider_id: StringName)
signal initialization_failed(error: Error)
signal identity_changed(user: NucleusPlatformUser)
signal capabilities_changed

@export var provider: NucleusPlatformProvider
@export var initialize_on_ready: bool = true
@export var use_standalone_fallback: bool = true

var _owned_fallback: NucleusNullPlatformProvider


func _ready() -> void:
	_ensure_provider()
	_connect_provider()

	if initialize_on_ready:
		initialize_provider()


func _exit_tree() -> void:
	_disconnect_provider()

	if provider != null and provider.is_initialized():
		provider.shutdown()


func initialize_provider() -> Error:
	_ensure_provider()

	if provider == null:
		initialization_failed.emit(ERR_UNAVAILABLE)
		return ERR_UNAVAILABLE

	var error: Error = provider.initialize()

	if error != OK:
		initialization_failed.emit(error)
		return error

	provider_ready.emit(provider.get_provider_id())
	return OK


func replace_provider(
	next_provider: NucleusPlatformProvider,
	initialize_next: bool = true,
) -> Error:
	if provider == next_provider:
		return (
			initialize_provider()
			if initialize_next
			else OK
		)

	_disconnect_provider()

	if provider != null and provider.is_initialized():
		provider.shutdown()

	if (
		_owned_fallback != null
		and provider == _owned_fallback
		and is_instance_valid(_owned_fallback)
	):
		_owned_fallback.queue_free()

	_owned_fallback = null
	provider = next_provider

	_ensure_provider()
	_connect_provider()
	provider_changed.emit(provider)

	if initialize_next:
		return initialize_provider()

	return OK


func is_ready() -> bool:
	return (
		provider != null
		and provider.is_initialized()
	)


func get_provider_id() -> StringName:
	return (
		provider.get_provider_id()
		if provider != null
		else &""
	)


func get_local_user() -> NucleusPlatformUser:
	if provider == null:
		return NucleusPlatformUser.new()

	return provider.get_local_user()


func has_capability(
	capability: StringName,
) -> bool:
	return (
		provider != null
		and provider.has_capability(capability)
	)


func get_capabilities() -> Array[StringName]:
	if provider == null:
		var empty: Array[StringName] = []
		return empty

	return provider.get_capabilities()


func _ensure_provider() -> void:
	if provider != null or not use_standalone_fallback:
		return

	_owned_fallback = NucleusNullPlatformProvider.new()
	_owned_fallback.name = "StandalonePlatformProvider"
	add_child(_owned_fallback)
	provider = _owned_fallback


func _connect_provider() -> void:
	if provider == null:
		return

	if not provider.identity_changed.is_connected(
		_on_identity_changed
	):
		provider.identity_changed.connect(
			_on_identity_changed
		)

	if not provider.capabilities_changed.is_connected(
		_on_capabilities_changed
	):
		provider.capabilities_changed.connect(
			_on_capabilities_changed
		)


func _disconnect_provider() -> void:
	if provider == null or not is_instance_valid(provider):
		return

	if provider.identity_changed.is_connected(
		_on_identity_changed
	):
		provider.identity_changed.disconnect(
			_on_identity_changed
		)

	if provider.capabilities_changed.is_connected(
		_on_capabilities_changed
	):
		provider.capabilities_changed.disconnect(
			_on_capabilities_changed
		)


func _on_identity_changed(
	user: NucleusPlatformUser,
) -> void:
	identity_changed.emit(user)


func _on_capabilities_changed() -> void:
	capabilities_changed.emit()
