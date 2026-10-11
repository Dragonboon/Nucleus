extends "res://tests/headless/test_case.gd"


class ObservedSession extends NucleusSaveSession:
	var autosave_calls: int = 0

	func autosave(_force: bool = false) -> NucleusSaveResult:
		autosave_calls += 1
		return NucleusSaveResult.new()


func run() -> Dictionary:
	_test_scene_reentry()
	_test_stable_capture_set()
	return finish()


func _test_scene_reentry() -> void:
	var session := ObservedSession.new()
	session.autosave_policy = NucleusAutosavePolicy.new()
	session.autosave_policy.save_on_focus_lost = true
	expect_true(attach_test_node(session), "Save session enters the active scene.")
	var scene_parent: Node = session.get_parent()
	var first_timer: Timer = session.get_node("AutosaveTimer") as Timer
	NucleusApp.focus_changed.emit(false)
	expect_equal(session.autosave_calls, 1, "Active session receives lifecycle signals once.")
	scene_parent.remove_child(session)
	NucleusApp.focus_changed.emit(false)
	expect_equal(session.autosave_calls, 1, "Detached sessions do not autosave on app events.")
	expect_true(first_timer.is_stopped(), "Detaching stops the session's timer.")
	scene_parent.add_child(session)
	expect_equal(session.get_child_count(), 1, "Reentry reuses the single autosave timer.")
	expect_equal(session.get_node("AutosaveTimer"), first_timer, "Timer identity is stable.")
	expect_false(first_timer.is_stopped(), "Reentry resumes the configured timer.")
	NucleusApp.focus_changed.emit(false)
	expect_equal(session.autosave_calls, 2, "Reentry reconnects exactly one app listener.")
	free_test_node(session)


func _test_stable_capture_set() -> void:
	var session := NucleusSaveSession.new()
	var replace_second := func() -> int:
		session.register_participant(&"second", func() -> int: return 2)
		return 10
	session.register_participant(&"first", replace_second)
	session.register_participant(&"second", func() -> int: return 1)
	var snapshot: Dictionary = session.capture_snapshot()
	expect_equal(snapshot.get("first"), 10, "Synchronous capture invokes each participant.")
	expect_equal(snapshot.get("second"), 1, "Capture uses callbacks selected at its start.")
	expect_equal(
		session.capture_snapshot().get("second"), 2,
		"Registration changes become visible on the next capture.",
	)
	session.free()
