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
	if is_visible_in_tree():
		sync_bullets()


func sync_bullets() -> void:
	if multimesh == null:
		return
	if not is_instance_valid(bullet_field) or is_zero_approx(global_transform.determinant()):
		multimesh.visible_instance_count = 0
		return
	var count := mini(bullet_field.active_count(), multimesh.instance_count)
	var mapping := global_transform.affine_inverse() * bullet_field.global_transform
	for i in range(count):
		var local_point := mapping * bullet_field.bullet_position_at(i)
		multimesh.set_instance_transform_2d(i, Transform2D(0.0, local_point))
	multimesh.visible_instance_count = count


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if bullet_field == null:
		warnings.append("Assign a NucleusBulletField2D.")
	return warnings
