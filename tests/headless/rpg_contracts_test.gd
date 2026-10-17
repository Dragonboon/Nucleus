extends "res://tests/headless/test_case.gd"

func run() -> Dictionary:
	_test_progression()
	_test_encounter()
	return finish()


func _test_progression() -> void:
	var definition := NucleusProgressionDefinition.new()
	definition.track_id = &"hero"
	definition.thresholds = PackedInt64Array([100, 250])
	var track := NucleusProgressionTrack.new()
	track.definition = definition
	var sword := NucleusUnlockDefinition.new()
	sword.unlock_id = &"sword"
	sword.max_rank = 2
	var magic := NucleusUnlockDefinition.new()
	magic.unlock_id = &"magic"
	magic.required_ranks = {"sword": 2}
	magic.minimum_level = 2
	var graph := NucleusUnlockGraph.new()
	graph.progression = track
	graph.initial_points = 3
	graph.definitions = [sword, magic]
	var root := Node.new()
	root.add_child(track)
	root.add_child(graph)
	expect_true(attach_test_node(root), "Progression fixture attaches.")
	expect_equal(track.grant_experience(100), OK, "Experience awarded.")
	expect_equal(track.level, 2, "Experience maps to level.")
	expect_equal(graph.can_unlock(&"magic"), ERR_UNAVAILABLE, "Prerequisite gates.")
	expect_equal(graph.unlock(&"sword"), OK, "First rank.")
	expect_equal(graph.unlock(&"sword"), OK, "Second rank.")
	expect_equal(graph.unlock(&"magic"), OK, "Dependent unlock.")
	expect_equal(graph.get_rank(&"magic"), 1, "Unlock recorded.")
	var snapshot: Dictionary = graph.capture_state()
	graph.reset_unlocks()
	expect_equal(graph.restore_state(snapshot), OK, "Unlock snapshot restored.")
	free_test_node(root)


func _test_encounter() -> void:
	var wave1 := NucleusEncounterWave.new()
	wave1.participant_ids = [&"goblin"]
	wave1.counts = PackedInt32Array([2])
	var wave2 := NucleusEncounterWave.new()
	wave2.participant_ids = [&"boss"]
	wave2.counts = PackedInt32Array([1])
	var definition := NucleusEncounterDefinition.new()
	definition.encounter_id = &"cave"
	definition.waves = [wave1, wave2]
	var director := NucleusEncounterDirector.new()
	director.definition = definition
	expect_equal(director.start_encounter(), OK, "Encounter begins.")
	expect_equal(director.get_remaining().get(&"goblin"), 2, "First wave count.")
	expect_equal(director.mark_defeated(&"goblin", 2), OK, "First wave cleared.")
	expect_equal(director.wave_index, 1, "Second wave activated.")
	expect_equal(director.mark_defeated(&"boss"), OK, "Boss defeated.")
	expect_false(director.running, "Encounter completes.")
	director.free()
