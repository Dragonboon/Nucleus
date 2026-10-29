@tool
class_name NucleusLootRoller
extends Node
## Scene-owned runtime owner for RNG and unique-loot state.

signal generated(results: Array[NucleusLootResult])

enum SeedMode {
	RANDOMIZED,
	FIXED,
}

@export var table: NucleusLootTable:
	set(value):
		table = value
		update_configuration_warnings()

@export var seed_mode: SeedMode = SeedMode.RANDOMIZED
@export var fixed_seed: int = 0

var _rng := RandomNumberGenerator.new()
var _loot_state := NucleusLootState.new()
var _rng_initialized: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_initialize_rng()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if table == null:
		warnings.append("Assign a NucleusLootTable.")
		return warnings

	warnings.append_array(table.get_validation_errors())
	return warnings


func generate(
	context: Dictionary = {},
) -> Array[NucleusLootResult]:
	var results: Array[NucleusLootResult] = []

	if table == null:
		return results

	_ensure_rng_initialized()
	results = table.roll(
		_rng,
		_loot_state,
		context,
	)
	generated.emit(results)
	return results


func reseed(seed_value: int) -> void:
	_rng.seed = seed_value
	_rng_initialized = true


func reset_unique_state() -> void:
	_loot_state.clear()


func reset_runtime_state(
	reset_rng: bool = false,
) -> void:
	reset_unique_state()

	if reset_rng:
		_rng_initialized = false
		_initialize_rng()


func get_loot_state() -> NucleusLootState:
	return _loot_state


func capture_state() -> Dictionary:
	_ensure_rng_initialized()

	return {
		"rng_seed": _rng.seed,
		"rng_state": _rng.state,
		"loot_state": _loot_state.capture_state(),
	}


func restore_state(data: Dictionary) -> void:
	var seed_value: int = int(
		data.get(
			"rng_seed",
			fixed_seed,
		)
	)
	_rng.seed = seed_value

	if data.has("rng_state"):
		_rng.state = int(data["rng_state"])

	var loot_state_value: Variant = data.get(
		"loot_state",
		{},
	)

	if loot_state_value is Dictionary:
		_loot_state.restore_state(
			loot_state_value as Dictionary
		)
	else:
		_loot_state.clear()

	_rng_initialized = true


func _ensure_rng_initialized() -> void:
	if not _rng_initialized:
		_initialize_rng()


func _initialize_rng() -> void:
	match seed_mode:
		SeedMode.FIXED:
			_rng.seed = fixed_seed

		SeedMode.RANDOMIZED:
			_rng.randomize()

	_rng_initialized = true
