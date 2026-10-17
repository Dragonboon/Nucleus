extends "res://tests/headless/test_case.gd"

class HalfDamage:
	extends NucleusDamageRule
	func transform_amount(_payload: NucleusHitPayload, amount: float) -> float:
		return amount * 0.5

class CountEffect:
	extends NucleusActionEffect
	var calls: int = 0
	func apply(_context: Dictionary) -> Error:
		calls += 1
		return OK


func run() -> Dictionary:
	_test_damage_and_shields()
	_test_interrupt_and_reactions()
	return finish()


func _test_damage_and_shields() -> void:
	var root := Node.new()
	var health := NucleusValuePool.new()
	health.initial_value = 100.0
	var shield := NucleusValuePool.new()
	shield.initial_value = 20.0
	var receiver := NucleusDamageReceiver.new()
	receiver.target_pool = health
	var resolver := NucleusDamageResolver.new()
	resolver.receiver = receiver
	resolver.shield_pools.append(shield)
	root.add_child(health)
	root.add_child(shield)
	root.add_child(receiver)
	root.add_child(resolver)
	expect_true(attach_test_node(root), "Combat fixture attaches.")
	var result: Dictionary = resolver.resolve_hit(NucleusHitPayload.new(30.0))
	expect_equal(result["error"], OK, "Damage pipeline accepts hit.")
	expect_float(result["absorbed"], 20.0, "Shields absorb before health.")
	expect_float(result["health_damage"], 10.0, "Only spillover reaches health.")
	expect_float(health.value, 90.0, "Health is reduced only by spillover.")
	var half := HalfDamage.new()
	resolver.rules.append(half)
	result = resolver.resolve_hit(NucleusHitPayload.new(20.0))
	expect_float(result["health_damage"], 10.0, "Transform runs before pools.")
	receiver.set_invulnerable(true)
	result = resolver.resolve_hit(NucleusHitPayload.new(20.0))
	expect_equal(result["error"], ERR_UNAVAILABLE, "Invulnerable receiver rejects.")
	expect_float(health.value, 80.0, "Rejected hit does not drain health.")
	receiver.set_invulnerable(false)
	free_test_node(root)


func _test_interrupt_and_reactions() -> void:
	var root := Node.new()
	var set := NucleusActionSet.new()
	set.actions_root = root
	var cast := NucleusGameplayAction.new()
	cast.action_id = &"cast"
	var cast_effect := CountEffect.new()
	cast.add_child(cast_effect)
	var parry := NucleusGameplayAction.new()
	parry.action_id = &"parry"
	var parry_effect := CountEffect.new()
	parry.add_child(parry_effect)
	var channel := NucleusActionChannel.new()
	channel.action = cast
	channel.windup_seconds = 1.0
	channel.minimum_interrupt_priority = 5
	var reactions := NucleusReactionCoordinator.new()
	reactions.action_set = set
	reactions.channel = channel
	var rule := NucleusReactionDefinition.new()
	rule.event_id = &"incoming_hit"
	rule.window_id = &"parry_window"
	rule.action_id = &"parry"
	rule.interrupt_priority = 5
	reactions.reactions.append(rule)
	root.add_child(cast)
	root.add_child(parry)
	root.add_child(set)
	root.add_child(channel)
	root.add_child(reactions)
	expect_true(attach_test_node(root), "Action fixture attaches.")
	expect_equal(channel.start_action(), OK, "Windup starts.")
	expect_equal(channel.interrupt_action(4), ERR_UNAVAILABLE, "Priority gate works.")
	expect_equal(reactions.react(&"incoming_hit"), ERR_DOES_NOT_EXIST, "Closed window blocks.")
	expect_equal(reactions.open_window(&"parry_window", 2.0), OK, "Window opens.")
	expect_equal(reactions.react(&"incoming_hit"), OK, "Reaction interrupts windup.")
	expect_false(channel.is_running(), "Channel is canceled.")
	expect_equal(cast_effect.calls, 0, "Canceled windup never commits.")
	expect_equal(parry_effect.calls, 1, "Reaction executes once.")
	expect_equal(channel.start_action(), OK, "Channel can restart.")
	channel.advance(1.0)
	expect_equal(cast_effect.calls, 1, "Completed windup commits once.")
	reactions.advance(2.0)
	expect_false(reactions.has_window(&"parry_window"), "Window expires.")
	free_test_node(root)
