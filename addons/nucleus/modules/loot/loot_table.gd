class_name NucleusLootTable
extends Resource
## Reusable, immutable-by-convention loot-table configuration.
##
## Godot's RandomNumberGenerator owns probability mechanics. This Resource adds
## loot semantics without owning global state or mutating shared assets.

enum RollMode {
	WEIGHTED,
	INDEPENDENT_CHANCE,
}

@export var entries: Array[NucleusLootEntry] = []
@export var roll_mode: RollMode = RollMode.WEIGHTED

## Selection cycles. Zero allows a guaranteed-only table.
@export_range(0, 10000, 1, "or_greater")
var rolls: int = 1

## When false, a non-unique entry can still appear at most once per roll() call.
@export var allow_duplicate_entries: bool = false

## Zero means unlimited random results.
@export_range(0, 10000, 1, "or_greater")
var maximum_random_results: int = 0

## When enabled, guaranteed entries consume the random-result budget too.
@export var guaranteed_count_toward_limit: bool = false


func roll(
	rng: RandomNumberGenerator,
	state: NucleusLootState = null,
	context: Dictionary = {},
) -> Array[NucleusLootResult]:
	var results: Array[NucleusLootResult] = []

	if rng == null or not get_validation_errors().is_empty():
		return results

	var runtime_state: NucleusLootState = (
		state
		if state != null
		else NucleusLootState.new()
	)
	var selected_ids: Dictionary[StringName, bool] = {}
	var random_result_count: int = 0

	for entry: NucleusLootEntry in entries:
		if (
			entry == null
			or not entry.guaranteed
			or not entry.is_eligible(
				context,
				runtime_state,
			)
		):
			continue

		if (
			guaranteed_count_toward_limit
			and maximum_random_results > 0
			and random_result_count >= maximum_random_results
		):
			break

		_append_result(
			results,
			entry,
			rng,
			runtime_state,
			selected_ids,
		)

		if guaranteed_count_toward_limit:
			random_result_count += 1

	if (
		maximum_random_results > 0
		and random_result_count >= maximum_random_results
	):
		return results

	match roll_mode:
		RollMode.WEIGHTED:
			_roll_weighted(
				results,
				rng,
				runtime_state,
				context,
				selected_ids,
				random_result_count,
			)

		RollMode.INDEPENDENT_CHANCE:
			_roll_independent(
				results,
				rng,
				runtime_state,
				context,
				selected_ids,
				random_result_count,
			)

	return results


func roll_seeded(
	seed_value: int,
	state: NucleusLootState = null,
	context: Dictionary = {},
) -> Array[NucleusLootResult]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	return roll(
		rng,
		state,
		context,
	)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var known_ids: Dictionary[StringName, bool] = {}

	for index: int in range(entries.size()):
		var entry: NucleusLootEntry = entries[index]

		if entry == null:
			errors.append("Loot entry %d is null." % index)
			continue

		for error: String in entry.get_validation_errors():
			errors.append(
				"Entry %d: %s" % [
					index,
					error,
				]
			)

		if entry.entry_id == &"":
			continue

		if known_ids.has(entry.entry_id):
			errors.append(
				"Duplicate entry_id '%s'." % entry.entry_id
			)
			continue

		known_ids[entry.entry_id] = true

	return errors


func _roll_weighted(
	results: Array[NucleusLootResult],
	rng: RandomNumberGenerator,
	state: NucleusLootState,
	context: Dictionary,
	selected_ids: Dictionary[StringName, bool],
	initial_result_count: int,
) -> void:
	var random_result_count: int = initial_result_count

	for _roll_index: int in range(maxi(0, rolls)):
		if _random_limit_reached(random_result_count):
			return

		var candidates: Array[NucleusLootEntry] = []
		var weights := PackedFloat32Array()

		for entry: NucleusLootEntry in entries:
			if not _is_random_candidate(
				entry,
				state,
				context,
				selected_ids,
			):
				continue

			if entry.weight <= 0.0:
				continue

			candidates.append(entry)
			weights.append(entry.weight)

		if candidates.is_empty():
			return

		var selected_index: int = rng.rand_weighted(weights)

		if selected_index < 0 or selected_index >= candidates.size():
			return

		_append_result(
			results,
			candidates[selected_index],
			rng,
			state,
			selected_ids,
		)
		random_result_count += 1


func _roll_independent(
	results: Array[NucleusLootResult],
	rng: RandomNumberGenerator,
	state: NucleusLootState,
	context: Dictionary,
	selected_ids: Dictionary[StringName, bool],
	initial_result_count: int,
) -> void:
	var random_result_count: int = initial_result_count

	for _roll_index: int in range(maxi(0, rolls)):
		for entry: NucleusLootEntry in entries:
			if _random_limit_reached(random_result_count):
				return

			if not _is_random_candidate(
				entry,
				state,
				context,
				selected_ids,
			):
				continue

			if not _roll_chance(
				rng,
				entry.chance,
			):
				continue

			_append_result(
				results,
				entry,
				rng,
				state,
				selected_ids,
			)
			random_result_count += 1


func _is_random_candidate(
	entry: NucleusLootEntry,
	state: NucleusLootState,
	context: Dictionary,
	selected_ids: Dictionary[StringName, bool],
) -> bool:
	if (
		entry == null
		or entry.guaranteed
		or not entry.is_eligible(
			context,
			state,
		)
	):
		return false

	if (
		not allow_duplicate_entries
		and selected_ids.has(entry.entry_id)
	):
		return false

	return true


func _append_result(
	results: Array[NucleusLootResult],
	entry: NucleusLootEntry,
	rng: RandomNumberGenerator,
	state: NucleusLootState,
	selected_ids: Dictionary[StringName, bool],
) -> void:
	results.append(
		NucleusLootResult.new(
			entry,
			entry.roll_amount(rng),
		)
	)
	selected_ids[entry.entry_id] = true

	if entry.unique:
		state.mark_consumed(entry.entry_id)


func _roll_chance(
	rng: RandomNumberGenerator,
	probability: float,
) -> bool:
	var normalized: float = clampf(
		probability,
		0.0,
		1.0,
	)

	if normalized <= 0.0:
		return false

	if normalized >= 1.0:
		return true

	return rng.randf() < normalized


func _random_limit_reached(result_count: int) -> bool:
	return (
		maximum_random_results > 0
		and result_count >= maximum_random_results
	)
