extends "res://tests/headless/test_case.gd"

func run() -> Dictionary:
	_test_serial_blocks_and_timeout()
	_test_initiative_and_simultaneous()
	_test_validation()
	return finish()


func _fixture() -> Dictionary:
	var root := Node.new()
	var session := NucleusTurnSession.new()
	session.automatic_clock = false
	var seats: Array[NucleusTurnParticipant] = []
	root.add_child(session)
	for id: StringName in [&"a", &"b", &"c"]:
		var seat := NucleusTurnParticipant.new()
		seat.participant_id = id
		root.add_child(seat)
		seats.append(seat)
	expect_true(attach_test_node(root), "Turn fixture attached.")
	return {"root": root, "session": session, "seats": seats}


func _test_serial_blocks_and_timeout() -> void:
	var fixture := _fixture()
	var session: NucleusTurnSession = fixture["session"]
	var seats: Array[NucleusTurnParticipant] = fixture["seats"]
	var starts: Array[StringName] = []
	var ends: Array[StringName] = []
	session.turn_started.connect(
		func(seat: NucleusTurnParticipant, _round: int) -> void:
			starts.append(seat.participant_id)
	)
	session.session_ended.connect(
		func(reason: StringName, _turns: int) -> void:
			ends.append(reason)
	)
	session.maximum_turns = 4
	session.default_turn_seconds = 2.0
	expect_equal(seats[1].block_turns(1), OK, "Block a future opportunity.")
	expect_equal(session.start_session(seats), OK, "Serial session begins.")
	expect_equal(starts, [&"a"], "First participant starts.")
	expect_equal(session.advance(1.0), OK, "Manual clock accepts delta.")
	expect_float(session.get_remaining_seconds(seats[0]), 1.0,
		"Clock advances by one second.")
	expect_equal(session.advance(1.0), OK, "Timeout advances queue.")
	expect_equal(starts, [&"a", &"c"], "Blocked seat skipped.")
	expect_equal(seats[1].blocked_opportunities, 0, "Block consumed.")
	expect_equal(seats[2].end_turn(), OK, "Third seat completes.")
	expect_equal(starts, [&"a", &"c", &"a"], "Second round begins.")
	expect_equal(session.round_number, 2, "Round counter increments.")
	expect_equal(seats[0].end_turn(), OK, "Limit closes session.")
	expect_equal(ends, [&"maximum_turns"], "Max turns ends session once.")
	expect_false(session.running, "No session remains active.")
	expect_true(seats[0].get_session() == null, "Seats are detached.")
	free_test_node(fixture["root"])


func _test_initiative_and_simultaneous() -> void:
	var fixture := _fixture()
	var session: NucleusTurnSession = fixture["session"]
	var seats: Array[NucleusTurnParticipant] = fixture["seats"]
	seats[0].initiative = 1
	seats[1].initiative = 9
	seats[2].initiative = 5
	session.mode = NucleusTurnSession.Mode.INITIATIVE
	expect_equal(session.start_session(seats), OK, "Initiative starts.")
	expect_true(session.get_current_participant() == seats[1],
		"Highest initiative has first turn.")
	expect_equal(session.complete_turn(seats[1]), OK, "First seat ends.")
	expect_true(session.get_current_participant() == seats[2],
		"Next initiative is selected.")
	session.end_session()
	session.mode = NucleusTurnSession.Mode.SIMULTANEOUS
	session.maximum_turns = 3
	var starts: Array[StringName] = []
	session.turn_started.connect(
		func(seat: NucleusTurnParticipant, _round: int) -> void:
			starts.append(seat.participant_id)
	)
	expect_equal(session.start_session(seats), OK, "Simultaneous starts.")
	expect_equal(session.get_active_participants().size(), 3,
		"All seats become active in parallel.")
	expect_equal(starts, [&"a", &"b", &"c"],
		"Simultaneous mode preserves authored order.")
	expect_equal(seats[0].end_turn(), OK, "First seat completes.")
	expect_equal(session.round_number, 1, "Round not advanced early.")
	expect_equal(seats[1].skip_turn(), OK, "Second seat skips.")
	expect_equal(seats[2].end_turn(), OK, "Last seat completes.")
	expect_false(session.running, "Turn budget ends parallel session.")
	free_test_node(fixture["root"])


func _test_validation() -> void:
	var fixture := _fixture()
	var session: NucleusTurnSession = fixture["session"]
	var seats: Array[NucleusTurnParticipant] = fixture["seats"]
	var invalid: Array[NucleusTurnParticipant] = [seats[0], seats[0]]
	expect_equal(session.start_session(invalid), ERR_INVALID_DATA,
		"Duplicate participants rejected.")
	expect_equal(session.advance(-1.0), ERR_INVALID_PARAMETER,
		"Negative clock rejected.")
	session.default_turn_seconds = 0.0
	expect_equal(session.start_session(seats), OK,
		"Indefinite session allowed.")
	session.set_paused(true)
	expect_equal(session.advance(1.0), ERR_UNAVAILABLE,
		"Paused session ignores time.")
	expect_equal(session.complete_turn(seats[1]), ERR_UNAVAILABLE,
		"Inactive participant cannot end another turn.")
	session.end_session()
	free_test_node(fixture["root"])
