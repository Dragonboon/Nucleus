class_name NucleusHitbox2D
extends Area2D
## 2D Area that carries damage metadata.
##
## Collision layers/masks are intentionally project-owned. Configure them in
## the Godot editor rather than relying on Nucleus global layer constants.

@export_range(0.0, 1.0e12, 0.01, "or_greater")
var amount: float = 1.0
@export var tags: Array[StringName] = []
@export var metadata: Dictionary = {}
@export var source: Node
@export var enabled: bool = true


func _init() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0


func _ready() -> void:
	if source == null:
		source = get_parent()

	set_enabled(enabled)


func set_enabled(active: bool) -> void:
	enabled = active
	set_deferred("monitorable", active)


func create_payload() -> NucleusHitPayload:
	return NucleusHitPayload.new(
		amount,
		source,
		self,
		tags,
		metadata,
	)
