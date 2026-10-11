extends "res://tests/headless/test_case.gd"


class FixedMotionSource3D:
	extends NucleusPlanarMotionSource3D

	var requested_velocity: Vector3 = Vector3.ZERO


	func get_desired_velocity(
		_body: CharacterBody3D,
		_max_planar_speed: float,
	) -> Vector3:
		return requested_velocity


func run() -> Dictionary:
	_test_float_consideration()
	_test_bool_consideration()
	_test_option_multiplication()
	_test_brain_priority_tie_break()
	_test_brain_current_option_bonus()
	_test_repath_policy()
	_test_invalid_navigation_query_fallback()
	_test_navigation_motion_source()
	_test_character_motor_motion_source()
	_test_movement_facing_modes()
	_test_ai_character_setup_wiring()
	return finish()


func _test_float_consideration() -> void:
	var consideration := NucleusAIContextFloatConsideration.new()
	consideration.context_key = &"health"
	consideration.minimum_value = 0.0
	consideration.maximum_value = 100.0

	expect_float(
		consideration.evaluate({&"health": 25.0}),
		0.25,
		"Float consideration should normalize context into [0, 1].",
	)

	consideration.invert = true

	expect_float(
		consideration.evaluate({&"health": 25.0}),
		0.75,
		"Inverted consideration should flip normalized utility.",
	)


func _test_bool_consideration() -> void:
	var consideration := NucleusAIContextBoolConsideration.new()
	consideration.context_key = &"has_target"

	expect_float(
		consideration.evaluate({&"has_target": true}),
		1.0,
		"Boolean consideration should pass the expected value.",
	)
	expect_float(
		consideration.evaluate({&"has_target": false}),
		0.0,
		"Boolean consideration should reject the opposite value.",
	)


func _test_option_multiplication() -> void:
	var gate := NucleusAIContextBoolConsideration.new()
	gate.context_key = &"has_target"

	var distance := NucleusAIContextFloatConsideration.new()
	distance.context_key = &"range_score"

	var option := NucleusAIUtilityOption.new()
	option.option_id = &"attack"
	option.base_score = 0.8
	option.considerations.append(gate)
	option.considerations.append(distance)

	expect_float(
		option.evaluate(
			{
				&"has_target": true,
				&"range_score": 0.5,
			}
		),
		0.4,
		"Utility option should multiply normalized considerations.",
	)


func _test_brain_priority_tie_break() -> void:
	var low := NucleusAIUtilityOption.new()
	low.option_id = &"idle"
	low.base_score = 0.5
	low.priority = 0

	var high := NucleusAIUtilityOption.new()
	high.option_id = &"guard"
	high.base_score = 0.5
	high.priority = 10

	var brain := NucleusAIUtilityBrain.new()
	brain.options.append(low)
	brain.options.append(high)
	brain.current_option_bonus = 0.0

	expect_true(
		brain.evaluate() == high,
		"Equal utility should use priority as deterministic tie-break.",
	)

	brain.free()


func _test_brain_current_option_bonus() -> void:
	var first := NucleusAIUtilityOption.new()
	first.option_id = &"patrol"
	first.base_score = 0.55

	var second := NucleusAIUtilityOption.new()
	second.option_id = &"investigate"
	second.base_score = 0.56

	var brain := NucleusAIUtilityBrain.new()
	brain.options.append(first)
	brain.options.append(second)
	brain.current_option_bonus = 0.02
	brain.current_option = first

	expect_true(
		brain.evaluate() == first,
		"Current-option bonus should reduce decision thrashing near a tie.",
	)

	brain.free()


func _test_repath_policy() -> void:
	expect_true(
		NucleusNavigationPolicy.should_repath(
			0.0,
			1.0,
			0.0,
			0.25,
			false,
		),
		"First target assignment should always request a path.",
	)
	expect_false(
		NucleusNavigationPolicy.should_repath(
			10.0,
			1.0,
			0.1,
			0.25,
			true,
		),
		"Repath interval should throttle moving-target path resets.",
	)
	expect_true(
		NucleusNavigationPolicy.should_repath(
			2.0,
			1.0,
			0.25,
			0.25,
			true,
		),
		"Moved target should repath after interval and distance thresholds.",
	)


func _test_invalid_navigation_query_fallback() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5

	expect_true(
		NucleusNavigationQueries2D.random_point_in_radius(
			RID(),
			Vector2(3.0, 4.0),
			10.0,
			rng,
		).is_equal_approx(
			Vector2(3.0, 4.0)
		),
		"2D query should fail safely without a navigation map.",
	)

	expect_true(
		NucleusNavigationQueries3D.random_point_in_radius(
			RID(),
			Vector3(3.0, 2.0, 4.0),
			10.0,
			rng,
		).is_equal_approx(
			Vector3(3.0, 2.0, 4.0)
		),
		"3D query should fail safely without a navigation map.",
	)


