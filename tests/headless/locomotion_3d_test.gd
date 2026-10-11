extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_planar_axes()
	_test_jump_release()
	_test_acceleration_rates()
	_test_animation_projection()
	return finish()


func _test_planar_axes() -> void:
	var overhead := Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, -PI / 2.0)
	var direction := NucleusMotionMath.planar_direction_3d(
		Vector2.RIGHT, overhead, Vector3.UP,
	)
	expect_true(
		direction.is_equal_approx(overhead.x),
		"An overhead camera preserves its horizontal heading.",
	)
	direction = NucleusMotionMath.planar_direction_3d(
		Vector2(0.0, 0.4), Basis.IDENTITY, Vector3.BACK,
	)
	expect_float(direction.length(), 0.4, "Parallel camera/up axes preserve analog intent.")
	expect_float(direction.dot(Vector3.BACK), 0.0, "Intent remains in the movement plane.")
	direction = NucleusMotionMath.planar_direction_3d(
		Vector2.ONE, Basis.IDENTITY, Vector3.UP,
	)
	expect_float(direction.length(), 1.0, "Diagonal intent does not exceed full speed.")


func _test_jump_release() -> void:
	var body := CharacterBody3D.new()
	var source := NucleusPlanarMotionSource3D.new()
	var motor := NucleusCharacterMotor3D.new()
	body.add_child(source)
	body.add_child(motor)
	motor.body = body
	motor.motion_source = source
	motor.jump_action = &"nucleus_test_jump"
	motor.extra_air_jumps = 1
	motor.gravity_scale = 0.0
	InputMap.add_action(motor.jump_action)
	expect_true(attach_test_node(body), "Jump test requires a live physics body.")
	var press := InputEventAction.new()
	press.action = motor.jump_action
	press.pressed = true
	var release := InputEventAction.new()
	release.action = motor.jump_action
	motor._on_input_event(press)
	motor._on_input_event(release)
	expect_float(body.velocity.y, 0.0, "Input callbacks do not write physical velocity.")
	motor._physics_process(1.0 / 60.0)
	expect_float(body.velocity.y, 2.5, "A tap between physics ticks produces a short jump.")
	motor._physics_process(1.0 / 60.0)
	expect_float(body.velocity.y, 2.5, "Jump release is consumed only once.")
	motor.enabled = false
	body.velocity.y = 4.0
	motor._on_input_event(release)
	expect_float(body.velocity.y, 4.0, "A disabled motor ignores jump release.")
	motor.enabled = true
	motor._air_jumps_used = 0
	motor.request_jump()
	motor.enabled = false
	motor.enabled = true
	body.velocity = Vector3.ZERO
	motor._physics_process(1.0 / 60.0)
	expect_float(body.velocity.y, 0.0, "Disabling clears a pending jump.")
	motor.extra_air_jumps = 0
	motor._on_input_event(press)
	motor._on_input_event(release)
	motor._physics_process(1.0 / 60.0)
	expect_float(body.velocity.y, 0.0, "A buffered tap waits for jump eligibility.")
	motor._coyote_remaining = 0.1
	motor._physics_process(1.0 / 60.0)
	expect_float(body.velocity.y, 2.5, "Buffered release survives until the jump is consumed.")
	InputMap.erase_action(motor.jump_action)
	free_test_node(body)


func _test_acceleration_rates() -> void:
	var body := CharacterBody3D.new()
	var motor := NucleusCharacterMotor3D.new()
	motor.body = body
	motor.desired_direction = Vector3.RIGHT
	motor.desired_velocity = Vector3.RIGHT * 5.0
	for frequency: int in [30, 60, 120]:
		body.velocity = Vector3.UP * 3.0
		for _tick: int in range(int(frequency * 0.2)):
			motor._apply_planar_motion(1.0 / frequency)
		expect_float(body.velocity.x, 1.6, "Acceleration is time-based at %d Hz." % frequency)
		expect_float(body.velocity.y, 3.0, "Planar acceleration preserves vertical velocity.")
	motor.free()
	body.free()


func _test_animation_projection() -> void:
	var body := CharacterBody3D.new()
	var pivot := Node3D.new()
	var tree := AnimationTree.new()
	var graph := AnimationNodeBlendTree.new()
	graph.add_node(&"Motion", AnimationNodeBlendSpace2D.new())
	graph.add_node(&"Speed", AnimationNodeTimeScale.new())
	graph.add_node(&"Vertical", AnimationNodeTimeScale.new())
	graph.connect_node(&"Speed", 0, &"Motion")
	graph.connect_node(&"Vertical", 0, &"Speed")
	graph.connect_node(&"output", 0, &"Vertical")
	tree.tree_root = graph
	tree.active = false
	var binding := NucleusAnimationVelocityBinding3D.new()
	binding.body = body
	binding.animation_tree = tree
	binding.orientation_source = pivot
	binding.blend_parameter = &"parameters/Motion/blend_position"
	binding.speed_parameter = &"parameters/Speed/scale"
	binding.vertical_speed_parameter = &"parameters/Vertical/scale"
	binding.normalize_blend_direction = false
	body.add_child(pivot)
	body.add_child(tree)
	body.add_child(binding)
	expect_true(attach_test_node(body), "Animation projection requires global transforms.")
	pivot.rotation.x = 0.6
	pivot.scale = Vector3(2.0, 3.0, 4.0)
	body.velocity = Vector3.UP * 5.0
	binding._process(0.0)
	var blend: Vector2 = tree.get(binding.blend_parameter)
	expect_true(blend.is_zero_approx(), "Vertical motion does not drive locomotion blend.")
	body.velocity = Vector3(0.0, 5.0, -2.0)
	binding._process(0.0)
	blend = tree.get(binding.blend_parameter)
	expect_true(blend.is_equal_approx(Vector2(0.0, 2.0)), "Art scale/pitch preserve gait speed.")
	body.up_direction = Vector3.RIGHT
	pivot.rotation = Vector3(0.0, 0.0, -PI / 2.0)
	body.velocity = Vector3(3.0, 0.0, -2.0)
	binding._process(0.0)
	expect_float(float(tree.get(binding.speed_parameter)), 2.0, "Speed uses the body's up axis.")
	expect_float(float(tree.get(binding.vertical_speed_parameter)), 3.0, "Vertical speed uses up.")
	free_test_node(body)
