class_name NucleusUIToastHost
extends CanvasLayer
## Scene-owned toast queue with bounded visible items and deduplication.
##
## Generated nodes use Theme type variations so projects can restyle the
## default toast without replacing queue logic.

signal toast_shown(request: NucleusUIToastRequest)
signal toast_hidden(request: NucleusUIToastRequest)
signal queue_changed(
	pending_count: int,
	visible_count: int,
)

enum Placement {
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT,
}

@export var placement: Placement = Placement.TOP_RIGHT
@export_range(1, 10, 1) var max_visible: int = 3
@export_range(160.0, 1000.0, 1.0) var toast_width: float = 340.0
@export_range(0.0, 200.0, 1.0) var screen_margin: float = 24.0
@export_range(0, 100, 1) var separation: int = 10

@export var motion: NucleusUIMotionProfile

var _pending: Array[NucleusUIToastRequest] = []
var _visible: Array[Dictionary] = []
var _next_order: int = 0

@onready var _container: VBoxContainer = $Root/ToastContainer


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	if motion == null:
		motion = NucleusUIMotionProfile.new()
		motion.duration = 0.16

	_container.add_theme_constant_override(
		&"separation",
		separation,
	)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


func enqueue(
	message: String,
	title: String = "",
	duration: float = 3.0,
	dedupe_key: StringName = &"",
	priority: int = 0,
) -> Error:
	if message.is_empty():
		return ERR_INVALID_PARAMETER

	var request := NucleusUIToastRequest.new(
		message,
		title,
		duration,
		dedupe_key,
		priority,
	)

	return enqueue_request(request)


func enqueue_request(request: NucleusUIToastRequest) -> Error:
	if request == null or request.message.is_empty():
		return ERR_INVALID_PARAMETER

	if (
		request.dedupe_key != &""
		and _contains_dedupe_key(request.dedupe_key)
	):
		return ERR_ALREADY_EXISTS

	request.order = _next_order
	_next_order += 1

	_pending.append(request)
	_pending.sort_custom(_sort_requests)

	_pump_queue()
	_emit_queue_changed()

	return OK


func dismiss_by_key(dedupe_key: StringName) -> bool:
	if dedupe_key == &"":
		return false

	for index: int in range(_pending.size() - 1, -1, -1):
		if _pending[index].dedupe_key == dedupe_key:
			_pending.remove_at(index)
			_emit_queue_changed()
			return true

	for entry: Dictionary in _visible.duplicate():
		var request: NucleusUIToastRequest = entry["request"]

		if request.dedupe_key == dedupe_key:
			_dismiss_panel(entry["panel"])
			return true

	return false


func clear() -> void:
	_pending.clear()

	for entry: Dictionary in _visible.duplicate():
		var panel: PanelContainer = entry["panel"]
		var timer: Timer = entry["timer"]

		if is_instance_valid(timer):
			timer.stop()

		if is_instance_valid(panel):
			panel.queue_free()

	_visible.clear()
	_emit_queue_changed()


func _pump_queue() -> void:
	while (
		_visible.size() < max_visible
		and not _pending.is_empty()
	):
		_show_request(_pending.pop_front())


func _show_request(request: NucleusUIToastRequest) -> void:
	var panel: PanelContainer = _create_toast_control(request)
	_container.add_child(panel)

	var timer := Timer.new()
	timer.one_shot = true
	timer.ignore_time_scale = true
	timer.wait_time = request.duration
	panel.add_child(timer)

	var entry: Dictionary = {
		"request": request,
		"panel": panel,
		"timer": timer,
	}
	_visible.append(entry)

	timer.timeout.connect(
		_dismiss_panel.bind(panel),
		CONNECT_ONE_SHOT,
	)
	timer.start()

	call_deferred("_animate_panel_in", panel)

	toast_shown.emit(request)
	_emit_queue_changed()


func _animate_panel_in(panel: PanelContainer) -> void:
	if not is_instance_valid(panel):
		return

	NucleusUIMotion.pop(
		panel,
		motion,
		Vector2(0.96, 0.96),
	)


func _dismiss_panel(panel: PanelContainer) -> void:
	var entry_index: int = _find_visible_panel(panel)

	if entry_index == -1:
		return

	var entry: Dictionary = _visible[entry_index]
	var request: NucleusUIToastRequest = entry["request"]

	_visible.remove_at(entry_index)

	var tween: Tween = NucleusUIMotion.fade_to(
		panel,
		0.0,
		motion,
	)
	tween.finished.connect(
		_finalize_panel.bind(panel, request),
		CONNECT_ONE_SHOT,
	)

	_emit_queue_changed()


func _finalize_panel(
	panel: PanelContainer,
	request: NucleusUIToastRequest,
) -> void:
	if is_instance_valid(panel):
		panel.queue_free()

	toast_hidden.emit(request)
	_pump_queue()
	_emit_queue_changed()


func _create_toast_control(
	request: NucleusUIToastRequest,
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"NucleusToast"
	panel.custom_minimum_size.x = toast_width
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.accessibility_name = request.title
	panel.accessibility_description = request.message

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 14)
	margin.add_theme_constant_override(&"margin_top", 12)
	margin.add_theme_constant_override(&"margin_right", 14)
	margin.add_theme_constant_override(&"margin_bottom", 12)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 4)
	margin.add_child(content)

	if not request.title.is_empty():
		var title := Label.new()
		title.theme_type_variation = &"NucleusToastTitle"
		title.text = request.title
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(title)

	var message := Label.new()
	message.theme_type_variation = &"NucleusToastMessage"
	message.text = request.message
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message)

	return panel


func _contains_dedupe_key(dedupe_key: StringName) -> bool:
	for request: NucleusUIToastRequest in _pending:
		if request.dedupe_key == dedupe_key:
			return true

	for entry: Dictionary in _visible:
		var request: NucleusUIToastRequest = entry["request"]

		if request.dedupe_key == dedupe_key:
			return true

	return false


func _find_visible_panel(panel: PanelContainer) -> int:
	for index: int in range(_visible.size()):
		if _visible[index]["panel"] == panel:
			return index

	return -1


func _sort_requests(
	left: NucleusUIToastRequest,
	right: NucleusUIToastRequest,
) -> bool:
	if left.priority == right.priority:
		return left.order < right.order

	return left.priority > right.priority


func _apply_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var available_height: float = maxf(
		0.0,
		viewport_size.y - screen_margin * 2.0,
	)

	_container.size = Vector2(
		toast_width,
		available_height,
	)
	_container.position.y = screen_margin

	match placement:
		Placement.TOP_LEFT:
			_container.position.x = screen_margin
			_container.alignment = BoxContainer.ALIGNMENT_BEGIN

		Placement.TOP_RIGHT:
			_container.position.x = (
				viewport_size.x
				- toast_width
				- screen_margin
			)
			_container.alignment = BoxContainer.ALIGNMENT_BEGIN

		Placement.BOTTOM_LEFT:
			_container.position.x = screen_margin
			_container.alignment = BoxContainer.ALIGNMENT_END

		Placement.BOTTOM_RIGHT:
			_container.position.x = (
				viewport_size.x
				- toast_width
				- screen_margin
			)
			_container.alignment = BoxContainer.ALIGNMENT_END


func _emit_queue_changed() -> void:
	queue_changed.emit(
		_pending.size(),
		_visible.size(),
	)
