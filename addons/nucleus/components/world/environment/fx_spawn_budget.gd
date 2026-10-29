class_name NucleusFxSpawnBudget
extends RefCounted
## Bounded accumulator for sparse secondary FX work.
##
## The budget converts a rate into an integer count while retaining fractional
## progress. Backlog is capped so a slow frame cannot create an unbounded burst.

var max_events_per_frame: int = 4
var max_backlog_events: float = 4.0

var _accumulator: float = 0.0


func _init(
	per_frame_limit: int = 4,
	backlog_limit: float = 4.0,
) -> void:
	configure(
		per_frame_limit,
		backlog_limit,
	)


func configure(
	per_frame_limit: int,
	backlog_limit: float,
) -> void:
	max_events_per_frame = maxi(per_frame_limit, 0)
	max_backlog_events = maxf(backlog_limit, 0.0)
	_accumulator = minf(
		_accumulator,
		max_backlog_events,
	)


func advance(
	delta: float,
	events_per_second: float,
	intensity: float = 1.0,
	rate_scale: float = 1.0,
) -> int:
	if delta <= 0.0:
		return 0

	if max_events_per_frame <= 0 or max_backlog_events <= 0.0:
		_accumulator = 0.0
		return 0

	var effective_rate := (
		maxf(events_per_second, 0.0)
		* clampf(intensity, 0.0, 1.0)
		* maxf(rate_scale, 0.0)
	)

	if effective_rate <= 0.0:
		_accumulator = 0.0
		return 0

	_accumulator = minf(
		_accumulator + effective_rate * delta,
		max_backlog_events,
	)

	var count := mini(
		int(floor(_accumulator)),
		max_events_per_frame,
	)
	_accumulator -= float(count)
	return count


func reset() -> void:
	_accumulator = 0.0


func get_pending_events() -> float:
	return _accumulator
