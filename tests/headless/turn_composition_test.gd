extends "res://tests/headless/test_case.gd"


class CountEffect:
	extends NucleusActionEffect
	var applied: int = 0
	func apply(_context: Dictionary) -> Error:
		applied += 1
		return OK


func run() -> Dictionary:
	_test_turn_gated_actions()
	_test_turn_status_clock()
	return finish()


func _test_turn_gated_actions() -> void:
	var root := Node.new()
	var session := NucleusTurnSession.new()
	session.automatic_clock = false
	var first := NucleusTurnParticipant.new()
	first.participant_id = &"first"
	var second := NucleusTurnParticipant.new()
	second.participant_id = &"second"
	var action := NucleusGameplayAction.new()
	action.action_id = &"move"
	var requirement := NucleusTurnRequirement.new()
	requirement.session = session
	requirement.participant = first
	action.add_child(requirement)
	var counter := CountEffect.new()
	action.add_child(counter)
	var end_turn := NucleusFinishTurnEffect.new()
	end_turn.participant = first
	action.add_child(end_turn)
	root.add_child(session)
	root.add_child(first)
	root.add_child(second)
	root.add_child(action)
	expect_true(attach_test_node(root), "Turn action fixture attaches.")
	expect_equal(action.try_execute(), ERR_UNAVAILABLE,
		"No action before its turn.")
	expect_equal(session.start_session([first, second]), OK,
		"Turn session begins.")
	expect_equal(action.try_execute(), OK,
		"Action commits during active turn.")
	expect_equal(counter.applied, 1, "Action effect executes once.")
	expect_true(session.get_current_participant() == second,
		"Committed effect ends turn and advances.")
	expect_equal(action.try_execute(), ERR_UNAVAILABLE,
		"Former participant cannot act outside turn.")
	session.end_session()
	free_test_node(root)


func _test_turn_status_clock() -> void:
	var root := Node.new()
	var session := NucleusTurnSession.new()
	session.automatic_clock = false
	var first := NucleusTurnParticipant.new()
	first.participant_id = &"first"
	var second := NucleusTurnParticipant.new()
	second.participant_id = &"second"
	var container := NucleusStatusEffectContainer.new()
	var status := NucleusStatusEffectDefinition.new()
	status.effect_id = &"stun"
	status.duration_unit = NucleusStatusEffectDefinition.DurationUnit.TURNS
	status.duration = 2.0
	status.tick_interval = 1.0
	var binding := NucleusTurnStatusBinding.new()
	binding.session = session
	binding.participant = first
	binding.container = container
	root.add_child(session)
	root.add_child(first)
	root.add_child(second)
	root.add_child(container)
	root.add_child(binding)
	expect_true(attach_test_node(root), "Turn status fixture attaches.")
	var ticks: Array[StringName] = []
	container.effect_ticked.connect(
		func(active: NucleusActiveStatusEffect) -> void:
			ticks.append(active.get_effect_id())
	)
	expect_equal(container.apply_effect(status), OK,
		"Round-based status applies.")
	expect_equal(session.start_session([first, second]), OK,
		"Status turn session starts.")
	expect_equal(first.end_turn(), OK, "First opportunity completed.")
	expect_true(container.has_effect(&"stun"), "One turn remains.")
	expect_equal(ticks.size(), 1, "One tick on owner's first turn.")
	expect_equal(second.end_turn(), OK, "Second opportunity completed.")
	expect_equal(ticks.size(), 1, "Other actor does not tick owner status.")
	expect_equal(first.end_turn(), OK, "Second owner opportunity completed.")
	expect_false(container.has_effect(&"stun"),
		"Two-turn status expires after second opportunity.")
	expect_equal(ticks.size(), 2, "Ticks occur at each owner opportunity.")
	session.end_session()
	free_test_node(root)
