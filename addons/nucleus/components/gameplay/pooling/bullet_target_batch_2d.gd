class_name NucleusBulletTargetBatch2D
extends RefCounted
## Exact swept-circle candidates from the existing NucleusSpatialRectIndex2D.
## The consuming game owns damage, authority, piercing, and hit deduplication.

const MAX_HITS_PER_QUERY: int = 16384

var _index := NucleusSpatialRectIndex2D.new()
var _targets: Dictionary = {}
var _candidates: Array[int] = []
var _query_scratch: Dictionary = {}


func configure_cell_size(value: float) -> Error:
	return _index.configure_cell_size(value)


func upsert_circle(target_id: int, center: Vector2, radius: float) -> Error:
	if target_id < 0 or not center.is_finite():
		return ERR_INVALID_PARAMETER
	if not is_finite(radius) or radius < 0.0:
		return ERR_INVALID_PARAMETER
	var extent := Vector2.ONE * radius
	var error := _index.upsert(target_id, Rect2(center - extent, extent * 2.0))
	if error != OK:
		return error
	_targets[target_id] = {"center": center, "radius": radius}
	return OK


func remove_target(target_id: int) -> bool:
	_targets.erase(target_id)
	return _index.remove(target_id)


func clear() -> void:
	_index.clear()
	_targets.clear()


func target_count() -> int:
	return _targets.size()


func query_bullet_hits(
	field: NucleusBulletField2D,
	maximum_pairs: int = 4096,
) -> Array[Vector2i]:
	## Each result is Vector2i(bullet_id, target_id), in field-local space.
	var results: Array[Vector2i] = []
	if maximum_pairs > 0:
		query_bullet_hits_into(field, results, maximum_pairs)
	return results


## Reuses caller output and per-batch broad-phase scratch. No callbacks/reentrancy.
## A result cap is not a CPU budget. Use 0 for all hits, with game-owned memory limits.
func query_bullet_hits_into(
	field: NucleusBulletField2D,
	results: Array[Vector2i],
	maximum_pairs: int = 0,
) -> void:
	results.clear()
	if not is_instance_valid(field) or maximum_pairs < 0:
		return
	if _targets.is_empty():
		return
	var budget := mini(maximum_pairs, MAX_HITS_PER_QUERY)
	var bullet_radius := maxf(field.projectile_radius, 0.0)
	for bullet_index in range(field.active_count()):
		var previous := field.bullet_previous_at(bullet_index)
		var current := field.bullet_position_at(bullet_index)
		var low := Vector2(
			minf(previous.x, current.x), minf(previous.y, current.y),
		)
		var high := Vector2(
			maxf(previous.x, current.x), maxf(previous.y, current.y),
		)
		var margin := Vector2.ONE * maxf(0.001, bullet_radius)
		var broad_phase := Rect2(low - margin, high - low + margin * 2.0)
		_index.query_region_into(broad_phase, _candidates, _query_scratch)
		for target_id: int in _candidates:
			var target: Dictionary = _targets[target_id]
			var center: Vector2 = target["center"]
			var radius: float = float(target["radius"]) + bullet_radius
			var nearest := Geometry2D.get_closest_point_to_segment(
				center, previous, current,
			)
			if nearest.distance_squared_to(center) <= radius * radius:
				results.append(Vector2i(field.bullet_id_at(bullet_index), target_id))
				if budget > 0 and results.size() >= budget:
					return
