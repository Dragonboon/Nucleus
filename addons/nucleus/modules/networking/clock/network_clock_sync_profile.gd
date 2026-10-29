class_name NucleusNetworkClockSyncProfile
extends Resource
## Bounds for client/server monotonic-clock observations.
## Reconfigure between sessions, not while a request is in flight.

@export_range(1, 64, 1) var max_pending_requests: int = 16
@export_range(1, 64, 1) var rtt_window_size: int = 8
@export_range(1.0, 60000.0, 1.0, "or_greater") var max_rtt_ms: float = 3000.0
@export_range(0.0, 10000.0, 1.0, "or_greater") var max_server_processing_ms: float = 1000.0
@export_range(0.0, 10000.0, 1.0, "or_greater") var outlier_tolerance_ms: float = 75.0
@export_range(0.01, 1.0, 0.01) var smoothing_factor: float = 0.25
@export_range(0.1, 3600.0, 0.1, "or_greater") var stale_after_seconds: float = 15.0
@export_range(0.1, 3600.0, 0.1, "or_greater") var request_timeout_seconds: float = 8.0


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if max_pending_requests < 1 or max_pending_requests > 64:
		errors.append("max_pending_requests must be between 1 and 64")
	if rtt_window_size < 1 or rtt_window_size > 64:
		errors.append("rtt_window_size must be between 1 and 64")
	if not is_finite(max_rtt_ms) or max_rtt_ms <= 0.0:
		errors.append("max_rtt_ms must be finite and positive")
	if not is_finite(max_server_processing_ms) or max_server_processing_ms < 0.0:
		errors.append("max_server_processing_ms must be finite and nonnegative")
	if not is_finite(outlier_tolerance_ms) or outlier_tolerance_ms < 0.0:
		errors.append("outlier_tolerance_ms must be finite and nonnegative")
	if not is_finite(smoothing_factor) or smoothing_factor <= 0.0 or smoothing_factor > 1.0:
		errors.append("smoothing_factor must be between 0 (exclusive) and 1")
	if not is_finite(stale_after_seconds) or stale_after_seconds <= 0.0:
		errors.append("stale_after_seconds must be finite and positive")
	if not is_finite(request_timeout_seconds) or request_timeout_seconds <= 0.0:
		errors.append("request_timeout_seconds must be finite and positive")

	return errors
