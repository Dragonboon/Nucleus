extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_ragdoll_requires_simulator()
	_test_ragdoll_influence_clamps()
	_test_profile_suggests_common_clips()
	_test_rig_inspector()
	_test_starter_tree_builder()
	_test_setup_creates_tree_and_velocity_binding()
	_test_directional_profile_and_upgrade()
	_test_one_shot_slot_paths()
	_test_animation_event_binding()
	_test_animation_quality_controller()
	return finish()


func _test_ragdoll_requires_simulator() -> void:
	var controller := NucleusRagdollController3D.new()

	expect_true(
		not controller._get_configuration_warnings().is_empty(),
		"Ragdoll controller warns when no simulator is assigned.",
	)
	controller.free()


func _test_ragdoll_influence_clamps() -> void:
	var skeleton := Skeleton3D.new()
	var simulator := PhysicalBoneSimulator3D.new()
	var controller := NucleusRagdollController3D.new()

	skeleton.add_child(simulator)
	skeleton.add_child(controller)
	controller.simulator = simulator

	controller.set_ragdoll_influence(0.35)
	expect_float(
		simulator.influence,
		0.35,
		"Ragdoll controller forwards influence to the native simulator.",
	)

	controller.set_ragdoll_influence(2.0)
	expect_float(
		simulator.influence,
		1.0,
		"Ragdoll influence is clamped to the native modifier range.",
	)

	skeleton.free()


func _test_profile_suggests_common_clips() -> void:
	var player := _build_animation_player()
	var profile := NucleusAnimationStarterProfile3D.new()

	expect_equal(
		profile.suggest_common_clips(player),
		6,
		"Starter profile should identify the six conventional clip roles.",
	)
	expect_equal(
		profile.idle_animation,
		&"Humanoid_Idle",
		"Idle suggestion should retain the original AnimationPlayer key.",
	)
	expect_equal(
		profile.walk_animation,
		&"Humanoid_Walk",
		"Walk suggestion should retain the original AnimationPlayer key.",
	)
	expect_equal(
		profile.run_animation,
		&"Humanoid_Run",
		"Run suggestion should retain the original AnimationPlayer key.",
	)
	expect_true(
		profile.get_validation_errors(player).is_empty(),
		"Suggested starter profile should validate against its source player.",
	)

	player.free()


func _test_rig_inspector() -> void:
	var visual := Node3D.new()
	var skeleton := Skeleton3D.new()
	var player := _build_animation_player()
	visual.add_child(skeleton)
	visual.add_child(player)

	var report := NucleusAnimationRigInspector3D.inspect(visual)

	expect_true(
		report.get("skeleton") == skeleton,
		"Rig inspector should resolve the imported Skeleton3D.",
	)
	expect_true(
		report.get("animation_player") == player,
		"Rig inspector should resolve the imported AnimationPlayer.",
	)
	expect_equal(
		int(report.get("animation_player_count", 0)),
		1,
		"Rig inspector should count animation players.",
	)
	var animations: PackedStringArray = report.get(
		"animations",
		PackedStringArray(),
	)
	expect_equal(
		animations.size(),
		15,
		"Rig inspector should expose available animation keys.",
	)

	visual.free()


func _test_starter_tree_builder() -> void:
	var root := Node3D.new()
	var player := _build_animation_player()
	var tree := AnimationTree.new()
	root.add_child(player)
	root.add_child(tree)

	expect_true(
		attach_test_node(root),
		"AnimationTree builder test requires a live SceneTree.",
	)

	var profile := _configured_profile()

	expect_equal(
		NucleusAnimationTreeBuilder3D.build_starter_tree(
			tree,
			player,
			profile,
		),
		OK,
		"Starter builder should create a native AnimationTree graph.",
	)

	var state_machine := tree.tree_root as AnimationNodeStateMachine
	expect_true(
		state_machine != null,
		"Starter tree root should be an AnimationNodeStateMachine.",
	)

	var locomotion := (
		state_machine.get_node(
			NucleusAnimationTreeBuilder3D.LOCOMOTION_STATE
		)
		as AnimationNodeBlendSpace1D
	)
	expect_true(
		locomotion != null,
		"Starter state machine should contain Locomotion BlendSpace1D.",
	)
	expect_equal(
		locomotion.get_blend_point_count(),
		3,
		"Locomotion blend space should contain idle, walk and run.",
	)
	expect_true(
		state_machine.get_node(
			NucleusAnimationTreeBuilder3D.JUMP_STATE
		) is AnimationNodeAnimation,
		"Configured jump clip should become a native state.",
	)
	expect_equal(
		tree.anim_player,
		tree.get_path_to(player),
		"Builder should wire AnimationTree to imported AnimationPlayer.",
	)
	expect_equal(
		NucleusAnimationTreeBuilder3D.build_starter_tree(
			tree,
			player,
			profile,
		),
		ERR_ALREADY_EXISTS,
		"Builder should protect an existing graph by default.",
	)

	free_test_node(root)


