class_name NucleusBulletField2D
extends Node2D
## Lightweight projectile presentation/simulation, without per-bullet Nodes.
## Authoritative damage, teams and physics collision remain game-owned.

signal bullet_expired(bullet_id: int)

@export_range(1, 200000, 1) var capacity: int = 8192
@export_range(1, 200000, 1) var max_spawns_per_frame: int = 1024
@export var projectile_radius: float = 3.0
@export var projectile_color: Color = Color.WHITE
@export var simulation_enabled: bool = true
@export var draw_enabled: bool = true
@export var cull_outside_bounds: bool = false
@export var simulation_bounds: Rect2 = Rect2(-2048, -2048, 4096, 4096)

var _position := PackedVector2Array()
var _previous := PackedVector2Array()
var _velocity := PackedVector2Array()
var _time := PackedFloat32Array()
var _ids := PackedInt32Array()
var _active: int = 0
var _next_id: int = 1
var _admitted_this_frame: int = 0


func _physics_process(delta: float) -> void:
	_admitted_this_frame = 0
	if not simulation_enabled or not is_finite(delta) or delta < 0.0:
		return
	var expired := PackedInt32Array()
	var index := _active - 1
	while index >= 0:
		_previous[index] = _position[index]
		_position[index] += _velocity[index] * delta
		_time[index] -= delta
		if _time[index] <= 0.0 or (
			cull_outside_bounds and not simulation_bounds.has_point(_position[index])
		):
			expired.append(_remove_dense(index))
		index -= 1
	if draw_enabled:
		queue_redraw()
	# Observers may clear/spawn/remove. Publish only after the dense iteration ends.
	for bullet_id: int in expired:
		bullet_expired.emit(bullet_id)


## Reserve once before a sustained encounter; active bullets and IDs are preserved.
func reserve_storage() -> Error:
	if capacity < 1 or capacity > 200000:
		return ERR_INVALID_PARAMETER
	_grow_storage(maxi(capacity, _active))
	return OK


func storage_count() -> int:
	return _ids.size()


func _grow_storage(size: int) -> void:
	if size <= _ids.size():
		return
	_ids.resize(size)
	_position.resize(size)
	_previous.resize(size)
	_velocity.resize(size)
	_time.resize(size)


func spawn(origin: Vector2, velocity: Vector2, lifetime: float) -> int:
	if not origin.is_finite() or not velocity.is_finite() or not is_finite(lifetime):
		return -1
	if lifetime <= 0.0 or _active >= capacity:
		return -1
	if _admitted_this_frame >= max_spawns_per_frame:
		return -1
	if capacity > 200000 or _next_id > 2147483647:
		return -1
	if _active == _ids.size():
		_grow_storage(mini(capacity, maxi(256, _active * 2)))
	_admitted_this_frame += 1
	var bullet_id := _next_id
	_next_id += 1
	_ids[_active] = bullet_id
	_position[_active] = origin
	_previous[_active] = origin
	_velocity[_active] = velocity
	_time[_active] = lifetime
	_active += 1
	if draw_enabled:
		queue_redraw()
	return bullet_id


func spawn_radial(
	center: Vector2,
	speed: float,
	count: int,
	lifetime: float,
	initial_angle: float = 0.0,
) -> int:
	if count <= 0 or count > capacity or not is_finite(speed):
		return 0
	var emitted := 0
	for i in range(count):
		var angle := initial_angle + TAU * float(i) / float(count)
		if spawn(center, Vector2.from_angle(angle) * speed, lifetime) < 0:
			break
		emitted += 1
	return emitted


func spawn_fan(
	center: Vector2,
	speed: float,
	count: int,
	lifetime: float,
	direction: float,
	spread: float,
) -> int:
	if count <= 0 or count > capacity or not is_finite(speed):
		return 0
	var emitted := 0
	for i in range(count):
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		var angle := direction + (t - 0.5) * spread
		if spawn(center, Vector2.from_angle(angle) * speed, lifetime) < 0:
			break
		emitted += 1
	return emitted


func active_count() -> int:
	return _active


func available_spawns() -> int:
	return maxi(0, mini(capacity - _active, max_spawns_per_frame - _admitted_this_frame))


func clear_bullets() -> void:
	_active = 0
	queue_redraw()


func remove_at(index: int) -> bool:
	if index < 0 or index >= _active:
		return false
	var bullet_id := _remove_dense(index)
	bullet_expired.emit(bullet_id)
	if draw_enabled:
		queue_redraw()
	return true


func _remove_dense(index: int) -> int:
	var bullet_id := _ids[index]
	var last := _active - 1
	if index != last:
		_ids[index] = _ids[last]
		_position[index] = _position[last]
		_previous[index] = _previous[last]
		_velocity[index] = _velocity[last]
		_time[index] = _time[last]
	_active -= 1
	return bullet_id


func bullet_id_at(index: int) -> int:
	return _ids[index] if index >= 0 and index < _active else -1


func bullet_position_at(index: int) -> Vector2:
	return _position[index] if index >= 0 and index < _active else Vector2.ZERO


func bullet_previous_at(index: int) -> Vector2:
	return _previous[index] if index >= 0 and index < _active else Vector2.ZERO


func get_bullet(index: int) -> Dictionary:
	if index < 0 or index >= _active:
		return {}
	return {
		"id": _ids[index],
		"position": _position[index],
		"previous_position": _previous[index],
		"velocity": _velocity[index],
		"remaining": _time[index],
	}


func query_swept_circle(center: Vector2, radius: float) -> PackedInt32Array:
	## Returns IDs, not damage events; caller resolves ownership and hits.
	var result := PackedInt32Array()
	if not center.is_finite() or not is_finite(radius) or radius < 0.0:
		return result
	var limit := radius + maxf(projectile_radius, 0.0)
	var squared := limit * limit
	for i in range(_active):
		var a := _previous[i]
		var b := _position[i]
		var ab := b - a
		var length_sq := ab.length_squared()
		var fraction := 0.0
		if length_sq > 0.0:
			fraction = clampf((center - a).dot(ab) / length_sq, 0.0, 1.0)
		var closest := a + ab * fraction
		if center.distance_squared_to(closest) <= squared:
			result.append(_ids[i])
	return result


func _draw() -> void:
	if not draw_enabled:
		return
	for i in range(_active):
		draw_circle(_position[i], maxf(projectile_radius, 0.0), projectile_color)
