extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_merge_preserves_manual_changes()
	_test_conflict_when_generated_clip_edited()
	_test_batch_plan()
	_test_signature_detects_native_edits()
	_test_sequence_removal_and_conflict()
	_test_cached_resource_refresh()
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


func _test_signature_detects_native_edits() -> void:
	var frames := SpriteFrames.new()
	var first := GradientTexture2D.new()
	first.resource_path = "user://sprite_first.tres"
	var replacement := GradientTexture2D.new()
	replacement.resource_path = "user://sprite_replacement.tres"
	frames.add_frame(&"default", first)
	var before := NucleusSpriteSheetBuilder2D.frames_signature(frames, &"default")
	frames.set_frame(&"default", 0, replacement)
	expect_true(before != NucleusSpriteSheetBuilder2D.frames_signature(frames, &"default"),
		"Replacing an individual texture changes provenance, even with identical timing.")
	var animation := NucleusSpriteSheetBuilder2D.build_library(_profile()).get_animation(&"row_00")
	var signature := NucleusSpriteSheetBuilder2D.animation_signature(animation)
	animation.track_set_enabled(0, false)
	expect_true(signature != NucleusSpriteSheetBuilder2D.animation_signature(animation),
		"Disabling an authored track must be protected on reimport.")


func _test_sequence_removal_and_conflict() -> void:
	var expected := SpriteFrames.new()
	expected.add_animation(&"obsolete")
	var first := NucleusSpriteSequencePipeline2D.merge_frames(expected, null, {})
	var existing: SpriteFrames = first["resource"]
	expected = expected.duplicate(true) as SpriteFrames
	expected.remove_animation(&"obsolete")
	var removed := NucleusSpriteSequencePipeline2D.merge_frames(
		expected, existing, first["managed"],
	)
	expect_false((removed["resource"] as SpriteFrames).has_animation(&"obsolete"),
		"Removing an unedited clip from a sequence profile removes generated frames.")
	existing.set_animation_speed(&"obsolete", 30.0)
	var protected := NucleusSpriteSequencePipeline2D.merge_frames(
		expected, existing, first["managed"],
	)
	expect_true((protected["resource"] as SpriteFrames).has_animation(&"obsolete"),
		"Deleted but manually edited sequence clips survive as conflicts.")
	expect_true("obsolete" in protected["conflicts"], "The preserved clip is reported.")
	var library := AnimationLibrary.new()
	library.add_animation(&"obsolete", Animation.new())
	var initial := NucleusSpriteSequencePipeline2D.merge_library(library, null, {})
	var empty := AnimationLibrary.new()
	var result := NucleusSpriteSequencePipeline2D.merge_library(
		empty, library, initial["managed"],
	)
	expect_false((result["resource"] as AnimationLibrary).has_animation(&"obsolete"),
		"Removed profile clips also leave the AnimationLibrary.")


func _test_cached_resource_refresh() -> void:
	var path := "res://tests/fixtures/cache_refresh_%d.tres" % Time.get_ticks_usec()
	var frames := SpriteFrames.new()
	expect_equal(NucleusSpriteReimport2D.write_new_resource(frames, path), OK,
		"Initial generated resource saves with an explicit path.")
	var held := ResourceLoader.load(path) as SpriteFrames
	var edited := held.duplicate(true) as SpriteFrames
	edited.set_animation_speed(&"default", 19.0)
	expect_equal(NucleusSpriteReimport2D.save_generated_resource(edited, path), OK,
		"Detached merge saves without claiming an already occupied resource path.")
	expect_float(held.get_animation_speed(&"default"), 19.0,
		"Native cache refresh updates resources held by existing scenes.")
	expect_equal(ResourceLoader.load(path), held, "The cached resource keeps its identity.")
	expect_equal(NucleusSpriteReimport2D.save_generated_resource(edited, ""),
		ERR_INVALID_PARAMETER, "Empty save path is rejected before ResourceSaver.")
	DirAccess.remove_absolute(path)
