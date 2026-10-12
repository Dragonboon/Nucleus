class_name NucleusAdaptiveQualityBinding
extends Node
## Opt-in transient render scale: only NucleusDisplaySettingsApplier writes Viewport.
## Never saves preferences. User edits revoke control until explicitly re-enabled.

signal binding_state_changed(active: bool, reason: StringName)
signal effective_scale_changed(value: float)

@export var controller: NucleusAdaptivePerformanceController
@export var display_applier: NucleusDisplaySettingsApplier
@export var start_enabled: bool = false

var _active: bool = false


func _ready() -> void:
	if is_instance_valid(controller):
		controller.render_scale_recommended.connect(_on_recommendation)
	if is_instance_valid(display_applier):
		display_applier.temporary_render_scale_revoked.connect(_on_revoked)
	if start_enabled:
		enable_binding()


func _exit_tree() -> void:
	disable_binding()
	if is_instance_valid(controller):
		if controller.render_scale_recommended.is_connected(_on_recommendation):
			controller.render_scale_recommended.disconnect(_on_recommendation)
	if is_instance_valid(display_applier):
		if display_applier.temporary_render_scale_revoked.is_connected(_on_revoked):
			display_applier.temporary_render_scale_revoked.disconnect(_on_revoked)


func enable_binding() -> Error:
	if _active:
		return OK
	if not is_inside_tree() or not is_instance_valid(controller):
		return ERR_UNCONFIGURED
	if not is_instance_valid(display_applier):
		return ERR_UNCONFIGURED
	var requested: float = controller.get_suggested_scale()
	var status: Error = display_applier.request_temporary_render_scale(
		self, requested
	)
	if status != OK:
		return status
	_active = true
	binding_state_changed.emit(true, &"enabled")
	effective_scale_changed.emit(display_applier.get_effective_render_scale())
	return OK


func disable_binding() -> void:
	if is_instance_valid(display_applier):
		display_applier.release_temporary_render_scale(self)
	if _active:
		_active = false
		binding_state_changed.emit(false, &"disabled")


func is_binding_enabled() -> bool:
	return _active


func _on_recommendation(value: float, _reason: StringName) -> void:
	if not _active:
		return
	if not is_instance_valid(display_applier):
		_active = false
		binding_state_changed.emit(false, &"missing_applier")
		return
	var error: Error = display_applier.request_temporary_render_scale(self, value)
	if error != OK:
		_active = false
		binding_state_changed.emit(false, &"request_rejected")
		return
	effective_scale_changed.emit(display_applier.get_effective_render_scale())


func _on_revoked(reason: StringName) -> void:
	if not _active:
		return
	_active = false
	binding_state_changed.emit(false, reason)
