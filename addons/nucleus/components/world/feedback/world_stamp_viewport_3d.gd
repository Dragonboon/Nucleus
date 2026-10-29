@tool
class_name NucleusWorldStampViewport3D
extends SubViewport
## Optional SubViewport renderer for NucleusWorldStampBuffer3D.
##
## The output texture is a bounded presentation map. Consumers decide how to
## interpret it as foam, tracks, wetness, flattened vegetation, or another effect.

const StampCanvas := preload(
	"res://addons/nucleus/components/world/feedback/world_stamp_canvas_3d.gd"
)

@export var buffer: NucleusWorldStampBuffer3D:
	set(value):
		_disconnect_buffer()
		buffer = value
		_connect_buffer()
		update_configuration_warnings()

@export_group("Texture")
@export var stamp_texture: Texture2D
@export var texture_size: Vector2i = Vector2i(384, 384)

@export_group("Envelope")
@export_range(0.0, 1.0, 0.01)
var fade_in_fraction: float = 0.08
@export_range(0.1, 8.0, 0.1, "or_greater")
var fade_out_power: float = 2.0

var _canvas: Node2D
var _had_visible_stamps: bool = false


func _ready() -> void:
	_configure_viewport()

	if Engine.is_editor_hint():
		return

	_connect_buffer()
	_ensure_stamp_texture()
	_ensure_canvas()
	_request_redraw()


func _exit_tree() -> void:
	_disconnect_buffer()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if buffer == null:
		warnings.append("Assign a NucleusWorldStampBuffer3D.")

	if texture_size.x <= 0 or texture_size.y <= 0:
		warnings.append("texture_size must be positive on both axes.")

	return warnings


func get_history_texture() -> Texture2D:
	return get_texture()


func refresh() -> void:
	_configure_viewport()
	_request_redraw()


func _configure_viewport() -> void:
	disable_3d = true
	transparent_bg = true
	size = Vector2i(
		maxi(texture_size.x, 1),
		maxi(texture_size.y, 1),
	)
	render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	render_target_update_mode = SubViewport.UPDATE_ONCE


func _ensure_canvas() -> void:
	if _canvas != null:
		return

	_canvas = StampCanvas.new()
	_canvas.name = "StampCanvas"
	_canvas.renderer = self
	add_child(_canvas)


func _ensure_stamp_texture() -> void:
	if stamp_texture != null:
		return

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([
		0.0,
		0.35,
		0.72,
		1.0,
	])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.9),
		Color(1.0, 1.0, 1.0, 0.32),
		Color(1.0, 1.0, 1.0, 0.0),
	])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	stamp_texture = texture


func _draw_stamps(canvas: Node2D) -> void:
	if buffer == null or stamp_texture == null:
		return

	var pixel_scale := Vector2(
		float(size.x) / buffer.coverage_size.x,
		float(size.y) / buffer.coverage_size.y,
	)

	for index: int in range(buffer.get_stored_count()):
		var stamp := buffer.get_stamp(index)

		if stamp == null or not stamp.is_alive(buffer.elapsed_time):
			continue

		var t := stamp.get_normalized_age(buffer.elapsed_time)
		var fade_in := 1.0

		if fade_in_fraction > 0.0:
			fade_in = smoothstep(
				0.0,
				fade_in_fraction,
				t,
			)

		var opacity := (
			fade_in
			* pow(maxf(0.0, 1.0 - t), fade_out_power)
			* stamp.strength
		)
		var world_position := stamp.get_world_position(buffer.elapsed_time)
		var uv := buffer.world_to_uv(world_position)
		var screen_point := Vector2(
			uv.x * float(size.x),
			uv.y * float(size.y),
		)
		var dimensions := stamp.get_dimensions(buffer.elapsed_time) * pixel_scale

		canvas.draw_set_transform(
			screen_point,
			stamp.rotation,
		)
		canvas.draw_texture_rect(
			stamp_texture,
			Rect2(-dimensions * 0.5, dimensions),
			false,
			Color(1.0, 1.0, 1.0, opacity),
		)

	canvas.draw_set_transform(Vector2.ZERO)


func _request_redraw() -> void:
	if _canvas == null:
		return

	var has_visible := buffer != null and buffer.get_active_count() > 0

	if has_visible or _had_visible_stamps:
		_canvas.queue_redraw()
		render_target_update_mode = SubViewport.UPDATE_ONCE

	_had_visible_stamps = has_visible


func _connect_buffer() -> void:
	if buffer == null or not is_node_ready():
		return

	if not buffer.stamp_emitted.is_connected(_on_buffer_changed):
		buffer.stamp_emitted.connect(_on_buffer_changed)

	if not buffer.cleared.is_connected(_on_buffer_cleared):
		buffer.cleared.connect(_on_buffer_cleared)

	if not buffer.center_changed.is_connected(_on_center_changed):
		buffer.center_changed.connect(_on_center_changed)

	if not buffer.time_advanced.is_connected(_on_time_advanced):
		buffer.time_advanced.connect(_on_time_advanced)


func _disconnect_buffer() -> void:
	if buffer == null or not is_instance_valid(buffer):
		return

	if buffer.stamp_emitted.is_connected(_on_buffer_changed):
		buffer.stamp_emitted.disconnect(_on_buffer_changed)

	if buffer.cleared.is_connected(_on_buffer_cleared):
		buffer.cleared.disconnect(_on_buffer_cleared)

	if buffer.center_changed.is_connected(_on_center_changed):
		buffer.center_changed.disconnect(_on_center_changed)

	if buffer.time_advanced.is_connected(_on_time_advanced):
		buffer.time_advanced.disconnect(_on_time_advanced)


func _on_buffer_changed(_stamp: NucleusWorldStamp3D) -> void:
	_request_redraw()


func _on_buffer_cleared() -> void:
	_had_visible_stamps = true
	_request_redraw()


func _on_center_changed(_center: Vector3) -> void:
	_request_redraw()


func _on_time_advanced(_elapsed_time: float) -> void:
	_request_redraw()
