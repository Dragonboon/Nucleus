class_name NucleusUIPageController
extends Node
## Controls mutually exclusive UI pages and optional tab buttons.

signal page_changing(
	from_index: int,
	to_index: int,
)
signal page_changed(
	index: int,
	page: Control,
)

@export var pages: Array[Control] = []
@export var tab_buttons: Array[BaseButton] = []
@export var initial_index: int = 0

@export var animate_transitions: bool = true
@export var motion: NucleusUIMotionProfile

var current_index: int = -1

var _transition_tween: Tween
var _base_alpha: Dictionary[int, float] = {}


func _ready() -> void:
	if motion == null:
		motion = NucleusUIMotionProfile.new()
		motion.duration = 0.14

	_record_page_state()
	_connect_tabs()

	if pages.is_empty():
		return

	var safe_initial_index: int = clampi(
		initial_index,
		0,
		pages.size() - 1,
	)

	_show_immediately(safe_initial_index)


func show_page(
	index: int,
	animated: bool = true,
) -> Error:
	if index < 0 or index >= pages.size():
		return ERR_INVALID_PARAMETER

	if index == current_index:
		return OK

	if _transition_tween and _transition_tween.is_running():
		return ERR_BUSY

	var previous_index: int = current_index
	var previous_control: Control = (
		pages[previous_index]
		if previous_index >= 0
		else null
	)
	var next_control: Control = pages[index]

	if next_control == null:
		return ERR_INVALID_DATA

	page_changing.emit(previous_index, index)

	if (
		not animated
		or not animate_transitions
		or previous_control == null
	):
		_show_immediately(index)
		return OK

	var duration: float = NucleusUIMotion.get_duration(motion)

	next_control.show()
	next_control.modulate.a = 0.0

	_transition_tween = NucleusUIMotion.create_tween(
		self,
		motion,
	).set_parallel(true)

	_transition_tween.tween_property(
		previous_control,
		"modulate:a",
		0.0,
		duration,
	)
	_transition_tween.tween_property(
		next_control,
		"modulate:a",
		_get_base_alpha(next_control),
		duration,
	)

	_transition_tween.finished.connect(
		_finish_transition.bind(
			previous_index,
			index,
		),
		CONNECT_ONE_SHOT,
	)

	return OK


func show_page_by_name(
	page_name: StringName,
	animated: bool = true,
) -> Error:
	for index: int in range(pages.size()):
		var page: Control = pages[index]

		if page and StringName(page.name) == page_name:
			return show_page(index, animated)

	return ERR_DOES_NOT_EXIST


func next_page(animated: bool = true) -> Error:
	if pages.is_empty():
		return ERR_DOES_NOT_EXIST

	return show_page(
		mini(current_index + 1, pages.size() - 1),
		animated,
	)


func previous_page(animated: bool = true) -> Error:
	if pages.is_empty():
		return ERR_DOES_NOT_EXIST

	return show_page(
		maxi(current_index - 1, 0),
		animated,
	)


func _show_immediately(index: int) -> void:
	for page_index: int in range(pages.size()):
		var page: Control = pages[page_index]

		if page == null:
			continue

		page.modulate.a = _get_base_alpha(page)
		page.visible = page_index == index

	current_index = index
	_update_tabs()
	_focus_current_page()

	page_changed.emit(
		current_index,
		pages[current_index],
	)


func _finish_transition(
	previous_index: int,
	next_index: int,
) -> void:
	_transition_tween = null

	if previous_index >= 0:
		var previous_control: Control = pages[previous_index]

		if previous_control:
			previous_control.hide()
			previous_control.modulate.a = _get_base_alpha(previous_control)

	current_index = next_index

	var next_control: Control = pages[current_index]
	next_control.modulate.a = _get_base_alpha(next_control)

	_update_tabs()
	_focus_current_page()

	page_changed.emit(current_index, next_control)


func _record_page_state() -> void:
	for page: Control in pages:
		if page:
			_base_alpha[page.get_instance_id()] = page.modulate.a


func _connect_tabs() -> void:
	var connected_count: int = mini(
		pages.size(),
		tab_buttons.size(),
	)

	for index: int in range(connected_count):
		var button: BaseButton = tab_buttons[index]

		if button:
			button.pressed.connect(
				_on_tab_pressed.bind(index)
			)


func _on_tab_pressed(index: int) -> void:
	show_page(index)


func _update_tabs() -> void:
	for index: int in range(tab_buttons.size()):
		var button: BaseButton = tab_buttons[index]

		if button == null or not button.toggle_mode:
			continue

		button.set_pressed_no_signal(index == current_index)


func _focus_current_page() -> void:
	if current_index < 0 or current_index >= pages.size():
		return

	var page: Control = pages[current_index]

	for node: Node in NucleusNodeUtils.descendants(page):
		if node is NucleusUIFocusScope:
			(node as NucleusUIFocusScope).call_deferred(
				"restore_focus"
			)
			return


func _get_base_alpha(page: Control) -> float:
	return float(
		_base_alpha.get(
			page.get_instance_id(),
			1.0,
		)
	)
