extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_merge_preserves_manual_changes()
	_test_conflict_when_generated_clip_edited()
	_test_batch_plan()
	return finish()


func _profile() -> NucleusSpriteSheetProfile2D:
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var profile := NucleusSpriteSheetProfile2D.new()
	profile.texture = ImageTexture.create_from_image(image)
	profile.cell_size = Vector2i(16, 16)
	NucleusSpriteSheetBuilder2D.create_row_clips(profile)
	return profile


func _test_merge_preserves_manual_changes() -> void:
	var profile := _profile()
	var first := NucleusSpriteReimport2D.sync(profile, null, null, {})
	expect_equal(first["error"], OK, "New generation is accepted.")
	var frames: SpriteFrames = first["frames"]
	frames.add_animation(&"custom")
	frames.add_frame(&"custom", profile.texture)
	var library: AnimationLibrary = first["library"]
	var authored := Animation.new()
	authored.length = 2.0
	library.add_animation(&"custom", authored)
	profile.clips[0].fps = 12.0
	var second := NucleusSpriteReimport2D.sync(
		profile, frames, library, first["manifest"],
	)
	var rebuilt: SpriteFrames = second["frames"]
	expect_true(rebuilt.has_animation(&"custom"), "Manual clip remains after reimport.")
	expect_float(rebuilt.get_animation_speed(&"row_00"), 12.0,
		"Unedited managed clip refreshes from profile.")
	expect_true((second["library"] as AnimationLibrary).has_animation(&"custom"),
		"Authored animation track survives the update.")
	expect_true(frames.get_animation_speed(&"row_00") != 12.0,
		"The supplied source resource is not mutated during merge.")


func _test_conflict_when_generated_clip_edited() -> void:
	var profile := _profile()
	var first := NucleusSpriteReimport2D.sync(profile, null, null, {})
	var frames: SpriteFrames = first["frames"]
	frames.set_animation_speed(&"row_00", 30.0)
	profile.clips[0].fps = 15.0
	var second := NucleusSpriteReimport2D.sync(
		profile, frames, first["library"], first["manifest"],
	)
	expect_true("row_00" in second["conflicts"],
		"User-edited generated clip is flagged rather than overwritten.")
	expect_float((second["frames"] as SpriteFrames).get_animation_speed(&"row_00"),
		30.0, "Conflicting manual FPS survives.")
	expect_float(frames.get_animation_speed(&"row_00"), 30.0,
		"Original resource stays intact.")


func _test_batch_plan() -> void:
	expect_equal(
		NucleusSpriteBatchImport2D.output_stem(
			"res://sprites/actors/hero.png", "res://sprites", "res://generated",
		),
		"res://generated/actors/hero",
		"Batch paths preserve relative folders without overwriting scenes.",
	)
	expect_true(
		NucleusSpriteBatchImport2D.scan_plan("../bad", "res://output").is_empty(),
		"Unsafe scan paths are rejected.",
	)