func _test_setup_creates_tree_and_velocity_binding() -> void:
	var body := CharacterBody3D.new()
	var visual := Node3D.new()
	var skeleton := Skeleton3D.new()
	var player := _build_animation_player()
	var setup := NucleusCharacterAnimationSetup3D.new()

	body.add_child(visual)
	visual.add_child(skeleton)
	visual.add_child(player)
	body.add_child(setup)
	setup.visual_root = visual
	setup.starter_profile = _configured_profile()

	expect_true(
		attach_test_node(body),
		"Animation setup test requires a live SceneTree.",
	)
	expect_equal(
		setup.build_starter_tree(),
		OK,
		"Setup helper should build the starter graph from resolved rig data.",
	)
	expect_true(
		setup.animation_tree != null,
		"Setup helper should create AnimationTree when requested.",
	)
	expect_true(
		setup.velocity_binding != null,
		"Setup helper should create a velocity binding for CharacterBody3D.",
	)
	expect_equal(
		setup.velocity_binding.speed_parameter,
		NucleusAnimationTreeBuilder3D.SPEED_PARAMETER,
		"Setup helper should wire standard locomotion speed parameter.",
	)

	free_test_node(body)


func _test_directional_profile_and_upgrade() -> void:
	var root := CharacterBody3D.new()
	var player := _build_animation_player()
	var tree := AnimationTree.new()
	var binding := NucleusAnimationVelocityBinding3D.new()
	root.add_child(player)
	root.add_child(tree)
	root.add_child(binding)

	expect_true(
		attach_test_node(root),
		"Directional builder test requires a live SceneTree.",
	)

	expect_equal(
		NucleusAnimationTreeBuilder3D.build_starter_tree(
			tree,
			player,
			_configured_profile(),
		),
		OK,
		"Directional upgrade requires a valid starter state machine.",
	)

	var profile := _directional_profile()

	expect_equal(
		NucleusAnimationTreeBuilder3D.upgrade_to_directional_locomotion(
			tree,
			player,
			profile,
		),
		OK,
		"Directional profile should replace only the Locomotion state.",
	)

	var state_machine := tree.tree_root as AnimationNodeStateMachine
	var locomotion := (
		state_machine.get_node(
			NucleusAnimationTreeBuilder3D.LOCOMOTION_STATE
		)
		as AnimationNodeBlendSpace2D
	)
	expect_true(
		locomotion != null,
		"Directional upgrade should create BlendSpace2D locomotion.",
	)
	expect_equal(
		locomotion.get_blend_point_count(),
		9,
		"Directional profile should include cardinals, idle and diagonals.",
	)
	expect_true(
		state_machine.has_node(NucleusAnimationTreeBuilder3D.JUMP_STATE),
		"Directional upgrade should preserve existing air states.",
	)

	expect_equal(
		NucleusAnimationTreeBuilder3D.configure_directional_velocity_binding(
			binding,
			tree,
			profile,
		),
		OK,
		"Directional builder should configure velocity transport.",
	)
	expect_equal(
		binding.blend_parameter,
		NucleusAnimationTreeBuilder3D.DIRECTION_PARAMETER,
		"Directional velocity should target Locomotion blend_position.",
	)
	expect_float(
		binding.blend_magnitude_reference,
		profile.reference_speed,
		"Directional velocity should preserve normalized speed magnitude.",
	)

	free_test_node(root)


func _test_one_shot_slot_paths() -> void:
	var slot := NucleusAnimationOneShotSlot.new()
	slot.slot_id = &"attack"
	slot.node_name = &"UpperBodyAttack"

	expect_equal(
		slot.get_request_parameter(),
		&"parameters/UpperBodyAttack/request",
		"One-shot slot should derive request parameter from native node name.",
	)
	expect_equal(
		slot.get_active_parameter(),
		&"parameters/UpperBodyAttack/active",
		"One-shot slot should derive active parameter from native node name.",
	)
	expect_true(
		slot.get_validation_errors().is_empty(),
		"A semantic one-shot slot should validate with slot and node names.",
	)

	var controller := NucleusAnimationOneShotController.new()
	controller.animation_tree = AnimationTree.new()
	expect_equal(
		controller.fire(&"missing"),
		ERR_DOES_NOT_EXIST,
		"One-shot controller should reject unknown semantic slots.",
	)
	controller.animation_tree.free()
	controller.free()


