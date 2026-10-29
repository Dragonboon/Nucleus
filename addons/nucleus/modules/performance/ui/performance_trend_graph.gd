extends Control
## Lightweight sparkline for recent frame-pacing windows.

const _COLOR_P50: Color = Color(0.45, 0.70, 0.95, 0.85)
const _COLOR_P95: Color = Color(0.30, 0.80, 0.54, 1.0)
const _COLOR_MAX: Color = Color(0.70, 0.74, 0.80, 0.55)
const _COLOR_TARGET: Color = Color(0.50, 0.56, 0.64, 0.50)
const _COLOR_WARNING: Color = Color(0.96, 0.68, 0.24, 0.55)
const _COLOR_CRITICAL: Color = Color(0.95, 0.33, 0.36, 0.55)

var _p50 := PackedFloat64Array()
var _p95 := PackedFloat64Array()
var _maximum := PackedFloat64Array()
var _target_ms: float = 0.0
var _warning_ms: float = 0.0
var _critical_ms: float = 0.0


func set_series(
	p50: PackedFloat64Array,
	p95: PackedFloat64Array,
	maximum: PackedFloat64Array,
	target_ms: float,
	warning_ms: float,
	critical_ms: float,
) -> void:
	_p50 = p50.duplicate()
	_p95 = p95.duplicate()
	_maximum = maximum.duplicate()
	_target_ms = maxf(target_ms, 0.0)
	_warning_ms = maxf(warning_ms, _target_ms)
	_critical_ms = maxf(critical_ms, _warning_ms)
	queue_redraw()


func clear_series() -> void:
	_p50.clear()
	_p95.clear()
	_maximum.clear()
	queue_redraw()


func _draw() -> void:
	if size.x <= 8.0 or size.y <= 8.0:
		return

	var plot := Rect2(4.0, 4.0, size.x - 8.0, size.y - 8.0)
	var ceiling := _graph_ceiling()
	if ceiling <= 0.0:
		return

	_draw_guide(plot, _target_ms, ceiling, _COLOR_TARGET)
	_draw_guide(plot, _warning_ms, ceiling, _COLOR_WARNING)
	_draw_guide(plot, _critical_ms, ceiling, _COLOR_CRITICAL)
	_draw_series(plot, _maximum, ceiling, _COLOR_MAX, 1.0)
	_draw_series(plot, _p50, ceiling, _COLOR_P50, 1.5)
	_draw_series(plot, _p95, ceiling, _COLOR_P95, 2.0)


func _graph_ceiling() -> float:
	var result := maxf(_critical_ms * 1.10, _target_ms * 2.25)
	for value: float in _p50:
		result = maxf(result, value * 1.10)
	for value: float in _p95:
		result = maxf(result, value * 1.10)
	return result


func _draw_guide(
	plot: Rect2,
	value: float,
	ceiling: float,
	color: Color,
) -> void:
	if value <= 0.0:
		return

	var y := _value_to_y(plot, value, ceiling)
	draw_line(
		Vector2(plot.position.x, y),
		Vector2(plot.end.x, y),
		color,
		1.0,
		true,
	)


func _draw_series(
	plot: Rect2,
	values: PackedFloat64Array,
	ceiling: float,
	color: Color,
	width: float,
) -> void:
	if values.size() < 2:
		return

	var points := PackedVector2Array()
	var denominator := float(maxi(values.size() - 1, 1))
	for index: int in range(values.size()):
		var ratio := float(index) / denominator
		points.append(
			Vector2(
				plot.position.x + plot.size.x * ratio,
				_value_to_y(plot, values[index], ceiling),
			)
		)

	draw_polyline(points, color, width, true)


func _value_to_y(plot: Rect2, value: float, ceiling: float) -> float:
	var ratio := clampf(value / maxf(ceiling, 0.001), 0.0, 1.0)
	return plot.end.y - plot.size.y * ratio
