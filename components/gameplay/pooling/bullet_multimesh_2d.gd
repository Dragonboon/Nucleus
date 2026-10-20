@tool
class_name NucleusBulletMultiMesh2D
extends MultiMeshInstance2D
## Optional native batched renderer; BulletField2D retains simulation ownership.

@export var bullet_field: NucleusBulletField2D
@export_range(1, 200000, 1) var max_instances: int = 8192
@export_range(0.1, 100.0, 0.1) var quad_size: float = 6.0


func _ready() -> void:
	rebuild_mesh()


func rebuild_mesh() -> void:
	var data := MultiMesh.new()
	data.transform_format = MultiMesh.TRANSFORM_2D
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * maxf(quad_size, 0.1)
	data.mesh = quad
	data.instance_count = maxi(max_instances, 1)
	data.visible_instance_count = 0
	multimesh = data


func _process(_delta: float) -> void:
	sync_bullets()


func sync_bullets() -> void:
	if bullet_field == null or multimesh == null:
		return
	var count := mini(bullet_field.active_count(), multimesh.instance_count)
	for i in range(count):
		var bullet: Dictionary = bullet_field.get_bullet(i)
		var source: Vector2 = bullet["position"]
		var global_point := bullet_field.to_global(source)
		var local_point := to_local(global_point)
		multimesh.set_instance_transform_2d(i, Transform2D(0.0, local_point))
	multimesh.visible_instance_count = count


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if bullet_field == null:
		warnings.append("Assign a NucleusBulletField2D.")
	return warnings
