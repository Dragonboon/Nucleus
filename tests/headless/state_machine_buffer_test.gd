extends "res://tests/headless/test_case.gd"

class BlockingState:
	extends NucleusState
	var blocked: bool = false
	var allowed: bool = true
	var entries: int = 0
	var exits: int = 0
	var requested_on_enter: StringName = &""

	func can_exit(_next: NucleusState, _context: Dictionary) -> bool:
		return not blocked

	func can_enter(_prev: NucleusState, _context: Dictionary) -> bool:
		return allowed

	func enter(_previous: NucleusState, _context: Dictionary) -> void:
		entries += 1
		if requested_on_enter != &"":
			request_deferred_transition(requested_on_enter)

	func exit(_next: NucleusState) -> void:
		exits += 1


func run() -> Dictionary:
	_test_buffered_and_reentrant()
	_test_restore_atomicity()
	return finish()


func _create_fixture() -> Dictionary:
	var root := Node.new()
	var machine := NucleusStateMachine.new()
	var first := BlockingState.new()
	var second := BlockingState.new()
	var third := BlockingState.new()
	first.name = "Idle"
	second.name = "Attack"
	third.name = "Jump"
	root.add_child(machine)
	machine.add_child(first)
	machine.add_child(second)
	machine.add_child(third)
	machine.initial_state = first
	var policy := NucleusStateTransitionPolicy.new()
	policy.capacity = 2
	policy.replace_latest = false
	machine.transition_policy = policy
	attach_test_node(root)
	return {"root": root, "machine": machine, "idle": first,
		"attack": second, "jump": third}


func _test_buffered_and_reentrant() -> void:
	var fixture := _create_fixture()
	var machine: NucleusStateMachine = fixture["machine"]
	var idle: BlockingState = fixture["idle"]
	var attack: BlockingState = fixture["attack"]
	var jump: BlockingState = fixture["jump"]
	expect_true(idle.get_actor() == fixture["root"], "Actor resolves to machine parent.")
	idle.blocked = true
	var context := {"damage": 4}
	expect_equal(machine.request_state(&"Attack", context), OK, "Locked request queued.")
	context["damage"] = 99
	expect_equal(machine.get_pending_request_count(), 1, "One buffered request.")
	expect_false(machine.process_pending_request(), "Lock cannot prematurely exit.")
	expect_equal(idle.exits, 0, "No premature exit.")
	idle.blocked = false
	expect_true(machine.process_pending_request(), "Unlock commits buffered request.")
	expect_equal(attack.entries, 1, "Transition executes exactly once.")
	expect_equal(machine.get_pending_request_count(), 0, "Request consumed.")
	expect_equal(machine.restart_state(), OK, "Explicit restart succeeds.")
	expect_equal(attack.entries, 2, "Restart re-enters active state.")
	expect_equal(machine.get_history(), [&"Idle"], "Restart does not duplicate history.")
	attack.blocked = true
	expect_equal(machine.request_state(&"Idle"), OK, "Buffer second transition.")
	expect_equal(machine.request_state(&"Jump"), OK, "Buffer within capacity.")
	expect_equal(machine.request_state(&"Attack"), ERR_BUSY, "Queue capacity enforced.")
	machine.set_active(false)
	expect_equal(machine.get_pending_request_count(), 0, "Disable cancels requests.")
	machine.set_active(true)
	attack.blocked = false
	attack.requested_on_enter = &"Jump"
	expect_equal(machine.restart_state(), OK, "Reentrant request during enter is queued.")
	expect_equal(machine.get_pending_request_count(), 1, "Reentrant request retained.")
	expect_true(machine.process_pending_request(), "Reentrant request executes later.")
	expect_true(machine.current_state == jump, "Requested target reached.")
	free_test_node(fixture["root"])


func _test_restore_atomicity() -> void:
	var fixture := _create_fixture()
	var machine: NucleusStateMachine = fixture["machine"]
	var attack: BlockingState = fixture["attack"]
	expect_equal(machine.change_state(&"Attack"), OK, "Initial transition.")
	var before: Array[StringName] = machine.get_history()
	attack.blocked = true
	var snapshot := {"current_state": "Idle", "history": [&"Jump"]}
	expect_equal(machine.restore_state(snapshot), ERR_UNAVAILABLE, "Restore rejected.")
	expect_equal(machine.get_history(), before, "Rejected restore keeps history.")
	expect_true(machine.current_state == attack, "Rejected restore keeps state.")
	attack.blocked = false
	expect_equal(machine.restore_state(snapshot), OK, "Valid restore.")
	expect_equal(machine.get_history(), [&"Jump"], "Valid restore commits history.")
	free_test_node(fixture["root"])
