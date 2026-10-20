extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_grid_and_frames()
	_test_bad_input()
	_test_scene()
	return finish()


func _profile() -> NucleusSpriteSheetProfile2D:
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var profile := NucleusSpriteSheetProfile2D.new()
	profile.texture = ImageTexture.create_from_image(image)
	profile.cell_size = Vector2i(16, 16)
	return profile


func _test_grid_and_frames() -> void:
	var profile := _profile()
	expect_equal(profile.grid_size(), Vector2i(4, 2), "Grid inferred from dimensions.")
	NucleusSpriteSheetBuilder2D.create_row_clips(profile)
	expect_equal(profile.clips.size(), 2, "Opt-in row clip generator adds both rows.")
	NucleusSpriteSheetBuilder2D.create_row_clips(profile)
	expect_equal(profile.clips.size(), 2, "Existing clips are not overwritten.")
	var frames := NucleusSpriteSheetBuilder2D.build_frames(profile)
	expect_true(frames != null, "Valid sheet builds native SpriteFrames.")
	if frames != null:
		expect_equal(frames.get_frame_count(&"row_00"), 4, "All four frames included.")
		var atlas := frames.get_frame_texture(&"row_00", 2) as AtlasTexture
		expect_equal(atlas.region, Rect2(32, 0, 16, 16),
			"Atlas region uses source texture without destructive extraction.")


func _test_bad_input() -> void:
	var profile := _profile()
	var clip := NucleusSpriteClip2D.new()
	clip.cells = [Vector2i(99, 0)]
	profile.clips.append(clip)
	expect_true(not profile.validate().is_empty(), "Out-of-bounds cells rejected.")
	expect_true(NucleusSpriteSheetBuilder2D.build_frames(profile) == null,
		"Invalid profiles never generate partial resources.")


func _test_scene() -> void:
	var profile := _profile()
	NucleusSpriteSheetBuilder2D.create_row_clips(profile)
	var root := NucleusSpriteSheetBuilder2D.build_scene(profile, true)
	expect_true(root != null, "Scene is built from same profile as frames.")
	if root != null:
		expect_true(root.get_node_or_null("AnimatedSprite2D") is AnimatedSprite2D,
			"Native AnimatedSprite2D is created.")
		var player := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
		expect_true(player != null, "Optional AnimationPlayer created.")
		if player != null:
			expect_true(player.has_animation(&"row_00"), "Native animation track generated.")
		root.free()
