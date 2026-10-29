class_name NucleusHitPayload
extends RefCounted
## Runtime data passed from a hitbox to a damage receiver.
##
## This is deliberately not a Resource: source Nodes and runtime metadata are
## transient and should not be shared as editor assets.

var amount: float = 0.0
var source: Node
var hitbox: Node
var tags: Array[StringName] = []
var metadata: Dictionary = {}


func _init(
	hit_amount: float = 0.0,
	hit_source: Node = null,
	hit_hitbox: Node = null,
	hit_tags: Array[StringName] = [],
	hit_metadata: Dictionary = {},
) -> void:
	amount = maxf(0.0, hit_amount)
	source = hit_source
	hitbox = hit_hitbox
	tags = hit_tags.duplicate()
	metadata = hit_metadata.duplicate(true)


func has_tag(tag: StringName) -> bool:
	return tag in tags
