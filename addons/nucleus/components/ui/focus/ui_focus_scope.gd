class_name NucleusUIFocusScope
extends Node
## Manages predictable keyboard/controller focus inside one UI subtree.

@export var target: Control
@export var initial_focus: Control

@export var focus_on_ready: bool = true
@export var focus_when_shown: bool = true
@export var restore_last_focus: bool = true
@export var release_focus_when_hidden: bool = true

var _last_focus: Control
var _viewport: Viewport


func _ready() -> void:
	if not _resolve_target():
		return

	_viewport = target.get_viewport()
	_viewport.gui_focus_changed.connect(_on_gui_focus_changed)
	target.visibility_changed.connect(_on_visibility_changed)

	if focus_on_ready and target.is_visible_in_tree():
		call_deferred("_focus_preferred")


func focus_first() -> Control:
	for control: Control in _get_focusable_controls():
		control.grab_focus()
		return control

	return null


func focus_last() -> Control:
	var controls: Array[Control] = _get_focusable_controls()

	if controls.is_empty():
		return null

	var control: Control = controls.back()
	control.grab_focus()

	return control


func restore_focus() -> Control:
	if _is_focusable(_last_focus):
		_last_focus.grab_focus()
		return _last_focus

	return focus_first()


func release_focus() -> void:
	if _viewport:
		_viewport.gui_release_focus()


func _focus_preferred() -> void:
	if not target.is_visible_in_tree():
		return

	if (
		restore_last_focus
		and _is_focusable(_last_focus)
	):
		_last_focus.grab_focus()
		return

	if _is_focusable(initial_focus):
		initial_focus.grab_focus()
		return

	focus_first()


func _get_focusable_controls() -> Array[Control]:
	var result: Array[Control] = []

	if _is_focusable(target):
		result.append(target)

	for node: Node in NucleusNodeUtils.descendants(target):
		if node is Control and _is_focusable(node as Control):
			result.append(node as Control)

	return result


func _is_focusable(control: Control) -> bool:
	if control == null or not is_instance_valid(control):
		return false

	if not control.is_inside_tree() or not control.is_visible_in_tree():
		return false

	if control.focus_mode == Control.FOCUS_NONE:
		return false

	if control is BaseButton and (control as BaseButton).disabled:
		return false

	return true


func _is_inside_scope(control: Control) -> bool:
	return (
		control == target
		or target.is_ancestor_of(control)
	)


func _resolve_target() -> bool:
	if target == null:
		target = get_parent() as Control

	if target:
		return true

	NucleusLog.error(
		"%s requires a Control target or parent." % get_path(),
		&"UIFocus",
	)

	return false


func _on_gui_focus_changed(control: Control) -> void:
	if control and _is_inside_scope(control):
		_last_focus = control


func _on_visibility_changed() -> void:
	if target.is_visible_in_tree():
		if focus_when_shown:
			call_deferred("_focus_preferred")
		return

	if not release_focus_when_hidden or _viewport == null:
		return

	var focus_owner: Control = _viewport.gui_get_focus_owner()

	if focus_owner and _is_inside_scope(focus_owner):
		_last_focus = focus_owner
		_viewport.gui_release_focus()
