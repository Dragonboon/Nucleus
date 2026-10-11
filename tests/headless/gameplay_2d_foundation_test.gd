extends "res://tests/headless/test_case.gd"


class FixedMotionSource2D:
	extends NucleusMotionSource2D

	var requested_velocity: Vector2 = Vector2.ZERO


	func get_desired_velocity(
		_body: CharacterBody2D,
		_max_speed: float,
	) -> Vector2:
		return requested_velocity


func run() -> Dictionary:
	_test_floating_motion()
	_test_grounded_motion_and_impulse()
	_test_source_lifecycle_and_fallback()
	_test_navigation_adapter()
	_test_missing_body()
	return finish()


func _test_floating_motion() -> void:
	var actor := CharacterBody2D.new()
	actor.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var source := FixedMotionSource2D.new()
	var motor := NucleusCharacterMotor2D.new()
	actor.add_child(source)
	actor.add_child(motor)
	motor.body = actor
	motor.motion_source = source
	motor.speed = 160.0
	motor.speed_multiplier = 0.5
	motor.acceleration = 10000.0
	motor.deceleration = 10000.0
	source.requested_velocity = Vector2(400.0, 400.0)

	expect_true(attach_test_node(actor), "Floating motor requires a live SceneTree.")
	motor._physics_process(0.1)
	expect_float(motor.get_max_speed(), 80.0, "Speed multiplier must apply.")
	expect_float(motor.desired_velocity.length(), 80.0, "Intent must be clamped.")
	expect_float(actor.velocity.length(), 80.0, "Floating motion must use both axes.")
	free_test_node(actor)


func _test_grounded_motion_and_impulse() -> void:
	var actor := CharacterBody2D.new()
	actor.motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	var source := FixedMotionSource2D.new()
	var motor := NucleusCharacterMotor2D.new()
	actor.add_child(source)
	actor.add_child(motor)
	motor.body = actor
	motor.motion_source = source
	motor.speed = 120.0
	motor.acceleration = 10000.0
	motor.gravity_scale = 0.0
	source.requested_velocity = Vector2(400.0, 400.0)

	expect_true(attach_test_node(actor), "Grounded motor requires a SceneTree.")
	expect_equal(
		motor.request_velocity_impulse(Vector2(0.0, -250.0)),
		OK,
		"Impulse must be accepted when a body is configured.",
	)
	motor._physics_process(0.1)
	expect_float(actor.velocity.x, 120.0, "Grounded motor uses tangent intent only.")
	expect_float(actor.velocity.y, -250.0, "Impulse preserves vertical velocity.")
	expect_float(motor.desired_velocity.length(), 120.0, "Source clamp is shared.")
	source.requested_velocity = Vector2(30.0, 400.0)
	motor._physics_process(0.1)
	expect_float(actor.velocity.x, 30.0, "Grounded analog speed survives projection.")
	expect_float(motor.desired_velocity.y, 0.0, "Grounded intent contains no vertical motion.")
	actor.up_direction = Vector2.LEFT
	source.requested_velocity = Vector2(400.0, 40.0)
	actor.velocity = Vector2(-25.0, 0.0)
	motor._physics_process(0.1)
	expect_float(actor.velocity.y, 40.0, "Custom up uses its own tangent plane.")
	expect_float(actor.velocity.x, -25.0, "Custom up preserves the existing vertical speed.")
	free_test_node(actor)


func _test_source_lifecycle_and_fallback() -> void:
	var actor := CharacterBody2D.new()
	actor.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var source := FixedMotionSource2D.new()
	var motor := NucleusCharacterMotor2D.new()
	actor.add_child(source)
	actor.add_child(motor)
	motor.body = actor
	motor.motion_source = source
	motor.acceleration = 10000.0
	motor.deceleration = 10000.0
	source.requested_velocity = Vector2(20.0, 0.0)

	expect_true(attach_test_node(actor), "Source lifecycle requires a SceneTree.")
	motor._physics_process(0.1)
	expect_true(actor.velocity.x > 0.0, "Source produces world-space intent.")
	source.enabled = false
	motor._physics_process(0.1)
	expect_true(
		motor.desired_velocity.is_zero_approx(),
		"Disabled source without input yields zero intent.",
	)
	expect_true(actor.velocity.is_zero_approx(), "Zero intent should decelerate.")
	expect_equal(
		motor.request_velocity_impulse(Vector2.INF),
		ERR_INVALID_PARAMETER,
		"Invalid impulse must be rejected.",
	)
	motor.enabled = false
	expect_equal(
		motor.request_velocity_impulse(Vector2.RIGHT),
		ERR_UNAVAILABLE,
		"Disabled motor must reject impulses.",
	)
	free_test_node(actor)


func _test_navigation_adapter() -> void:
	var actor := CharacterBody2D.new()
	var agent := NavigationAgent2D.new()
	var follower := NucleusNavigationFollower2D.new()
	var source := NucleusNavigationMotionSource2D.new()
	actor.add_child(agent)
	actor.add_child(follower)
	actor.add_child(source)
	follower.agent = agent
	follower.origin = actor
	follower.output_velocity = Vector2(120.0, 0.0)
	source.follower = follower

	expect_float(
		source.get_desired_velocity(actor, 40.0).length(),
		40.0,
		"Navigation adapter must limit movement intent.",
	)
	expect_float(follower.movement_speed, 40.0, "Follower speed stays synchronized.")
	expect_float(agent.max_speed, 40.0, "Native NavigationAgent speed stays synchronized.")
	source.enabled = false
	expect_true(
		source.get_desired_velocity(actor, 40.0).is_zero_approx(),
		"Inactive adapter must produce zero velocity.",
	)
	actor.free()


func _test_missing_body() -> void:
	var motor := NucleusCharacterMotor2D.new()
	expect_false(
		motor._get_configuration_warnings().is_empty(),
		"Motor must report a missing CharacterBody2D.",
	)
	expect_equal(
		motor.request_velocity_impulse(Vector2.RIGHT),
		ERR_UNAVAILABLE,
		"Missing physics owner must reject impulses.",
	)
	motor.free()
