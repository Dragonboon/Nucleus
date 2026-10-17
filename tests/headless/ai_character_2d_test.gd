extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_setup_and_speed()
	_test_facing()
	return finish()


func _test_setup_and_speed() -> void:
	var actor := CharacterBody2D.new()
	actor.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var agent := NavigationAgent2D.new()
	var setup := NucleusAICharacterSetup2D.new()
	actor.add_child(agent)
	actor.add_child(setup)
	setup.actor = actor
	setup.navigation_agent = agent
	expect_equal(setup.wire_navigation_locomotion(), OK,
		"2D setup wires native navigation to shared motor.")
	expect_true(setup.motor != null, "2D setup creates a CharacterMotor2D.")
	expect_true(setup.navigation_follower != null,
		"2D setup creates a NavigationFollower2D.")
	expect_true(setup.navigation_motion_source != null,
		"2D setup creates navigation motion source.")
	expect_true(setup.motor.motion_source == setup.navigation_motion_source,
		"2D motor consumes navigation intent.")
	expect_true(setup.navigation_motion_source.follower == setup.navigation_follower,
		"2D source uses the selected follower.")
	expect_true(
		setup.navigation_follower.process_physics_priority
		< setup.motor.process_physics_priority,
		"2D follower evaluates before motor.")
	setup.motor.speed_multiplier = 0.5
	expect_equal(setup.sync_locomotion_speeds(), OK,
		"2D navigation speed can be resynchronized.")
	expect_float(setup.navigation_follower.movement_speed,
		setup.motor.get_max_speed(), "Follower uses effective motor speed.")
	expect_true(setup.get_character_report()["warnings"].is_empty(),
		"Minimal 2D AI setup has no wiring warnings.")
	actor.free()


func _test_facing() -> void:
	var actor := CharacterBody2D.new()
	var motor := NucleusCharacterMotor2D.new()
	var pivot := Node2D.new()
	var objective := Node2D.new()
	var facing := NucleusMovementFacing2D.new()
	actor.add_child(motor)
	actor.add_child(pivot)
	actor.add_child(objective)
	actor.add_child(facing)
	motor.body = actor
	facing.motor = motor
	facing.target = pivot
	objective.position = Vector2(0.0, 100.0)
	expect_true(attach_test_node(actor), "2D facing fixture attaches.")
	facing.set_facing_target(objective)
	expect_true(
		facing.get_desired_facing_direction().is_equal_approx(Vector2.DOWN),
		"2D facing aims at a scene-owned target.")
	facing.set_facing_direction(Vector2.LEFT)
	expect_true(
		facing.get_desired_facing_direction().is_equal_approx(Vector2.LEFT),
		"2D facing accepts scripted direction.")
	free_test_node(actor)
