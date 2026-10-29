class_name NucleusTransientSurfaceBatch3D
extends Node3D
## Bounded MultiMesh batch for short-lived world-space surface effects.
##
## The batch owns transform/color/lifetime transport only. Surface queries,
## effect meaning and authored material/shader content stay game-owned.

signal effect_emitted
signal effect_rejected

@export_range(0, 100000, 1, "or_greater")
var capacity: int = 128

@export var draw_mesh: Mesh
@export var material_override: Material

@export_group("Lifetime presentation")
@export_range(0.0, 1.0, 0.01)
var fade_in_ratio: float = 0.12
@export_range(0.0, 1.0, 0.01)
var fade_out_start_ratio: float = 0.55

@export_group("Bounds")
@export var auto_update_bounds: bool = true
@export_range(0.0, 1000.0, 0.01, "or_greater")
var bounds_padding: float = 0.25

var _records: Array[Dictionary] = []
var _replacement_cursor: int = 0
var _instance: MultiMeshInstance3D
var _multimesh: MultiMesh
var _fallback_mesh: QuadMesh


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return

	if DisplayServer.get_name() != "headless":
		_ensure_render_resources()

	_sync_render_data()
	set_process(not _records.is_empty())


func _process(delta: float) -> void:
	advance(delta)


func emit_surface(
	world_position: Vector3,
	world_normal: Vector3,
	size: Vector2,
	lifetime: float,
	color: Color = Color.WHITE,
	end_scale: Vector2 = Vector2.ONE,
	tangent_hint: Vector3 = Vector3.ZERO,
) -> bool:
	if (
		capacity <= 0
		or lifetime <= 0.0
		or world_normal.is_zero_approx()
		or not world_position.is_finite()
	):
		effect_rejected.emit()
		return false

	_trim_to_capacity()

	var record := {
		"position": world_position,
		"basis": _surface_basis(world_normal, tangent_hint),
		"size": Vector2(
			maxf(absf(size.x), 0.001),
			maxf(absf(size.y), 0.001),
		),
		"age": 0.0,
		"lifetime": lifetime,
		"color": color,
		"end_scale": Vector2(
			maxf(end_scale.x, 0.001),
			maxf(end_scale.y, 0.001),
		),
	}

	if _records.size() < capacity:
		_records.append(record)
	else:
		var index := _replacement_cursor % _records.size()
		_records[index] = record
		_replacement_cursor += 1

	if is_inside_tree():
		set_process(true)
		_sync_render_data()

	effect_emitted.emit()
	return true


func advance(delta: float) -> void:
	if delta <= 0.0:
		return

	_trim_to_capacity()

	for index: int in range(_records.size() - 1, -1, -1):
		var record: Dictionary = _records[index]
		record["age"] = float(record["age"]) + delta

		if float(record["age"]) >= float(record["lifetime"]):
			_records[index] = _records[-1]
			_records.pop_back()
		else:
			_records[index] = record

	_sync_render_data()

	if _records.is_empty() and is_inside_tree():
		set_process(false)


func clear() -> void:
	_records.clear()
	_replacement_cursor = 0
	_sync_render_data()

	if is_inside_tree():
		set_process(false)


func get_active_count() -> int:
	return _records.size()


func get_multimesh_instance() -> MultiMeshInstance3D:
	return _instance


func _trim_to_capacity() -> void:
	var resolved_capacity := maxi(capacity, 0)

	while _records.size() > resolved_capacity:
		_records.pop_back()

	if _records.is_empty():
		_replacement_cursor = 0
	else:
		_replacement_cursor %= _records.size()


func _ensure_render_resources() -> void:
	if _instance != null:
		return

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = _resolve_mesh()
	_multimesh.instance_count = maxi(capacity, 1)
	_multimesh.visible_instance_count = 0

	_instance = MultiMeshInstance3D.new()
	_instance.name = "TransientSurfaceBatch"
	_instance.multimesh = _multimesh
	_instance.material_override = material_override
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_instance)
	_instance.set_as_top_level(true)
	_instance.global_transform = Transform3D.IDENTITY


func _resolve_mesh() -> Mesh:
	if draw_mesh != null:
		return draw_mesh

	_fallback_mesh = QuadMesh.new()
	_fallback_mesh.size = Vector2.ONE
	return _fallback_mesh


func _sync_render_data() -> void:
	if _multimesh == null:
		return

	var resolved_capacity := maxi(capacity, 0)
	var required_capacity := maxi(resolved_capacity, 1)

	if _multimesh.instance_count != required_capacity:
		_multimesh.instance_count = required_capacity

	var visible_count := mini(_records.size(), resolved_capacity)
	_multimesh.visible_instance_count = visible_count

	var bounds_min := Vector3.ZERO
	var bounds_max := Vector3.ZERO
	var has_bounds := false

	for index: int in range(visible_count):
		var record: Dictionary = _records[index]
		var age := float(record["age"])
		var lifetime := maxf(float(record["lifetime"]), 0.001)
		var t := clampf(age / lifetime, 0.0, 1.0)
		var size: Vector2 = record["size"]
		var end_scale: Vector2 = record["end_scale"]
		var growth := Vector2(
			lerpf(1.0, end_scale.x, t),
			lerpf(1.0, end_scale.y, t),
		)
		var basis: Basis = record["basis"]
		basis = basis.scaled(
			Vector3(
				size.x * growth.x,
				size.y * growth.y,
				1.0,
			)
		)
		var position: Vector3 = record["position"]
		_multimesh.set_instance_transform(
			index,
			Transform3D(basis, position),
		)

		var color: Color = record["color"]
		color.a *= _fade_alpha(t)
		_multimesh.set_instance_color(index, color)

		if auto_update_bounds:
			var radius := (
				maxf(size.x * growth.x, size.y * growth.y) * 0.5
				+ bounds_padding
			)
			var item_min := position - Vector3.ONE * radius
			var item_max := position + Vector3.ONE * radius

			if not has_bounds:
				bounds_min = item_min
				bounds_max = item_max
				has_bounds = true
			else:
				bounds_min = bounds_min.min(item_min)
				bounds_max = bounds_max.max(item_max)

	if auto_update_bounds and has_bounds:
		_multimesh.custom_aabb = AABB(
			bounds_min,
			bounds_max - bounds_min,
		)


func _fade_alpha(t: float) -> float:
	var fade_in := 1.0

	if fade_in_ratio > 0.0:
		fade_in = smoothstep(
			0.0,
			clampf(fade_in_ratio, 0.0, 1.0),
			t,
		)

	var fade_out := 1.0
	var fade_start := clampf(fade_out_start_ratio, 0.0, 1.0)

	if t >= fade_start:
		fade_out = 1.0 - smoothstep(
			fade_start,
			1.0,
			t,
		)

	return fade_in * fade_out


func _surface_basis(
	world_normal: Vector3,
	tangent_hint: Vector3,
) -> Basis:
	var normal := world_normal.normalized()
	var tangent := tangent_hint - normal * tangent_hint.dot(normal)

	if tangent.length_squared() <= 0.000001:
		var reference := (
			Vector3.UP
			if absf(normal.dot(Vector3.UP)) < 0.95
			else Vector3.RIGHT
		)
		tangent = reference.cross(normal)

	tangent = tangent.normalized()
	var bitangent := normal.cross(tangent).normalized()
	return Basis(tangent, bitangent, normal)
