extends PanelContainer
## Compact summary card for one high-priority performance metric.

const STATE_NONE: int = -1
const STATE_NORMAL: int = 0
const STATE_WARNING: int = 1
const STATE_CRITICAL: int = 2

const _COLOR_PRIMARY: Color = Color(0.92, 0.95, 0.98)
const _COLOR_MUTED: Color = Color(0.60, 0.66, 0.73)
const _COLOR_NORMAL: Color = Color(0.30, 0.80, 0.54)
const _COLOR_WARNING: Color = Color(0.96, 0.68, 0.24)
const _COLOR_CRITICAL: Color = Color(0.95, 0.33, 0.36)

@onready var _title_label: Label = %Title
@onready var _status_label: Label = %Status
@onready var _value_label: Label = %Value
@onready var _detail_label: Label = %Detail
@onready var _budget_bar: ProgressBar = %BudgetBar

var _fill_styles: Dictionary = {}


func _ready() -> void:
	_fill_styles = {
		STATE_NORMAL: _build_fill_style(_COLOR_NORMAL),
		STATE_WARNING: _build_fill_style(_COLOR_WARNING),
		STATE_CRITICAL: _build_fill_style(_COLOR_CRITICAL),
	}


func set_metric(
	title: String,
	value: String,
	detail: String = "",
	budget_ratio: float = -1.0,
	state: int = STATE_NONE,
) -> void:
	_title_label.text = title
	_value_label.text = value
	_detail_label.text = detail
	_detail_label.visible = not detail.is_empty()

	_budget_bar.visible = budget_ratio >= 0.0
	if _budget_bar.visible:
		_budget_bar.value = clampf(budget_ratio, 0.0, 1.0)

	_apply_state(state)


func _apply_state(state: int) -> void:
	var color := _COLOR_PRIMARY
	_status_label.visible = state != STATE_NONE

	match state:
		STATE_NORMAL:
			_status_label.text = "OK"
			color = _COLOR_NORMAL
		STATE_WARNING:
			_status_label.text = "WARN"
			color = _COLOR_WARNING
		STATE_CRITICAL:
			_status_label.text = "CRITICAL"
			color = _COLOR_CRITICAL
		_:
			_status_label.text = ""

	_value_label.add_theme_color_override("font_color", color)
	_status_label.add_theme_color_override("font_color", color)

	if _budget_bar.visible:
		var style_state := state
		if not _fill_styles.has(style_state):
			style_state = STATE_NORMAL
		_budget_bar.add_theme_stylebox_override(
			"fill",
			_fill_styles[style_state],
		)

	if state == STATE_NONE:
		_detail_label.add_theme_color_override("font_color", _COLOR_MUTED)


func _build_fill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style
