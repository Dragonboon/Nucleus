extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
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
	session.free()
	screen.free()
	return finish()
