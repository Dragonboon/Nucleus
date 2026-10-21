extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	expect_equal(
		NucleusSpriteSequenceImporter2D.scan_directory("res://missing_sprite_studio"),
		[], "Missing input folder produces an empty plan.",
	)
	_test_real_directory_grouping()
	_test_native_scene_playback()
	_test_sequence_timing_and_case()
	return finish()


func _test_real_directory_grouping() -> void:
	var root := "res://tests/fixtures/sprite_scan_%d" % Time.get_ticks_usec()
	var files := PackedStringArray([
		"player/idle/player-idle-10.png", "player/idle/player-idle-2.png",
		"player/run/player-run-1.png", "player/run/player-run-2.png",
		"props/tree.png", "props/tree.webp",
	])
	for relative: String in files:
		var path := root.path_join(relative)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("Discovery checks filenames without decoding images.")
		file.close()
	var groups := NucleusSpriteSequenceImporter2D.scan_directory(root)
	expect_equal(groups.size(), 1, "Idle and run folders produce one player, not four actors.")
	if groups.size() == 1:
		expect_equal(groups[0]["id"], "player", "Character identity preserves the parent folder.")
		var clips: Array = groups[0]["clips"]
		expect_equal(clips.size(), 2, "Both animation groups are available for review.")
		var paths: PackedStringArray = clips[0]["paths"]
		expect_true(paths[0].ends_with("-2.png"), "Frame numbers sort naturally before frame 10.")
	var plan := NucleusSpriteBatchImport2D.scan_plan(root, "res://generated/test")
	var collisions := 0
	for entry: Dictionary in plan:
		if entry.has("error"):
			collisions += 1
	expect_equal(collisions, 2, "Same-basename images cannot silently share an output profile.")
	for relative: String in files:
		DirAccess.remove_absolute(root.path_join(relative))
	for folder: String in ["player/idle", "player/run", "player", "props", ""]:
		DirAccess.remove_absolute(root.path_join(folder))


func _test_native_scene_playback() -> void:
	var profile := NucleusSpriteSequenceProfile2D.new()
	var clip := NucleusSpriteSequenceClip2D.new()
	clip.frame_paths = PackedStringArray(["res://idle-1.png", "res://idle-2.png"])
	clip.fps = 8.0
	profile.clips.append(clip)
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.add_frame(&"idle", GradientTexture2D.new())
	frames.add_frame(&"idle", GradientTexture2D.new())
	var library := NucleusSpriteSequencePipeline2D.build_library(profile)
	var root := NucleusSpriteSequencePipeline2D.create_scene(frames, library)
	expect_true(attach_test_node(root), "Generated visual attaches to the actual scene tree.")
	var player := root.get_node("AnimationPlayer") as AnimationPlayer
	var sprite := root.get_node("AnimatedSprite2D") as AnimatedSprite2D
	player.play(&"idle")
	player.advance(0.15)
	expect_equal(sprite.animation, &"idle", "AnimationPlayer selects the native sprite clip.")
	expect_equal(sprite.frame, 1, "Native animation tracks drive the expected frame.")
	expect_false(sprite.is_playing(), "No second playback clock competes with AnimationPlayer.")
	var packed := PackedScene.new()
	expect_equal(packed.pack(root), OK, "Generated nodes have valid PackedScene ownership.")
	free_test_node(root)
	var instance := packed.instantiate()
	expect_true(instance.get_node_or_null("AnimatedSprite2D") != null,
		"Sprite remains owned and present after packing and instantiation.")
	instance.free()


func _test_sequence_timing_and_case() -> void:
	var path := "res://tests/fixtures/frame_timing_%d.png" % Time.get_ticks_usec()
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	expect_equal(image.save_png(path), OK, "Create a real filename for canonicalization.")
	var texture := ImageTexture.create_from_image(image)
	texture.take_over_path(path)
	var profile := NucleusSpriteSequenceProfile2D.new()
	var clip := NucleusSpriteSequenceClip2D.new()
	clip.frame_paths = PackedStringArray([path.replace("fixtures", "FIXTURES"), path])
	clip.frame_durations_ms = PackedFloat32Array([100.0, 300.0])
	profile.clips.append(clip)
	var frames := NucleusSpriteSequenceImporter2D.build_frames(profile)
	expect_true(frames != null, "Canonical filenames are used before loading textures.")
	if frames != null:
		expect_equal(frames.get_frame_texture(&"idle", 0).resource_path, path,
			"Generated resources contain the on-disk spelling.")
		expect_float(frames.get_frame_duration(&"idle", 1) / clip.fps, 0.3,
			"Sequence SpriteFrames preserves duration overrides.")
	var animation := NucleusSpriteSequencePipeline2D.build_library(profile).get_animation(&"idle")
	expect_float(animation.length, 0.4, "Sequence library uses the same timing as frames.")
	expect_float(animation.track_get_key_time(1, 1), 0.1, "Sequence key starts after first hold.")
	clip.frame_durations_ms = PackedFloat32Array([-1.0, 100.0])
	expect_true(not clip.validate().is_empty(), "Negative sequence durations are invalid.")
	DirAccess.remove_absolute(path)
