class_name NucleusUIWorldAnchor3D
extends Node
## Projects a game-owned Node3D into a direct Control child of a HUD overlay.
## The anchor is the sole writer of the visual's position and visibility.

signal projection_visibility_changed(is_visible: bool)

@export var world_target: Node3D
@export var camera: Camera3D
@export var overlay: Control
@export var visual: Control

@export_group("Placement")
@export var world_offset: Vector3 = Vector3.ZERO
## 0 = left/top, 0.5 = center, 1 = right/bottom of the Control bounds.
@export var alignment: Vector2 = Vector2(0.5, 1.0)
@export var pixel_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 100000.0, 0.1) var maximum_distance: float = 0.0
@export var hide_outside_viewport: bool = true
@export_range(0.0, 512.0, 1.0) var viewport_margin: float = 0.0

@export_group("Updates")
## Set false when a NucleusUIWorldAnchorLayout refreshes this component.
@export var update_automatically: bool = true

var _has_projection: bool = false
var _base_position: Vector2 = Vector2.ZERO
var _layout_position: Vector2 = Vector2.ZERO
var _layout_active: bool = false
var _layout_visible: bool = true
var _presentation_visible: bool = false


func _ready() -> void:
	if is_instance_valid(visual):
		visual.hide()

	set_process(update_automatically)


func _process(_delta: float) -> void:
	refresh_projection()


func _exit_tree() -> void:
	if is_instance_valid(visual):
		visual.hide()


## Returns false for missing bindings, a different Viewport, or invalid projection.
## Camera3D.unproject_position() gives viewport pixels, not Control-local pixels.
func refresh_projection() -> bool:
	if not _can_project():
		_clear_projection()
		return false

	var world_point: Vector3 = world_target.global_position + world_offset
	if camera.is_position_behind(world_point):
		_clear_projection()
		return false

	if maximum_distance > 0.0:
		var distance: float = camera.global_position.distance_to(world_point)
		if distance > maximum_distance:
			_clear_projection()
			return false

	var viewport: Viewport = camera.get_viewport()
	var viewport_point: Vector2 = camera.unproject_position(world_point)
	if not viewport_point.is_finite():
		_clear_projection()
		return false

	if hide_outside_viewport:
		var view_rect: Rect2 = viewport.get_visible_rect()
		var inset: float = maxf(0.0, viewport_margin)
		if not view_rect.grow(-inset).has_point(viewport_point):
			_clear_projection()
			return false

	var overlay_transform: Transform2D = overlay.get_global_transform_with_canvas()
	if absf(overlay_transform.determinant()) < 0.00001:
		_clear_projection()
		return false

	var local_point: Vector2 = overlay_transform.affine_inverse() * viewport_point
	var anchor_fraction: Vector2 = Vector2(
		clampf(alignment.x, 0.0, 1.0),
		clampf(alignment.y, 0.0, 1.0),
	)
	_base_position = local_point + pixel_offset - visual.size * anchor_fraction
	_has_projection = true
	_apply_visual_state()
	return true


func has_projection() -> bool:
	return _has_projection


## Desired top-left in overlay-local coordinates, before collision avoidance.
func get_base_position() -> Vector2:
	return _base_position


## The layout controller chooses the final top-left; only this anchor writes it.
func apply_layout(position: Vector2, should_show: bool) -> void:
	_layout_active = true
	_layout_position = position
	_layout_visible = should_show
	_apply_visual_state()


## Remove placement overrides when a layout controller is no longer used.
func reset_layout() -> void:
	_layout_active = false
	_layout_visible = true
	_apply_visual_state()


func _can_project() -> bool:
	if (
		not is_instance_valid(world_target)
		or not is_instance_valid(camera)
		or not is_instance_valid(overlay)
		or not is_instance_valid(visual)
	):
		return false

	if not world_target.is_inside_tree() or not camera.is_inside_tree():
		return false

	if not overlay.is_inside_tree() or not visual.is_inside_tree():
		return false

	if visual.get_parent() != overlay:
		return false

	return camera.get_viewport() == overlay.get_viewport()


func _clear_projection() -> void:
	_has_projection = false
	_apply_visual_state()


func _apply_visual_state() -> void:
	if visual == null or not is_instance_valid(visual):
		return

	var should_show: bool = _has_projection and (
		not _layout_active or _layout_visible
	)
	if should_show:
		visual.position = _layout_position if _layout_active else _base_position

	if _presentation_visible != should_show:
		_presentation_visible = should_show
		projection_visibility_changed.emit(should_show)

	visual.visible = should_show
