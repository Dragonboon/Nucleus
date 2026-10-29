class_name NucleusHurtbox2D
extends Area2D
## 2D Area that converts overlapping Nucleus hitboxes into runtime hit payloads.

signal hit_detected(
	payload: NucleusHitPayload,
	hitbox: NucleusHitbox2D,
)

@export var receiver: NucleusDamageReceiver
@export var enabled: bool = true


func _init() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0


func _ready() -> void:
	if receiver == null:
		receiver = _find_receiver()

	area_entered.connect(_on_area_entered)
	set_enabled(enabled)


func set_enabled(active: bool) -> void:
	enabled = active
	set_deferred("monitoring", active)


func _find_receiver() -> NucleusDamageReceiver:
	var parent: Node = get_parent()

	if parent == null:
		return null

	for node: Node in NucleusNodeUtils.descendants(parent):
		if node is NucleusDamageReceiver:
			return node as NucleusDamageReceiver

	return null


func _on_area_entered(area: Area2D) -> void:
	if not enabled or not (area is NucleusHitbox2D):
		return

	var hitbox := area as NucleusHitbox2D
	var payload: NucleusHitPayload = hitbox.create_payload()

	hit_detected.emit(payload, hitbox)

	if receiver:
		receiver.receive_hit(payload)
