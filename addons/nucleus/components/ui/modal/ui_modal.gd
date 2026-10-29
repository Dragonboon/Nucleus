class_name NucleusUIModal
extends Node
## Scene component that describes one modal Control.
##
## [NucleusUIModalHost] owns stack/input policy. This component owns the
## modal's presentation and focus behavior.

signal accept_requested
signal cancel_requested
signal opened
signal closed(reason: int)

enum CloseReason {
	PROGRAMMATIC,
	ACCEPTED,
	CANCELED,
	BACKDROP,
}

@export var target: Control
@export var presenter: NucleusUIPresenter
@export var focus_scope: NucleusUIFocusScope

@export_group("Dismiss policy")
@export var dismiss_on_cancel: bool = true
@export var dismiss_on_backdrop: bool = true

var is_open: bool = false


func _ready() -> void:
	_resolve_dependencies()

	if target:
		target.hide()


func request_accept() -> void:
	if is_open:
		accept_requested.emit()


func request_cancel() -> void:
	if is_open:
		cancel_requested.emit()


func present() -> void:
	if target == null or is_open:
		return

	is_open = true

	if presenter:
		presenter.show_animated()
	else:
		target.show()

	if focus_scope:
		focus_scope.call_deferred("restore_focus")

	opened.emit()


func dismiss(reason: int = CloseReason.PROGRAMMATIC) -> void:
	if target == null or not is_open:
		return

	is_open = false

	if presenter:
		var tween: Tween = presenter.hide_animated()
		tween.finished.connect(
			_emit_closed.bind(reason),
			CONNECT_ONE_SHOT,
		)
		return

	target.hide()
	closed.emit(reason)


func _emit_closed(reason: int) -> void:
	closed.emit(reason)


func _resolve_dependencies() -> void:
	if target == null:
		target = get_parent() as Control

	if target == null:
		NucleusLog.error(
			"%s requires a Control target or parent." % get_path(),
			&"UIModal",
		)
		return

	if presenter == null:
		presenter = _find_presenter()

	if focus_scope == null:
		focus_scope = _find_focus_scope()


func _find_presenter() -> NucleusUIPresenter:
	for node: Node in NucleusNodeUtils.descendants(target):
		if node is NucleusUIPresenter:
			return node as NucleusUIPresenter

	return null


func _find_focus_scope() -> NucleusUIFocusScope:
	for node: Node in NucleusNodeUtils.descendants(target):
		if node is NucleusUIFocusScope:
			return node as NucleusUIFocusScope

	return null
