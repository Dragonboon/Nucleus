@tool
class_name NucleusBulletActionEffect2D
extends NucleusActionEffect
## Commits a resource-authored pattern through an existing GameplayAction.

@export var bullet_field: NucleusBulletField2D
@export var emitter: Node2D
@export var pattern: NucleusBulletPattern2D


func can_apply(context: Dictionary) -> Error:
	if bullet_field == null or pattern == null or not pattern.is_valid():
		return ERR_UNCONFIGURED
	if emitter == null and not context.get("origin", null) is Vector2:
		return ERR_INVALID_PARAMETER
	if bullet_field.available_spawns() < pattern.count:
		return ERR_BUSY
	return OK


func apply(context: Dictionary) -> Error:
	var error := can_apply(context)
	if error != OK:
		return error
	var world_origin: Vector2 = (
		emitter.global_position if emitter != null else context["origin"]
	)
	var origin := bullet_field.to_local(world_origin)
	var direction: Vector2 = context.get("direction", Vector2.RIGHT)
	var local_direction := bullet_field.global_transform.basis_xform_inv(direction)
	var emitted := pattern.emit_into(bullet_field, origin, local_direction)
	return OK if emitted == pattern.count else ERR_BUSY


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if bullet_field == null:
		warnings.append("Assign a NucleusBulletField2D.")
	if pattern == null:
		warnings.append("Assign a NucleusBulletPattern2D.")
	return warnings
