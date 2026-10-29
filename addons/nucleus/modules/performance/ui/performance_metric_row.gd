extends HBoxContainer
## Tabular presentation row for one subsystem metric.

const STATE_NONE: int = -1
const STATE_NORMAL: int = 0
const STATE_WARNING: int = 1
const STATE_CRITICAL: int = 2

const _COLOR_PRIMARY: Color = Color(0.88, 0.91, 0.95)
const _COLOR_MUTED: Color = Color(0.54, 0.60, 0.67)
const _COLOR_WARNING: Color = Color(0.96, 0.68, 0.24)
const _COLOR_CRITICAL: Color = Color(0.95, 0.33, 0.36)

@onready var _name_label: Label = %MetricName
@onready var _value_label: Label = %MetricValue
@onready var _budget_label: Label = %MetricBudget
@onready var _status_label: Label = %MetricStatus


func set_metric(
	metric_name: String,
	value: String,
	budget: String = "",
	state: int = STATE_NONE,
) -> void:
	_name_label.text = metric_name
	_value_label.text = value
	_budget_label.text = budget
	_budget_label.visible = not budget.is_empty()

	var color := _COLOR_PRIMARY
	_status_label.visible = state == STATE_WARNING or state == STATE_CRITICAL

	match state:
		STATE_WARNING:
			_status_label.text = "OVER"
			color = _COLOR_WARNING
		STATE_CRITICAL:
			_status_label.text = "CRIT"
			color = _COLOR_CRITICAL
		_:
			_status_label.text = ""

	_value_label.add_theme_color_override("font_color", color)
	_status_label.add_theme_color_override("font_color", color)
	_budget_label.add_theme_color_override("font_color", _COLOR_MUTED)
