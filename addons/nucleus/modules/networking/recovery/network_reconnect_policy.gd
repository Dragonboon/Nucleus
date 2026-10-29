class_name NucleusNetworkReconnectPolicy
extends Resource
## Bounded client reconnect timing; does not own identity or gameplay state.

@export_range(1, 100, 1, "or_greater") var max_attempts: int = 6
@export_range(0.0, 30.0, 0.05, "or_greater") var initial_delay_seconds: float = 0.25
@export_range(1.0, 8.0, 0.1, "or_greater") var backoff_multiplier: float = 2.0
@export_range(0.0, 120.0, 0.05, "or_greater") var max_delay_seconds: float = 5.0
@export_range(0.1, 120.0, 0.1, "or_greater") var attempt_timeout_seconds: float = 5.0
@export_range(0.1, 120.0, 0.1, "or_greater") var restore_timeout_seconds: float = 6.0
@export_range(0.1, 600.0, 0.5, "or_greater") var total_timeout_seconds: float = 30.0


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if max_attempts < 1:
		errors.append("max_attempts must be positive")
	if initial_delay_seconds < 0.0:
		errors.append("initial_delay_seconds cannot be negative")
	if backoff_multiplier < 1.0:
		errors.append("backoff_multiplier must be at least 1")
	if max_delay_seconds < initial_delay_seconds:
		errors.append("max_delay_seconds must cover initial_delay_seconds")
	if attempt_timeout_seconds <= 0.0:
		errors.append("attempt_timeout_seconds must be positive")
	if restore_timeout_seconds <= 0.0:
		errors.append("restore_timeout_seconds must be positive")
	if total_timeout_seconds <= 0.0:
		errors.append("total_timeout_seconds must be positive")

	return errors


## One failed attempt produces the initial delay; the next doubles by default.
func delay_after_failure(failed_attempts: int) -> float:
	var exponent: int = maxi(failed_attempts - 1, 0)
	var delay: float = initial_delay_seconds * pow(
		backoff_multiplier,
		float(exponent),
	)
	return minf(delay, max_delay_seconds)
