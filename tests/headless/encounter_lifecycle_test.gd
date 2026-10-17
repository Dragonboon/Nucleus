extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_instance_accounting_and_victory()
	_test_retreat_restore_and_reward()
	return finish()


func _make_definition() -> NucleusEncounterDefinition:
	var wave := NucleusEncounterWave.new()
	wave.participant_ids = [&"enemy"]
	wave.counts = PackedInt32Array([2])
	var definition := NucleusEncounterDefinition.new()
	definition.encounter_id = &"arena"
	definition.waves = [wave]
	return definition


func _test_instance_accounting_and_victory() -> void:
	var director := NucleusEncounterDirector.new()
	director.definition = _make_definition()
	var outcomes: Array[StringName] = []
	director.encounter_ended.connect(
		func(_id: StringName, result: StringName) -> void:
			outcomes.append(result)
	)
	expect_equal(director.start_encounter(), OK, "Encounter starts.")
	expect_equal(director.register_instance(&"one", &"enemy"), OK, "First instance.")
	expect_equal(director.register_instance(&"two", &"enemy"), OK, "Second instance.")
	expect_equal(director.register_instance(&"three", &"enemy"), ERR_UNAVAILABLE,
		"Cannot over-register the current wave.")
	expect_equal(director.mark_instance_defeated(&"one"), OK, "First defeated.")
	expect_equal(director.mark_instance_defeated(&"one"), ERR_DOES_NOT_EXIST,
		"Duplicate defeat rejected.")
	expect_equal(director.mark_instance_defeated(&"two"), OK, "Second defeated.")
	expect_equal(outcomes, [&"victory"], "Victory emitted exactly once.")
	expect_false(director.running, "Victory closes the encounter.")
	director.free()


func _test_retreat_restore_and_reward() -> void:
	var root := Node.new()
	var director := NucleusEncounterDirector.new()
	director.definition = _make_definition()
	var xp_def := NucleusProgressionDefinition.new()
	xp_def.track_id = &"hero"
	xp_def.thresholds = PackedInt64Array([10, 20])
	var track := NucleusProgressionTrack.new()
	track.definition = xp_def
	var reward := NucleusEncounterReward.new()
	reward.director = director
	reward.experience_track = track
	reward.experience = 10
	root.add_child(director)
	root.add_child(track)
	root.add_child(reward)
	expect_true(attach_test_node(root), "Reward fixture attaches.")
	expect_equal(director.start_encounter(), OK, "First start.")
	var snapshot: Dictionary = director.capture_state()
	snapshot["remaining"] = {"unknown": 1}
	expect_equal(director.restore_state(snapshot), ERR_BUSY,
		"Running state cannot be overwritten.")
	expect_equal(director.finish_encounter(&"retreat"), OK, "Retreat accepted.")
	expect_equal(track.experience, 0, "Retreat gives no XP.")
	expect_equal(director.start_encounter(), OK, "Restart after retreat.")
	expect_equal(director.mark_defeated(&"enemy", 2), OK, "Victory.")
	expect_equal(track.experience, 10, "Victory XP awarded once.")
	expect_equal(director.finish_encounter(&"victory"), ERR_INVALID_PARAMETER,
		"Second finish rejected.")
	var saved: Dictionary = director.capture_state()
	expect_equal(director.restore_state(saved), OK, "Stopped save restores.")
	free_test_node(root)
