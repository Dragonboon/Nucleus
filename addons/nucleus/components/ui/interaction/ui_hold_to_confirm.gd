class_name NucleusUIHoldToConfirm
extends Node
## Adds real-time hold-to-confirm semantics to an existing BaseButton.
##
## Connect destructive or expensive actions to [signal confirmed], not to the
## button's normal [signal BaseButton.pressed] signal.

signal hold_started
signal progress_changed(progress: float)
signal confirmed
signal canceled

const MICROSECONDS_PER_SECOND: float = 1_000_000.0

@export var target: BaseButton
@export var progress_target: Range

@export_range(0.1, 10.0, 0.05, "or_greater")
var hold_duration: float = 0.8

@export var cancel_on_focus_lost: bool = true
@export var reset_progress_on_release: bool = true

var _holding: bool = false
var _confirmed_this_hold: bool = false
var _started_at_usec: int = 0


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _ready() -> void:
	if not _resolve_target():
		return

	target.button_down.connect(_on_button_down)
	target.button_up.connect(_on_button_up)

	if cancel_on_focus_lost:
		target.focus_exited.connect(_on_focus_exited)

	_set_progress(0.0)


func _process(_delta: float) -> void:
	if not _holding:
		set_process(false)
		return

	var elapsed: float = (
		Time.get_ticks_usec() - _started_at_usec
	) / MICROSECONDS_PER_SECOND
	var progress: float = clampf(
		elapsed / hold_duration,
		0.0,
		1.0,
	)

	_set_progress(progress)

	if progress >= 1.0:
		_complete_hold()


func cancel() -> void:
	if not _holding:
		return

	_holding = false
	set_process(false)
	_set_progress(0.0)

	canceled.emit()


func _resolve_target() -> bool:
	if target == null:
		target = get_parent() as BaseButton

	if target:
		return true

	NucleusLog.error(
		"%s requires a BaseButton target or parent." % get_path(),
		&"UIHoldConfirm",
	)

	return false


func _on_button_down() -> void:
	if target.disabled or _holding:
		return

	_holding = true
	_confirmed_this_hold = false
	_started_at_usec = Time.get_ticks_usec()

	_set_progress(0.0)
	set_process(true)

	hold_started.emit()


func _on_button_up() -> void:
	if _confirmed_this_hold:
		_confirmed_this_hold = false

		if reset_progress_on_release:
			_set_progress(0.0)

		return

	if _holding:
		cancel()


func _on_focus_exited() -> void:
	if _holding:
		cancel()


func _complete_hold() -> void:
	_holding = false
	_confirmed_this_hold = true
	set_process(false)
	_set_progress(1.0)

	confirmed.emit()


func _set_progress(progress: float) -> void:
	var normalized: float = clampf(progress, 0.0, 1.0)

	if progress_target:
		progress_target.value = lerpf(
			progress_target.min_value,
			progress_target.max_value,
			normalized,
		)

	progress_changed.emit(normalized)
