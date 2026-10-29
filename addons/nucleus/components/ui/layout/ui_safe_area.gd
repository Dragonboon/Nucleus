class_name NucleusUISafeArea
extends Node
## Applies physical display safe-area insets to a full-rect Control.
##
## Native safe-area availability is platform dependent. Manual fallback and
## extra margins keep the component usable on Web and custom host shells.

@export var target: Control
@export var force_full_rect_anchors: bool = true
@export var use_native_safe_area: bool = true

## Left, top, right, bottom logical-pixel fallback insets.
@export var fallback_margins: Vector4 = Vector4.ZERO

## Additional left, top, right, bottom logical-pixel design padding.
@export var extra_margins: Vector4 = Vector4.ZERO


func _ready() -> void:
	if not _resolve_target():
		return

	if force_full_rect_anchors:
		target.set_anchors_preset(Control.PRESET_FULL_RECT)

	get_viewport().size_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if target == null:
		return

	var margins: Vector4 = fallback_margins

	if use_native_safe_area and _should_apply_native_safe_area():
		margins = _get_native_margins()

	margins += extra_margins

	target.offset_left = margins.x
	target.offset_top = margins.y
	target.offset_right = -margins.z
	target.offset_bottom = -margins.w


func _resolve_target() -> bool:
	if target == null:
		target = get_parent() as Control

	if target:
		return true

	NucleusLog.error(
		"%s requires a Control target or parent." % get_path(),
		&"UISafeArea",
	)

	return false


func _should_apply_native_safe_area() -> bool:
	if NucleusPlatform.is_native_mobile():
		return true

	var mode: int = DisplayServer.window_get_mode()

	return mode in [
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	]


func _get_native_margins() -> Vector4:
	var screen: int = DisplayServer.SCREEN_OF_MAIN_WINDOW
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen)
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()

	if (
		screen_size.x <= 0
		or screen_size.y <= 0
		or safe_area.size.x <= 0
		or safe_area.size.y <= 0
	):
		return fallback_margins

	var safe_position: Vector2i = safe_area.position

	# Mobile safe areas are relative to the physical screen. Desktop fallback
	# can be expressed in virtual-desktop coordinates.
	if not NucleusPlatform.is_native_mobile():
		safe_position -= DisplayServer.screen_get_position(screen)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var scale_x: float = viewport_size.x / float(screen_size.x)
	var scale_y: float = viewport_size.y / float(screen_size.y)

	var right_inset: int = maxi(
		0,
		screen_size.x - safe_position.x - safe_area.size.x,
	)
	var bottom_inset: int = maxi(
		0,
		screen_size.y - safe_position.y - safe_area.size.y,
	)

	var margins := Vector4(
		maxi(0, safe_position.x) * scale_x,
		maxi(0, safe_position.y) * scale_y,
		right_inset * scale_x,
		bottom_inset * scale_y,
	)

	return (
		fallback_margins
		if margins == Vector4.ZERO
		else margins
	)
