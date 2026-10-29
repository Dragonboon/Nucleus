class_name NucleusTimeUtils
extends RefCounted
## Stateless formatting helpers around Godot's Time API.

const MICROSECONDS_PER_SECOND: float = 1_000_000.0


## Returns monotonic engine uptime in seconds.
static func ticks_seconds() -> float:
	return (
		Time.get_ticks_usec()
		/ MICROSECONDS_PER_SECOND
	)


## Formats a duration as MM:SS or HH:MM:SS.
##
## When [param include_milliseconds] is true, exactly three millisecond digits
## are appended. Negative values keep their sign.
static func format_duration(
	seconds: float,
	include_milliseconds: bool = false,
	always_show_hours: bool = false,
) -> String:
	var negative: bool = seconds < 0.0
	var total_milliseconds: int = roundi(
		absf(seconds) * 1000.0
	)

	var hours: int = floori(
		total_milliseconds / 3_600_000.0
	)
	var minutes: int = floori(
		(total_milliseconds % 3_600_000) / 60_000.0
	)
	var remaining_seconds: int = floori(
		(total_milliseconds % 60_000) / 1000.0
	)
	var milliseconds: int = total_milliseconds % 1000

	var result: String

	if always_show_hours or hours > 0:
		result = "%02d:%02d:%02d" % [
			hours,
			minutes,
			remaining_seconds,
		]
	else:
		result = "%02d:%02d" % [
			minutes,
			remaining_seconds,
		]

	if include_milliseconds:
		result += ".%03d" % milliseconds

	return ("-" + result) if negative else result
