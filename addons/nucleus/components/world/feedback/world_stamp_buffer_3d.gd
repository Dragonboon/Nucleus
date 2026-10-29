class_name NucleusWorldStampBuffer3D
extends Node
## Bounded scene-owned world-space history for transient visual marks.
##
## The buffer stores stamp data in world X/Z coordinates. Rendering is optional
## and delegated to NucleusWorldStampViewport3D.

signal stamp_emitted(stamp: NucleusWorldStamp3D)
signal cleared
signal center_changed(center: Vector3)
signal time_advanced(elapsed_time: float)
signal emitter_reset(emitter_id: int)

@export_group("Coverage")
@export var center: Vector3 = Vector3.ZERO
@export var coverage_size: Vector2 = Vector2(64.0, 64.0):
	set(value):
		coverage_size = Vector2(
			maxf(absf(value.x), 0.01),
			maxf(absf(value.y), 0.01),
		)
@export_range(1, 100000, 1, "or_greater")
var max_stamps: int = 384:
	set(value):
		max_stamps = maxi(value, 1)
		_trim_to_capacity()
@export_range(0.0, 1.0, 0.01)
var acceptance_margin: float = 0.1

@export_group("Lifetime")
@export_range(0.001, 3600.0, 0.001, "or_greater")
var default_lifetime: float = 4.0
@export var auto_advance: bool = true

@export_group("Motion emission")
@export_range(0.001, 1000.0, 0.001, "or_greater")
var motion_spacing: float = 0.45
@export_range(1, 256, 1, "or_greater")
var max_motion_stamps_per_call: int = 8
@export_range(0.01, 1.0, 0.01)
var motion_break_distance_ratio: float = 0.25
@export_range(1, 1024, 1, "or_greater")
var max_emitters: int = 32
@export_range(0.1, 100.0, 0.1, "or_greater")
var emitter_timeout_multiplier: float = 2.0

var elapsed_time: float = 0.0

var _stamps: Array[NucleusWorldStamp3D] = []
var _emitters: Dictionary = {}
var _replace_cursor: int = 0


func _process(delta: float) -> void:
	if auto_advance:
		advance(delta)


func advance(delta: float) -> void:
	if delta <= 0.0:
		return

	elapsed_time += delta
	time_advanced.emit(elapsed_time)


func set_center(value: Vector3) -> void:
	if center.is_equal_approx(value):
		return

	center = value
	center_changed.emit(center)


func clear() -> void:
	_stamps.clear()
	_emitters.clear()
	_replace_cursor = 0
	cleared.emit()


func clear_emitter(emitter_id: int) -> void:
	if not _emitters.has(emitter_id):
		return

	_emitters.erase(emitter_id)
	emitter_reset.emit(emitter_id)


func emit_stamp(
	world_position: Vector3,
	dimensions: Vector2 = Vector2.ONE,
	rotation: float = 0.0,
	strength: float = 1.0,
	lifetime: float = -1.0,
	drift: Vector3 = Vector3.ZERO,
	growth: Vector2 = Vector2.ZERO,
	metadata: Dictionary = {},
) -> NucleusWorldStamp3D:
	if max_stamps <= 0 or not contains_world_position(world_position):
		return null

	var resolved_lifetime := (
		lifetime
		if lifetime > 0.0
		else default_lifetime
	)
	var stamp := NucleusWorldStamp3D.new(
		world_position,
		dimensions,
		rotation,
		strength,
		resolved_lifetime,
		elapsed_time,
		drift,
		growth,
		metadata,
	)

	if _stamps.size() < max_stamps:
		_stamps.append(stamp)
	else:
		_stamps[_replace_cursor % _stamps.size()] = stamp
		_replace_cursor = (_replace_cursor + 1) % max_stamps

	stamp_emitted.emit(stamp)
	return stamp


