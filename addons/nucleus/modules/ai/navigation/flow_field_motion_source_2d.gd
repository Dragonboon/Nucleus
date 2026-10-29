@tool
class_name NucleusFlowFieldMotionSource2D
extends NucleusMotionSource2D
## Optional intent adapter; NucleusCharacterMotor2D remains movement owner.

@export var tile_map: TileMapLayer
@export var origin_cell: Vector2i = Vector2i.ZERO
@export var cell_size: Vector2 = Vector2(32.0, 32.0)

var field: NucleusFlowField2D


func get_desired_velocity(
	body: CharacterBody2D,
	max_speed: float,
) -> Vector2:
	if not enabled or field == null:
		return Vector2.ZERO
	if not cell_size.is_finite() or cell_size.x <= 0.0 or cell_size.y <= 0.0:
		return Vector2.ZERO
	var cell: Vector2i
	if tile_map != null:
		cell = tile_map.local_to_map(tile_map.to_local(body.global_position))
	else:
		cell = origin_cell + Vector2i(
			floori(body.global_position.x / cell_size.x),
			floori(body.global_position.y / cell_size.y),
		)
	return field.direction_at(cell) * maxf(max_speed, 0.0)
