@tool
class_name NucleusDeterministicSchedule
extends Resource
## Fixed-duration deterministic schedule derived from absolute simulation time.
##
## The schedule provides stable segment seeds and transition timing. It does not
## define weather, encounters, shops, music, or any other game-specific state.

const SEED_ALGORITHM_VERSION: int = 1
const _SEED_MODULUS: int = 2147483646

@export var seed: int = 1
@export var seed_salt: int = 0

@export_range(0.001, 31536000.0, 0.001, "or_greater")
var segment_duration_seconds: float = 21600.0

@export_range(0.0, 31536000.0, 0.001, "or_greater")
var transition_duration_seconds: float = 1800.0


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if segment_duration_seconds <= 0.0:
		errors.append("segment_duration_seconds must be greater than zero")

	if transition_duration_seconds < 0.0:
		errors.append("transition_duration_seconds cannot be negative")

	if transition_duration_seconds > segment_duration_seconds:
		errors.append(
			"transition_duration_seconds cannot exceed segment duration"
		)

	return errors


func get_segment_index(total_seconds: float) -> int:
	if segment_duration_seconds <= 0.0:
		return 0

	return int(
		floor(
			maxf(total_seconds, 0.0)
			/ segment_duration_seconds
		)
	)


func get_previous_segment_index(total_seconds: float) -> int:
	return get_segment_index(total_seconds) - 1


func get_segment_start_seconds(segment_index: int) -> float:
	return (
		float(segment_index)
		* maxf(segment_duration_seconds, 0.0)
	)


func get_segment_local_seconds(total_seconds: float) -> float:
	if segment_duration_seconds <= 0.0:
		return 0.0

	return fposmod(
		maxf(total_seconds, 0.0),
		segment_duration_seconds,
	)


func get_segment_progress(total_seconds: float) -> float:
	if segment_duration_seconds <= 0.0:
		return 0.0

	return clampf(
		get_segment_local_seconds(total_seconds)
		/ segment_duration_seconds,
		0.0,
		1.0,
	)


func get_transition_alpha(total_seconds: float) -> float:
	var transition := minf(
		maxf(transition_duration_seconds, 0.0),
		maxf(segment_duration_seconds, 0.0),
	)

	if transition <= 0.0:
		return 1.0

	return smoothstep(
		0.0,
		transition,
		get_segment_local_seconds(total_seconds),
	)


func get_segment_seed(
	segment_index: int,
	stream: int = 0,
) -> int:
	var value := posmod(seed, _SEED_MODULUS)
	value = posmod(
		value
		+ posmod(segment_index, _SEED_MODULUS) * 104729,
		_SEED_MODULUS,
	)
	value = posmod(
		value
		+ posmod(stream, _SEED_MODULUS) * 130363,
		_SEED_MODULUS,
	)
	value = posmod(
		value
		+ posmod(seed_salt, _SEED_MODULUS) * 42589,
		_SEED_MODULUS,
	)
	value = posmod(value * 48271 + 1, _SEED_MODULUS)
	value = posmod(value * 69621 + 17, _SEED_MODULUS)
	return value + 1


func create_rng(
	segment_index: int,
	stream: int = 0,
) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = get_segment_seed(segment_index, stream)
	return rng