func emit_motion(
	emitter_id: int,
	world_position: Vector3,
	width: float = 1.0,
	strength: float = 1.0,
	spacing_override: float = -1.0,
	lifetime: float = -1.0,
	drift: Vector3 = Vector3.ZERO,
	growth: Vector2 = Vector2.ZERO,
	metadata: Dictionary = {},
) -> int:
	var position_xz := Vector2(world_position.x, world_position.z)
	var spacing := (
		spacing_override
		if spacing_override > 0.0
		else motion_spacing
	)
	spacing = maxf(spacing, 0.001)

	if not _emitters.has(emitter_id):
		if not _try_reserve_emitter_slot():
			return 0
		_store_emitter(emitter_id, position_xz)
		return 0

	var state: Dictionary = _emitters[emitter_id]
	var previous: Vector2 = state["point"]
	var distance := previous.distance_to(position_xz)
	var break_distance := minf(coverage_size.x, coverage_size.y)
	break_distance *= motion_break_distance_ratio

	if distance > break_distance:
		_store_emitter(emitter_id, position_xz)
		emitter_reset.emit(emitter_id)
		return 0

	var count := mini(
		int(floor(distance / spacing)),
		maxi(max_motion_stamps_per_call, 1),
	)

	if count <= 0:
		state["time"] = elapsed_time
		_emitters[emitter_id] = state
		return 0

	var direction := (position_xz - previous).normalized()
	var emitted := 0
	var last_point := previous

	for index: int in range(count):
		var point_xz := previous + direction * spacing * float(index + 1)
		var point := Vector3(point_xz.x, world_position.y, point_xz.y)
		var stamp := emit_stamp(
			point,
			Vector2(maxf(width, 0.001), spacing * 2.0),
			direction.angle() - PI * 0.5,
			strength,
			lifetime,
			drift,
			growth,
			metadata,
		)

		last_point = point_xz
		if stamp != null:
			emitted += 1

	_store_emitter(emitter_id, last_point)
	return emitted


func contains_world_position(world_position: Vector3) -> bool:
	var half_size := coverage_size * 0.5
	var margin := coverage_size * clampf(acceptance_margin, 0.0, 1.0)
	var relative := Vector2(
		world_position.x - center.x,
		world_position.z - center.z,
	)

	return (
		absf(relative.x) <= half_size.x + margin.x
		and absf(relative.y) <= half_size.y + margin.y
	)


func world_to_uv(world_position: Vector3) -> Vector2:
	var relative := Vector2(
		world_position.x - center.x,
		world_position.z - center.z,
	)
	return Vector2(
		relative.x / coverage_size.x + 0.5,
		relative.y / coverage_size.y + 0.5,
	)


func get_active_count() -> int:
	var count := 0

	for stamp: NucleusWorldStamp3D in _stamps:
		if stamp != null and stamp.is_alive(elapsed_time):
			count += 1

	return count


func get_stored_count() -> int:
	return _stamps.size()


func get_stamp(index: int) -> NucleusWorldStamp3D:
	if index < 0 or index >= _stamps.size():
		return null

	return _stamps[index]


func _trim_to_capacity() -> void:
	while _stamps.size() > max_stamps:
		_stamps.pop_front()

	if _stamps.is_empty():
		_replace_cursor = 0
	else:
		_replace_cursor %= _stamps.size()


func _store_emitter(
	emitter_id: int,
	point: Vector2,
) -> void:
	_emitters[emitter_id] = {
		"point": point,
		"time": elapsed_time,
	}


func _try_reserve_emitter_slot() -> bool:
	if _emitters.size() < maxi(max_emitters, 1):
		return true

	var timeout := default_lifetime * emitter_timeout_multiplier
	var expired_ids: Array[int] = []

	for emitter_id: Variant in _emitters:
		var state: Dictionary = _emitters[emitter_id]
		if elapsed_time - float(state["time"]) > timeout:
			expired_ids.append(int(emitter_id))

	for emitter_id: int in expired_ids:
		_emitters.erase(emitter_id)

	return _emitters.size() < maxi(max_emitters, 1)
