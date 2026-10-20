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

var _position := PackedVector2Array()
var _previous := PackedVector2Array()
var _velocity := PackedVector2Array()
var _time := PackedFloat32Array()
var _ids := PackedInt32Array()
var _next_id: int = 1
var _admitted_this_frame: int = 0


func _physics_process(delta: float) -> void:
	_admitted_this_frame = 0
	if not simulation_enabled:
		return
	var index := _ids.size() - 1
	while index >= 0:
		_previous[index] = _position[index]
		_position[index] += _velocity[index] * maxf(delta, 0.0)
		_time[index] -= maxf(delta, 0.0)
		if _time[index] <= 0.0:
			remove_at(index)
		index -= 1
	queue_redraw()


func spawn(origin: Vector2, velocity: Vector2, lifetime: float) -> int:
	if not origin.is_finite() or not velocity.is_finite() or not is_finite(lifetime):
		return -1
	if lifetime <= 0.0 or _ids.size() >= capacity:
		return -1
	if _admitted_this_frame >= max_spawns_per_frame:
		return -1
	_admitted_this_frame += 1
	var bullet_id := _next_id
	_next_id += 1
	_ids.append(bullet_id)
	_position.append(origin)
	_previous.append(origin)
	_velocity.append(velocity)
	_time.append(lifetime)
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
	return _ids.size()


func available_spawns() -> int:
	return maxi(0, mini(capacity - _ids.size(), max_spawns_per_frame - _admitted_this_frame))


func clear_bullets() -> void:
	_ids.clear()
	_position.clear()
	_previous.clear()
	_velocity.clear()
	_time.clear()
	queue_redraw()


func remove_at(index: int) -> bool:
	if index < 0 or index >= _ids.size():
		return false
	var bullet_id := _ids[index]
	var last := _ids.size() - 1
	if index != last:
		_ids[index] = _ids[last]
		_position[index] = _position[last]
		_previous[index] = _previous[last]
		_velocity[index] = _velocity[last]
		_time[index] = _time[last]
	_ids.resize(last)
	_position.resize(last)
	_previous.resize(last)
	_velocity.resize(last)
	_time.resize(last)
	bullet_expired.emit(bullet_id)
	queue_redraw()
	return true


func bullet_id_at(index: int) -> int:
	return _ids[index] if index >= 0 and index < _ids.size() else -1


func bullet_position_at(index: int) -> Vector2:
	return _position[index] if index >= 0 and index < _position.size() else Vector2.ZERO


func bullet_previous_at(index: int) -> Vector2:
	return _previous[index] if index >= 0 and index < _previous.size() else Vector2.ZERO


func get_bullet(index: int) -> Dictionary:
	if index < 0 or index >= _ids.size():
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
	for i in range(_ids.size()):
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
	for i in range(_position.size()):
		draw_circle(_position[i], maxf(projectile_radius, 0.0), projectile_color)