func _test_navigation_motion_source() -> void:
	var body := CharacterBody3D.new()
	var agent := NavigationAgent3D.new()
	var follower := NucleusNavigationFollower3D.new()
	var source := NucleusNavigationMotionSource3D.new()

	body.add_child(agent)
	body.add_child(follower)
	body.add_child(source)

	follower.agent = agent
	follower.origin = body
	follower.output_velocity = Vector3(8.0, 3.0, 0.0)
	source.follower = follower

	var velocity := source.get_desired_velocity(body, 4.0)

	expect_float(
		velocity.length(),
		4.0,
		"Navigation motion source should clamp to motor max planar speed.",
	)
	expect_float(
		velocity.y,
		0.0,
		"Navigation motion source should remove vertical intent.",
	)
	expect_float(
		follower.movement_speed,
		4.0,
		"Navigation motion source should synchronize follower speed.",
	)
	expect_float(
		agent.max_speed,
		4.0,
		"Navigation motion source should synchronize native agent max speed.",
	)

	body.free()


func _test_character_motor_motion_source() -> void:
	var body := CharacterBody3D.new()
	var source := FixedMotionSource3D.new()
	var motor := NucleusCharacterMotor3D.new()

	body.add_child(source)
	body.add_child(motor)
	motor.body = body
	motor.motion_source = source
	motor.speed = 5.0
	motor.speed_multiplier = 0.5
	motor.air_acceleration = 1000.0
	motor.gravity_scale = 0.0
	source.requested_velocity = Vector3(10.0, 0.0, 0.0)

	expect_true(
		attach_test_node(body),
		"Motion-source motor test requires a live SceneTree.",
	)

	motor._physics_process(0.1)

	expect_float(
		motor.get_max_planar_speed(),
		2.5,
		"CharacterMotor3D should expose effective max planar speed.",
	)
	expect_float(
		motor.desired_velocity.length(),
		2.5,
		"Motion-source intent should respect effective motor speed.",
	)
	expect_float(
		NucleusMotionMath.planar_component_3d(
			body.velocity,
			body.up_direction,
		).length(),
		2.5,
		"AI motion source should use the same CharacterMotor3D physics path.",
	)

	free_test_node(body)


func _test_movement_facing_modes() -> void:
	var body := CharacterBody3D.new()
	var motor := NucleusCharacterMotor3D.new()
	var visual := Node3D.new()
	var target := Node3D.new()
	var facing := NucleusMovementFacing3D.new()

	body.add_child(motor)
	body.add_child(visual)
	body.add_child(facing)
	motor.body = body
	facing.motor = motor
	facing.target = visual
	var source := FixedMotionSource3D.new()
	body.add_child(source)
	motor.motion_source = source
	body.add_child(target)
	target.position = Vector3(10.0, 0.0, 0.0)
	expect_true(attach_test_node(body), "Facing uses live world-space transforms.")

	facing.set_facing_target(target)

	expect_true(
		facing.get_desired_facing_direction().is_equal_approx(
			Vector3.RIGHT
		),
		"Target-facing mode should resolve a planar target direction.",
	)

	facing.set_facing_direction(Vector3.BACK)
	expect_true(
		facing.get_desired_facing_direction().is_equal_approx(
			Vector3.BACK
		),
		"Direction-facing mode should preserve explicit world direction.",
	)

	target.free()
	body.free()


func _test_ai_character_setup_wiring() -> void:
	var actor := CharacterBody3D.new()
	var agent := NavigationAgent3D.new()
	var setup := NucleusAICharacterSetup3D.new()

	actor.add_child(agent)
	actor.add_child(setup)
	setup.actor = actor
	setup.navigation_agent = agent

	expect_equal(
		setup.wire_navigation_locomotion(),
		OK,
		"AI character setup should create and wire reusable locomotion plumbing.",
	)
	expect_true(
		setup.motor != null,
		"AI setup should create a CharacterMotor3D when requested.",
	)
	expect_true(
		setup.navigation_follower != null,
		"AI setup should create NavigationFollower3D when requested.",
	)
	expect_true(
		setup.navigation_motion_source != null,
		"AI setup should create NavigationMotionSource3D when requested.",
	)
	expect_true(
		setup.motor.motion_source == setup.navigation_motion_source,
		"AI setup should connect navigation intent to the shared motor.",
	)
	expect_true(
		setup.navigation_motion_source.follower
		== setup.navigation_follower,
		"AI setup should wire its motion source to its follower.",
	)
	expect_true(
		setup.navigation_follower.process_physics_priority
		< setup.motor.process_physics_priority,
		"AI setup should schedule navigation before physical locomotion.",
	)

	var report := setup.get_character_report()
	var warnings: PackedStringArray = report.get(
		"warnings",
		PackedStringArray(),
	)
	expect_true(
		warnings.is_empty(),
		"Minimal navigation locomotion setup should validate cleanly.",
	)

	actor.free()