func _test_animation_event_binding() -> void:
	var root := Node.new()
	var relay := NucleusAnimationEventRelay.new()
	var binding := NucleusAnimationEventBinding.new()
	root.add_child(relay)
	root.add_child(binding)
	binding.relay = relay
	binding.event_id = &"footstep"

	var payloads: Array[Variant] = []
	binding.triggered.connect(
		func(payload: Variant) -> void:
			payloads.append(payload)
	)

	expect_true(
		attach_test_node(root),
		"Animation event binding test requires a live SceneTree.",
	)

	relay.emit_event(&"other", 1)
	relay.emit_event(&"footstep", 2)

	expect_equal(
		payloads.size(),
		1,
		"Event binding should forward only its configured event id.",
	)
	expect_equal(
		int(payloads[0]),
		2,
		"Event binding should preserve the event payload.",
	)

	free_test_node(root)


func _test_animation_quality_controller() -> void:
	var root := Node3D.new()
	var tree := AnimationTree.new()
	var modifier := LookAtModifier3D.new()
	var controller := NucleusAnimationQualityController3D.new()
	var profile := NucleusAnimationQualityProfile3D.new()

	root.add_child(tree)
	root.add_child(modifier)
	root.add_child(controller)
	controller.animation_tree = tree
	controller.quality_profile = profile
	controller.allow_pose_throttling = true
	controller.full_only_modifiers = [modifier]

	expect_true(
		attach_test_node(root),
		"Animation quality test requires a live SceneTree.",
	)

	controller.set_quality(
		NucleusAnimationQualityProfile3D.Quality.REDUCED
	)
	controller.apply_now()

	expect_false(
		modifier.active,
		"Reduced animation quality should disable full-only modifiers.",
	)
	expect_equal(
		tree.callback_mode_process,
		AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,
		"Reduced quality may use bounded manual pose evaluation.",
	)

	controller.set_quality(
		NucleusAnimationQualityProfile3D.Quality.FULL
	)
	controller.apply_now()

	expect_true(
		modifier.active,
		"Full animation quality should restore authored modifier state.",
	)
	expect_true(
		tree.callback_mode_process
		!= AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,
		"Full quality should restore native AnimationTree update mode.",
	)

	free_test_node(root)


func _configured_profile() -> NucleusAnimationStarterProfile3D:
	var profile := NucleusAnimationStarterProfile3D.new()
	profile.idle_animation = &"Humanoid_Idle"
	profile.walk_animation = &"Humanoid_Walk"
	profile.run_animation = &"Humanoid_Run"
	profile.jump_animation = &"Humanoid_Jump"
	profile.fall_animation = &"Humanoid_Fall"
	profile.land_animation = &"Humanoid_Land"
	profile.walk_speed = 2.0
	profile.run_speed = 5.0
	return profile


func _directional_profile() -> NucleusDirectionalAnimationProfile3D:
	var profile := NucleusDirectionalAnimationProfile3D.new()
	profile.idle_animation = &"Humanoid_Idle"
	profile.forward_animation = &"Strafe_Forward"
	profile.backward_animation = &"Strafe_Backward"
	profile.left_animation = &"Strafe_Left"
	profile.right_animation = &"Strafe_Right"
	profile.forward_left_animation = &"Strafe_Forward_Left"
	profile.forward_right_animation = &"Strafe_Forward_Right"
	profile.backward_left_animation = &"Strafe_Backward_Left"
	profile.backward_right_animation = &"Strafe_Backward_Right"
	profile.reference_speed = 5.0
	return profile


func _build_animation_player() -> AnimationPlayer:
	var player := AnimationPlayer.new()
	var library := AnimationLibrary.new()

	for animation_name: StringName in [
		&"Humanoid_Idle",
		&"Humanoid_Walk",
		&"Humanoid_Run",
		&"Humanoid_Jump",
		&"Humanoid_Fall",
		&"Humanoid_Land",
		&"Strafe_Forward",
		&"Strafe_Backward",
		&"Strafe_Left",
		&"Strafe_Right",
		&"Strafe_Forward_Left",
		&"Strafe_Forward_Right",
		&"Strafe_Backward_Left",
		&"Strafe_Backward_Right",
		&"Attack",
	]:
		var animation := Animation.new()
		animation.length = 1.0
		library.add_animation(animation_name, animation)

	player.add_animation_library(&"", library)
	return player
