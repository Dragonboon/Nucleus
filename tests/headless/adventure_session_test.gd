extends "res://tests/headless/test_case.gd"


# Existing consuming games may already declare this signal in a session subclass.
class LegacySession extends NucleusAdventureSession:
	signal interaction_requested(id: StringName, destination: StringName)


func run() -> Dictionary:
	var legacy := LegacySession.new()
	expect_true(legacy.has_signal("interaction_requested"),
		"Existing policy-routing subclasses retain their own signals.")
	legacy.free()
	var session := NucleusAdventureSession.new()
	var screen := NucleusImageScreen.new()
	session.screen = screen
	var picture := ImageTexture.create_from_image(
		Image.create(16, 16, false, Image.FORMAT_RGBA8))
	var door := NucleusScreenHotspot.new()
	door.id = &"door"
	door.destination = &"hall"
	var first := NucleusAdventurePage.new()
	first.id = &"start"
	first.image = picture
	first.hotspots = [door]
	var second := NucleusAdventurePage.new()
	second.id = &"hall"
	second.image = picture
	session.pages = [first, second]
	session._ready()
	expect_composition_signal(screen.hotspot_activated, session._on_hotspot)
	expect_equal(session.current_page, &"start", "First authored page is active.")
	expect_equal(screen.focus_next(), &"door", "Initial focus selects the first hotspot.")
	expect_equal(screen.activate_focused(), OK, "Focused hotspot can be activated.")
	expect_equal(session.change_page(&"start"), OK, "Return to first page.")
	expect_equal(session.activate_hotspot(&"door"), OK, "Navigate to linked page.")
	expect_equal(session.current_page, &"hall", "Destination resolves from allowed pages.")
	expect_equal(session.change_page(&"unknown"), ERR_DOES_NOT_EXIST,
		"Reject unknown page ID.")
	var snapshot := session.capture_state()
	session.set_flag(&"solved", true)
	expect_equal(session.restore_state(snapshot), OK, "Serializable state restores.")
	expect_false(session.has_flag(&"solved"), "Restored flags replace transient flags.")
	expect_equal(session.restore_state({"version": 9}), ERR_FILE_UNRECOGNIZED,
		"Unknown save version is rejected.")
	var before := session.capture_state()
	var corrupt := before.duplicate(true)
	corrupt["flags"] = {"wrong": 42}
	expect_equal(session.restore_state(corrupt), ERR_INVALID_DATA,
		"Invalid flag payload must be rejected before page mutation.")
	expect_equal(session.capture_state(), before,
		"Invalid restore preserves previously committed state.")
	expect_true(session.validate_configuration().is_empty(),
		"A one-way authored sequence remains valid by default.")
	expect_false(session.validate_configuration(true).is_empty(),
		"Optional return-path diagnostics detect a trapped close-up.")
	second.back_page = &"start"
	second.navigation_edge_fraction = Vector2(0.07, 0.065)
	expect_true(session.validate_configuration(true).is_empty(),
		"An explicit return link closes the authored navigation graph.")
	expect_equal(session.change_page(&"hall"), OK, "Open a detail page with edge navigation.")
	var region := screen.hotspot_at(Vector2(0.5, 0.975))
	expect_true(region != null and region.destination == &"start",
		"The normalized bottom band resolves the explicit return target.")
	expect_equal(session.go_back(), OK, "Return is deterministic and independent of history.")
	expect_equal(session.current_page, &"start", "Back returns to the declared page.")
	expect_equal(second.hotspots.size(), 0, "Generated navigation never mutates authored arrays.")
	var requests := []
	session.auto_activate_hotspots = false
	session.hotspot_requested.connect(
		func(id: StringName, destination: StringName) -> void: requests.append([id, destination]))
	expect_equal(screen.activate(&"door"), OK, "Route input to game policy without subclassing.")
	expect_equal(session.current_page, &"start", "Manual routing performs no implicit action.")
	expect_equal(requests.size(), 1, "One semantic request is emitted.")
	session.activate_hotspot(&"door")
	expect_equal(session.current_page, &"hall", "Game policy can explicitly commit the action.")
	var nested := []
	session.page_changed.connect(
		func(_id: StringName) -> void: nested.append(session.change_page(&"start")))
	session.change_page(&"hall")
	expect_equal(nested[0], ERR_BUSY, "Page callbacks cannot re-enter a half-committed change.")
	var orphan := NucleusAdventurePage.new()
	orphan.id = &"orphan"
	orphan.image = picture
	session.pages.append(orphan)
	expect_false(session.validate_configuration().is_empty(),
		"Unreachable pages are reported before gameplay.")
	session.pages.pop_back()
	second.back_page = &"missing"
	expect_false(session.validate_configuration().is_empty(), "Broken destinations are reported.")
	second.back_page = &"start"
	# Target resources may become invalid after indexing; preflight before setting flags.
	var action := NucleusScreenAction.new()
	action.next_screen = &"hall"
	action.set_flags = [&"must_not_commit"]
	door.action = action
	session.change_page(&"start")
	var broken := NucleusScreenHotspot.new()
	second.hotspots = [broken]
	expect_equal(session.activate_hotspot(&"door"), ERR_INVALID_DATA,
		"Invalid destination content is rejected before action side effects.")
	expect_false(session.has_flag(&"must_not_commit"), "Rejected navigation does not set flags.")
	session.free()
	screen.free()
	return finish()
