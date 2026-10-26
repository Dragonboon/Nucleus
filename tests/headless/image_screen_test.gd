extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	var screen := NucleusImageScreen.new()
	screen.size = Vector2(1600, 900)
	var texture := ImageTexture.create_from_image(
		Image.create(800, 800, false, Image.FORMAT_RGBA8)
	)
	var left := NucleusScreenHotspot.new()
	left.id = &"door"
	left.bounds = Rect2(0.1, 0.1, 0.5, 0.5)
	left.destination = &"hall"
	var top := NucleusScreenHotspot.new()
	top.id = &"note"
	top.bounds = Rect2(0.25, 0.25, 0.2, 0.2)
	top.priority = 10
	expect_equal(screen.set_screen(&"room", texture, [left, top]), OK,
		"Valid image screen admitted.")
	expect_equal(screen.image_rect(), Rect2(350, 0, 900, 900),
		"Square image letterboxed in widescreen.")
	expect_equal(screen.normalized_point(Vector2.ZERO), Vector2(-1, -1),
		"Black bar must never be clickable.")
	expect_equal(screen.hotspot_at(Vector2(0.3, 0.3)).id, &"note",
		"Overlaps select highest priority.")
	var fired := []
	screen.hotspot_activated.connect(
		func(id: StringName, destination: StringName) -> void:
			fired.append([id, destination])
	)
	screen._begin_press(Vector2(350 + 900 * 0.3, 900 * 0.3))
	screen._finish_press(Vector2(350 + 900 * 0.3, 900 * 0.3))
	expect_equal(fired.size(), 1, "Click triggers once.")
	expect_equal(fired[0], [&"note", &""], "Click emits semantic hotspot.")
	screen._begin_press(Vector2(350 + 900 * 0.3, 900 * 0.3))
	screen._finish_press(Vector2.ZERO)
	expect_equal(fired.size(), 1, "Release outside image cancels activation.")
	screen._begin_press(Vector2(350 + 900 * 0.3, 900 * 0.3))
	screen._finish_press(Vector2(350 + 900 * 0.5, 900 * 0.5))
	expect_equal(fired.size(), 1, "Drag beyond slop cannot activate.")
	var invalid := NucleusScreenHotspot.new()
	invalid.id = &"bad"
	invalid.bounds = Rect2(0.9, 0.9, 0.2, 0.2)
	expect_equal(screen.set_screen(&"broken", texture, [invalid]), ERR_INVALID_DATA,
		"Reject out-of-range hotspot.")
	expect_equal(screen.screen_id, &"room", "Invalid replacement remains atomic.")
	screen.size = Vector2(600, 1000)
	expect_equal(screen.image_rect(), Rect2(0, 200, 600, 600),
		"Portrait viewport keeps image proportions.")
	left.enabled = false
	expect_equal(screen.activate(&"door"), ERR_DOES_NOT_EXIST,
		"Disabled hotspot cannot be activated.")
	screen.free()
	return finish()
