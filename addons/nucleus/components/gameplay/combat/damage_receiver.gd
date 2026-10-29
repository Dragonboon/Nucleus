class_name NucleusDamageReceiver
extends Node
## Applies [NucleusHitPayload] damage to a [NucleusValuePool].
##
## Health semantics are created through composition:
##
## ValuePool + DamageReceiver (+ optional Regenerator)

signal hit_received(
	payload: NucleusHitPayload,
	applied_damage: float,
)
signal hit_rejected(
	payload: NucleusHitPayload,
	reason: StringName,
)
signal invulnerability_changed(active: bool)

const REASON_INVULNERABLE: StringName = &"invulnerable"
const REASON_IMMUNE_TAG: StringName = &"immune_tag"
const REASON_NO_POOL: StringName = &"no_pool"
const REASON_EMPTY_HIT: StringName = &"empty_hit"

@export var target_pool: NucleusValuePool

@export_range(0.0, 1000.0, 0.01, "or_greater")
var damage_multiplier: float = 1.0
@export var immune_tags: Array[StringName] = []

@export_group("Invulnerability")
@export var invulnerable: bool = false
@export_range(0.0, 60.0, 0.01, "or_greater")
var invulnerability_after_hit: float = 0.0
@export var invulnerability_ignores_time_scale: bool = false

var _invulnerability_timer: Timer


func _enter_tree() -> void:
	_invulnerability_timer = Timer.new()
	_invulnerability_timer.name = "InvulnerabilityTimer"
	_invulnerability_timer.one_shot = true
	_invulnerability_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_invulnerability_timer.timeout.connect(
		_on_invulnerability_timeout
	)
	add_child(_invulnerability_timer)


func _ready() -> void:
	if target_pool == null:
		target_pool = _find_value_pool()

	_invulnerability_timer.ignore_time_scale = (
		invulnerability_ignores_time_scale
	)


func get_hit_rejection_reason(payload: NucleusHitPayload) -> StringName:
	if payload == null or payload.amount <= 0.0:
		return REASON_EMPTY_HIT
	if target_pool == null:
		return REASON_NO_POOL
	if invulnerable:
		return REASON_INVULNERABLE
	if not immune_tags.is_empty() and NucleusArrayUtils.intersects(immune_tags, payload.tags):
		return REASON_IMMUNE_TAG
	return &""


func receive_hit(
	payload: NucleusHitPayload,
	already_scaled: bool = false,
) -> float:
	var reason: StringName = get_hit_rejection_reason(payload)
	if reason != &"":
		if payload != null:
			hit_rejected.emit(payload, reason)
		return 0.0

	var requested_damage: float = (
		payload.amount if already_scaled
		else payload.amount * maxf(0.0, damage_multiplier)
	)
	var delta: float = target_pool.decrease(requested_damage)
	var applied_damage: float = maxf(0.0, -delta)

	if applied_damage <= 0.0:
		hit_received.emit(payload, 0.0)
		return 0.0

	if invulnerability_after_hit > 0.0:
		set_invulnerable(
			true,
			invulnerability_after_hit,
		)

	hit_received.emit(payload, applied_damage)

	return applied_damage


func set_invulnerable(
	active: bool,
	duration: float = 0.0,
) -> void:
	var changed: bool = invulnerable != active
	invulnerable = active

	_invulnerability_timer.stop()

	if active and duration > 0.0:
		_invulnerability_timer.start(duration)

	if changed:
		invulnerability_changed.emit(invulnerable)


func _find_value_pool() -> NucleusValuePool:
	var parent: Node = get_parent()

	if parent == null:
		return null

	if parent is NucleusValuePool:
		return parent as NucleusValuePool

	for node: Node in NucleusNodeUtils.descendants(parent):
		if node is NucleusValuePool:
			return node as NucleusValuePool

	return null


func _on_invulnerability_timeout() -> void:
	set_invulnerable(false)
