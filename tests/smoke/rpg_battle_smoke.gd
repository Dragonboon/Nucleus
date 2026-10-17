extends Node
## Scripted end-to-end acceptance. All actors and rules are intentionally local.
## Use F6 or run headlessly. No global RPG service, renderer or gameplay loop.

var _failed: PackedStringArray = []
var _finished: bool = false


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed.append(message)


func _run() -> void:
	var actor := Node.new()
	actor.name = "Hero"
	add_child(actor)

	var mana := NucleusValuePool.new()
	mana.name = "Mana"
	mana.initial_value = 30.0
	actor.add_child(mana)
	var track_def := NucleusProgressionDefinition.new()
	track_def.track_id = &"hero"
	track_def.thresholds = PackedInt64Array([10])
	var track := NucleusProgressionTrack.new()
	track.definition = track_def
	actor.add_child(track)
	var skill := NucleusUnlockDefinition.new()
	skill.unlock_id = &"strike"
	var graph := NucleusUnlockGraph.new()
	graph.progression = track
	graph.initial_points = 1
	graph.definitions = [skill]
	actor.add_child(graph)

	var actions := NucleusActionSet.new()
	actions.name = "Actions"
	actor.add_child(actions)
	actions.actions_root = actions
	var strike := NucleusGameplayAction.new()
	strike.action_id = &"strike"
	var cost := NucleusValuePoolCost.new()
	cost.target_pool = mana
	cost.amount = 5.0
	strike.add_child(cost)
	var rank_gate := NucleusUnlockRequirement.new()
	rank_gate.unlock_graph = graph
	rank_gate.unlock_id = &"strike"
	strike.add_child(rank_gate)
	actions.add_child(strike)
	var loadout := NucleusAbilityLoadout.new()
	loadout.action_set = actions
	loadout.unlock_graph = graph
	actor.add_child(loadout)

	var enemy := Node.new()
	enemy.name = "Enemy"
	add_child(enemy)
	var hp := NucleusValuePool.new()
	hp.initial_value = 20.0
	enemy.add_child(hp)
	var barrier := NucleusValuePool.new()
	barrier.initial_value = 6.0
	enemy.add_child(barrier)
	var receiver := NucleusDamageReceiver.new()
	receiver.target_pool = hp
	enemy.add_child(receiver)
	var resolver := NucleusDamageResolver.new()
	resolver.receiver = receiver
	resolver.shield_pools.append(barrier)
	enemy.add_child(resolver)
	var statuses := NucleusStatusEffectContainer.new()
	enemy.add_child(statuses)
	var poison := NucleusStatusEffectDefinition.new()
	poison.effect_id = &"poison"
	poison.duration = 5.0

	var damage := NucleusApplyDamageEffect.new()
	damage.resolve_from_context = true
	damage.amount = 12.0
	strike.add_child(damage)
	var apply_status := NucleusApplyStatusEffect.new()
	apply_status.definition = poison
	apply_status.target_container = statuses
	strike.add_child(apply_status)
	strike.refresh_parts()
	var channel := NucleusActionChannel.new()
	channel.action = strike
	channel.windup_seconds = 1.0
	channel.minimum_interrupt_priority = 2
	actor.add_child(channel)
	var stagger := NucleusDamageInterruptBinding.new()
	stagger.resolver = resolver
	stagger.channel = channel
	stagger.interrupt_priority = 2
	actor.add_child(stagger)

	# New nodes run _ready() when attached. Registry needs explicit rebuild
	# because this authored fixture adds actions after the owner became ready.
	actions.rebuild_registry()
	_check(loadout.assign(&"primary", &"strike") == ERR_UNAVAILABLE,
		"Locked ability cannot be assigned.")
	_check(graph.unlock(&"strike") == OK, "Ability unlocks.")
	_check(loadout.assign(&"primary", &"strike") == OK, "Ability assigned.")
	_check(loadout.execute_slot(&"primary", {"target": enemy}) == OK,
		"Ability executed using target-scoped DamageResolver.")
	_check(is_equal_approx(barrier.value, 0.0), "Shield drained first.")
	_check(is_equal_approx(hp.value, 14.0), "Remaining damage reached health.")
	_check(is_equal_approx(mana.value, 25.0), "Mana cost paid exactly once.")
	_check(statuses.has_effect(&"poison"), "Status applied by the same ability.")

	_check(channel.start_action({"target": enemy}) == OK, "Cast starts.")
	_check(channel.interrupt_action(1) == ERR_UNAVAILABLE,
		"Insufficient interrupt priority is rejected.")
	_check(channel.interrupt_action(2) == OK, "Valid interruption succeeds.")
	_check(channel.start_action({"target": enemy}) == OK, "Cast restarts.")
	channel.advance(1.0)
	_check(is_equal_approx(hp.value, 2.0), "Cast commits after windup.")
	_check(track.grant_experience(10) == OK, "Experience awarded.")
	_check(track.level == 2, "Level advances.")

	var first := NucleusEncounterWave.new()
	first.participant_ids = [&"goblin"]
	first.counts = PackedInt32Array([2])
	var second := NucleusEncounterWave.new()
	second.participant_ids = [&"boss"]
	second.counts = PackedInt32Array([1])
	var definition := NucleusEncounterDefinition.new()
	definition.encounter_id = &"cave"
	definition.waves = [first, second]
	var director := NucleusEncounterDirector.new()
	director.definition = definition
	add_child(director)
	var finished: Array[StringName] = []
	director.encounter_completed.connect(
		func(id: StringName) -> void: finished.append(id)
	)
	_check(director.start_encounter() == OK, "Encounter starts.")
	_check(director.get_remaining().get(&"goblin", 0) == 2,
		"First wave contains both enemies.")
	_check(director.mark_defeated(&"goblin", 2) == OK,
		"Wave advances after both defeats.")
	_check(director.get_remaining().get(&"boss", 0) == 1,
		"Second wave contains boss.")
	_check(director.mark_defeated(&"boss") == OK, "Boss defeated.")
	_check(finished == [&"cave"], "Encounter completes exactly once.")
	_report()


func _report() -> void:
	if _finished:
		return
	_finished = true
	if _failed.is_empty():
		print("RPG_BATTLE_SMOKE: PASS")
		get_tree().quit(0)
		return
	for message: String in _failed:
		push_error("RPG_BATTLE_SMOKE: " + message)
	get_tree().quit(1)
