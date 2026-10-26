extends "res://tests/headless/test_case.gd"

const Fixture = preload("res://tests/fixtures/presentation/sprite_fixture.gd")


func run() -> Dictionary:
	var root := Node2D.new()
	attach_test_node(root)
	var sprite := AnimatedSprite2D.new()
	root.add_child(sprite)
	var settings := Fixture.profile()
	sprite.sprite_frames = Fixture.frames(settings)
	var adapter := NucleusDirectionalSpriteAnimator2D.new()
	root.add_child(adapter)
	expect_equal(adapter.configure(sprite, settings), OK, "Four-direction profile binds.")
	adapter.update_motion(Vector2(0, 10))
	expect_equal(sprite.animation, &"move_d", "Motion selects down.")
	adapter.update_motion(Vector2(0, 2))
	expect_equal(sprite.animation, &"move_d", "Hysteresis retains moving state.")
	adapter.update_motion(Vector2.ZERO, Vector2.LEFT)
	expect_equal(sprite.animation, &"rest_l", "Aim controls idle facing.")
	adapter.update_motion(Vector2.ZERO, Vector2.RIGHT)
	adapter.update_motion(Vector2.ZERO, Vector2.RIGHT.rotated(PI / 4.0 + 0.01))
	expect_equal(sprite.animation, &"rest_r", "Facing hysteresis avoids boundary flicker.")
	expect_equal(adapter.play_action(&"missing"), ERR_DOES_NOT_EXIST, "Missing action rejects.")
	adapter.play_action(&"use")
	sprite.set_frame_and_progress(1, 0.5)
	adapter.play_action(&"use")
	expect_equal(sprite.frame, 1, "Repeated action preserves frame.")
	expect_float(sprite.frame_progress, 0.5, "Repeated action preserves progress.")
	adapter.update_motion(Vector2.UP * 10)
	expect_equal(sprite.animation, &"use_r", "Active action keeps starting direction.")
	expect_equal(adapter.play_action(&"end"), ERR_BUSY, "Busy action cannot be replaced implicitly.")
	var canceled: Array[StringName] = []
	adapter.action_canceled.connect(func(id: StringName) -> void: canceled.append(id))
	expect_equal(adapter.play_action(&"end", true, true), OK, "Explicit interruption works.")
	expect_equal(canceled, [&"use"], "Interruption reports old action once.")
	adapter.cancel_action()
	expect_equal(sprite.animation, &"move_u", "Cancel resumes most recent movement.")
	var invalid := settings.duplicate(true) as NucleusDirectionalSpriteProfile2D
	invalid.idle_clips[0] = "absent"
	expect_equal(adapter.configure(sprite, invalid), ERR_INVALID_DATA,
		"Missing clip rejects atomically.")
	expect_equal(adapter.profile, settings, "Rejected configuration preserves previous profile.")
	invalid = settings.duplicate(true)
	invalid.start_speed = NAN
	expect_false(invalid.get_validation_errors(sprite.sprite_frames).is_empty(), "NaN rejects.")
	var bad_frames := sprite.sprite_frames.duplicate(true) as SpriteFrames
	bad_frames.set_animation_loop(&"use_r", true)
	expect_false(settings.get_validation_errors(bad_frames).is_empty(), "Looping actions reject.")
	expect_equal(adapter.update_motion(Vector2(INF, 0)), ERR_INVALID_PARAMETER,
		"Nonfinite motion rejects.")
	var eight := Fixture.profile(true)
	sprite.sprite_frames = Fixture.frames(eight)
	expect_equal(adapter.configure(sprite, eight), OK, "Eight-direction profile binds.")
	for index in 8:
		adapter.update_motion(Vector2.RIGHT.rotated(index * PI / 4.0) * 10)
		expect_equal(sprite.animation, StringName(eight.move_clips[index]), "All eight sectors resolve.")
	root.remove_child(adapter)
	root.add_child(adapter)
	adapter.update_motion(Vector2.LEFT * 10)
	expect_equal(sprite.animation, &"move_l", "Re-entry restores binding.")
	sprite.free()
	expect_equal(adapter.play_action(&"use"), ERR_UNCONFIGURED, "Freed sprite rejects safely.")
	free_test_node(root)
	return finish()
