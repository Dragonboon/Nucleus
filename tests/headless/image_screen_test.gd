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
	var entries: Array[NucleusScreenHotspot] = [left, top]
	expect_equal(screen.set_screen(&"room", texture, entries), OK,
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
	var invalid_entries: Array[NucleusScreenHotspot] = [invalid]
	expect_equal(screen.set_screen(&"broken", texture, invalid_entries), ERR_INVALID_DATA,
		"Reject out-of-range hotspot.")
	expect_equal(screen.screen_id, &"room", "Invalid replacement remains atomic.")
	screen.size = Vector2(600, 1000)
	expect_equal(screen.image_rect(), Rect2(0, 200, 600, 600),
		"Portrait viewport keeps image proportions.")
	var mask := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	mask.fill(Color(1.0, 1.0, 1.0, 0.0))
	mask.set_pixel(1, 1, Color.WHITE)
	var masked := NucleusScreenHotspot.new()
	masked.id = &"masked"
	masked.bounds = Rect2(0.0, 0.0, 1.0, 1.0)
	masked.alpha_mask = ImageTexture.create_from_image(mask)
	expect_true(masked.contains_normalized(Vector2(0.375, 0.375)),
		"Cached alpha image dimensions support opaque pixels.")
	expect_false(masked.contains_normalized(Vector2(0.875, 0.875)),
		"Transparent mask pixels cannot receive interactions.")
	left.enabled = false
	expect_equal(screen.activate(&"door"), ERR_DOES_NOT_EXIST,
		"Disabled hotspot cannot be activated.")
	var tap := screen.image_local_point(Vector2(0.3, 0.3))
	screen._begin_press(tap)
	screen.interaction_enabled = false
	screen.interaction_enabled = true
	screen._finish_press(tap)
	expect_equal(fired.size(), 1, "Disable/re-enable cannot revive a pending press.")
	screen._begin_press(tap)
	screen._update_press(screen.image_local_point(Vector2(0.8, 0.8)))
	screen._finish_press(tap)
	expect_equal(fired.size(), 1, "Dragging away and returning is not a tap.")
	screen._begin_press(tap, 7)
	screen._finish_press(tap, 8)
	expect_equal(fired.size(), 1, "Another finger cannot finish an owned touch.")
	screen._finish_press(tap, 7)
	expect_equal(fired.size(), 2, "Touch ownership is not restricted to index zero.")
	screen._begin_press(tap)
	screen.hotspots = [top]
	screen._finish_press(tap)
	expect_equal(fired.size(), 2, "Replacing dynamic hotspots cancels old presses.")
	expect_equal(screen.hotspot_at(Vector2(NAN, 0.3)), null,
		"Nonfinite pointer coordinates cannot hit a region.")
	masked.bounds.position.x = NAN
	expect_false(masked.is_valid_hotspot(), "Nonfinite geometry is rejected.")
	masked.bounds.position.x = 0.0
	masked.polygon = PackedVector2Array([Vector2.ZERO, Vector2(INF, 0), Vector2.ONE])
	expect_false(masked.is_valid_hotspot(), "Nonfinite polygons are rejected.")
	screen.free()
	return finish()
