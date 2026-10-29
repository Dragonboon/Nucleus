class_name NucleusUIModalHost
extends CanvasLayer
## Scene-owned stack for in-viewport game dialogs and modal panels.
##
## Native OS [Window] dialogs solve a different problem. This host is designed
## for game UI that must work consistently on desktop, mobile, and Web.

signal modal_opened(modal: NucleusUIModal)
signal modal_closed(
	modal: NucleusUIModal,
	reason: int,
)
signal stack_changed(depth: int)

@export var backdrop_color: Color = Color(0.0, 0.0, 0.0, 0.62)
@export var backdrop_motion: NucleusUIMotionProfile

var _stack: Array[NucleusUIModal] = []
var _previous_focus: Control
var _backdrop_tween: Tween
var _original_z: Dictionary[int, int] = {}

@onready var _backdrop: ColorRect = $Root/Backdrop
@onready var _content: Control = $Root/ModalContent


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	if backdrop_motion == null:
		backdrop_motion = NucleusUIMotionProfile.new()
		backdrop_motion.duration = 0.14

	_backdrop.color = Color(
		backdrop_color.r,
		backdrop_color.g,
		backdrop_color.b,
		1.0,
	)
	_backdrop.modulate.a = 0.0
	_backdrop.hide()
	_backdrop.gui_input.connect(_on_backdrop_gui_input)


func get_content() -> Control:
	return _content


func get_depth() -> int:
	return _stack.size()


func get_top_modal() -> NucleusUIModal:
	return _stack.back() if not _stack.is_empty() else null


func open(modal: NucleusUIModal) -> Error:
	if modal == null or modal.target == null:
		return ERR_INVALID_PARAMETER

	if not _content.is_ancestor_of(modal.target):
		return ERR_INVALID_PARAMETER

	if modal in _stack:
		return ERR_ALREADY_EXISTS

	if _stack.is_empty():
		_previous_focus = get_viewport().gui_get_focus_owner()
		_show_backdrop()

	_connect_modal(modal)

	_original_z[modal.get_instance_id()] = modal.target.z_index
	modal.target.z_index = 10 + _stack.size()

	_stack.append(modal)
	modal.present()

	modal_opened.emit(modal)
	stack_changed.emit(_stack.size())

	return OK


func close_top(
	reason: int = NucleusUIModal.CloseReason.PROGRAMMATIC,
) -> Error:
	var modal: NucleusUIModal = get_top_modal()

	if modal == null:
		return ERR_DOES_NOT_EXIST

	return close(modal, reason)


func close(
	modal: NucleusUIModal,
	reason: int = NucleusUIModal.CloseReason.PROGRAMMATIC,
) -> Error:
	var index: int = _stack.find(modal)

	if index == -1:
		return ERR_DOES_NOT_EXIST

	_stack.remove_at(index)
	_disconnect_modal(modal)
	_restore_modal_z(modal)
	modal.dismiss(reason)

	stack_changed.emit(_stack.size())

	if _stack.is_empty():
		_hide_backdrop()
		_restore_previous_focus()
	else:
		_focus_top_modal()

	return OK


func close_all(
	reason: int = NucleusUIModal.CloseReason.PROGRAMMATIC,
) -> void:
	while not _stack.is_empty():
		close(_stack.back(), reason)


func _unhandled_input(event: InputEvent) -> void:
	var modal: NucleusUIModal = get_top_modal()

	if modal == null or not modal.dismiss_on_cancel:
		return

	if event.is_action_pressed(&"ui_cancel"):
		close(
			modal,
			NucleusUIModal.CloseReason.CANCELED,
		)
		get_viewport().set_input_as_handled()


func _connect_modal(modal: NucleusUIModal) -> void:
	var accept_callback: Callable = _on_modal_accept_requested.bind(modal)
	var cancel_callback: Callable = _on_modal_cancel_requested.bind(modal)
	var closed_callback: Callable = _on_modal_dismissed.bind(modal)

	if not modal.accept_requested.is_connected(accept_callback):
		modal.accept_requested.connect(accept_callback)

	if not modal.cancel_requested.is_connected(cancel_callback):
		modal.cancel_requested.connect(cancel_callback)

	if not modal.closed.is_connected(closed_callback):
		modal.closed.connect(
			closed_callback,
			CONNECT_ONE_SHOT,
		)


func _disconnect_modal(modal: NucleusUIModal) -> void:
	var accept_callback: Callable = _on_modal_accept_requested.bind(modal)
	var cancel_callback: Callable = _on_modal_cancel_requested.bind(modal)

	if modal.accept_requested.is_connected(accept_callback):
		modal.accept_requested.disconnect(accept_callback)

	if modal.cancel_requested.is_connected(cancel_callback):
		modal.cancel_requested.disconnect(cancel_callback)


func _on_modal_accept_requested(modal: NucleusUIModal) -> void:
	close(
		modal,
		NucleusUIModal.CloseReason.ACCEPTED,
	)


func _on_modal_cancel_requested(modal: NucleusUIModal) -> void:
	close(
		modal,
		NucleusUIModal.CloseReason.CANCELED,
	)


func _on_backdrop_gui_input(event: InputEvent) -> void:
	var modal: NucleusUIModal = get_top_modal()

	if modal == null or not modal.dismiss_on_backdrop:
		return

	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton

	if (
		mouse_event.button_index == MOUSE_BUTTON_LEFT
		and mouse_event.pressed
	):
		close(
			modal,
			NucleusUIModal.CloseReason.BACKDROP,
		)
		_backdrop.accept_event()


func _on_modal_dismissed(
	reason: int,
	modal: NucleusUIModal,
) -> void:
	modal_closed.emit(modal, reason)


func _show_backdrop() -> void:
	_kill_backdrop_tween()

	_backdrop.show()
	_backdrop.modulate.a = 0.0
	_backdrop_tween = NucleusUIMotion.fade_to(
		_backdrop,
		backdrop_color.a,
		backdrop_motion,
	)


func _hide_backdrop() -> void:
	_kill_backdrop_tween()

	_backdrop_tween = NucleusUIMotion.fade_to(
		_backdrop,
		0.0,
		backdrop_motion,
	)
	_backdrop_tween.finished.connect(
		_backdrop.hide,
		CONNECT_ONE_SHOT,
	)


func _kill_backdrop_tween() -> void:
	if _backdrop_tween and _backdrop_tween.is_valid():
		_backdrop_tween.kill()

	_backdrop_tween = null


func _focus_top_modal() -> void:
	var modal: NucleusUIModal = get_top_modal()

	if modal and modal.focus_scope:
		modal.focus_scope.call_deferred("restore_focus")


func _restore_previous_focus() -> void:
	if (
		_previous_focus
		and is_instance_valid(_previous_focus)
		and _previous_focus.is_inside_tree()
		and _previous_focus.is_visible_in_tree()
	):
		_previous_focus.call_deferred("grab_focus")

	_previous_focus = null


func _restore_modal_z(modal: NucleusUIModal) -> void:
	var instance_id: int = modal.get_instance_id()

	if _original_z.has(instance_id):
		modal.target.z_index = _original_z[instance_id]
		_original_z.erase(instance_id)
