extends Node2D
## Composition fixture, not a game shell. Native timers/animation/Tweens run for real.

const Fixture = preload("res://tests/fixtures/presentation/sprite_fixture.gd")
var _failures: PackedStringArray = []
var _finished: Array[StringName] = []
var _last_label: Label


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var presenter: NucleusFloatingTextPresenter2D = $Feedback
	presenter.profile = NucleusFloatingTextProfile2D.new()
	presenter.profile.duration = 0.15
	presenter.reduced_motion = true
	var sprite: AnimatedSprite2D = $Actor/Sprite
	var animator: NucleusDirectionalSpriteAnimator2D = $Actor/Animator
	var settings := Fixture.profile(true)
	sprite.sprite_frames = Fixture.frames(settings)
	_check(animator.configure(sprite, settings) == OK, "Animation composition binds.")
	animator.action_finished.connect(func(id: StringName) -> void: _finished.append(id))
	var receiver: NucleusDamageReceiver = $Actor/Receiver
	var health: NucleusValuePool = $Actor/Health
	receiver.hit_received.connect(func(_payload: NucleusHitPayload, applied: float) -> void:
		if applied > 0.0:
			_last_label = presenter.show_number(applied, $Actor.global_position))
	var agent := NucleusTargetingAgent.new()
	add_child(agent)
	agent.register_candidate($Actor/Targetable)
	agent.refresh_selection()
	agent.lock_current()
	receiver.receive_hit(NucleusHitPayload.new(3.0))
	_check(is_instance_valid(_last_label) and _last_label.text == "3", "Confirmed hit shows 3.")
	var starting_point := _last_label.position
	receiver.set_invulnerable(true)
	receiver.receive_hit(NucleusHitPayload.new(7.0))
	_check(presenter.get_visible_count() == 1, "Rejected hit adds no label.")
	_check(health.value == 7.0, "Presentation never changes health.")
	animator.update_motion(Vector2.DOWN * 10)
	animator.play_action(&"use")
	await get_tree().create_timer(0.05).timeout
	_check(_last_label.position.is_equal_approx(starting_point), "Reduced motion holds position.")
	await get_tree().create_timer(0.2).timeout
	_check(_finished == [&"use"], "Native animation emits one completion.")
	_check(sprite.animation == &"move_d", "Completion returns to current locomotion.")
	_check(presenter.get_visible_count() == 0, "Tween completion releases local budget.")
	_check(not is_instance_valid(_last_label), "Completed label is freed.")
	animator.play_action(&"end", false, true)
	await get_tree().create_timer(0.2).timeout
	_check(_finished == [&"use", &"end"], "Terminal action completes once.")
	animator.update_motion(Vector2.LEFT * 10)
	_check(sprite.animation == &"end_d", "Held terminal pose survives motion updates.")
	_check(animator.play_action(&"use") == ERR_BUSY, "Held pose blocks accidental actions.")
	animator.cancel_action()
	_check(sprite.animation == &"move_l", "Explicit cancel releases terminal pose.")
	receiver.set_invulnerable(false)
	receiver.receive_hit(NucleusHitPayload.new(100.0))
	_check(_last_label.text == "7", "Overkill displays only applied damage.")
	$Actor.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(agent.current == null and not agent.is_locked(), "Actor deletion clears targeting.")
	_check(presenter.get_visible_count() == 1, "Feedback can outlive damaged actor.")
	presenter.clear()
	await get_tree().process_frame
	_check(presenter.get_visible_count() == 0, "Scene-owned cleanup clears remaining feedback.")
	if _failures.is_empty():
		print("Nucleus presentation 2D composition: PASS")
	else:
		for failure: String in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
