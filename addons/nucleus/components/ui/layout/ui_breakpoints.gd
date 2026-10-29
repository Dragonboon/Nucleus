class_name NucleusUIBreakpoints
extends Node
## Classifies logical viewport width and orientation for responsive UI.

signal breakpoint_changed(
	size_class: int,
	is_portrait: bool,
)

enum SizeClass {
	COMPACT,
	REGULAR,
	WIDE,
}

@export_range(240.0, 4096.0, 1.0)
var compact_max_width: float = 720.0

@export_range(240.0, 8192.0, 1.0)
var wide_min_width: float = 1280.0

var size_class: SizeClass = SizeClass.REGULAR
var is_portrait: bool = false


func _ready() -> void:
	get_viewport().size_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var new_size_class: SizeClass = classify_width(viewport_size.x)
	var new_is_portrait: bool = viewport_size.y > viewport_size.x

	if (
		new_size_class == size_class
		and new_is_portrait == is_portrait
	):
		return

	size_class = new_size_class
	is_portrait = new_is_portrait

	breakpoint_changed.emit(
		size_class,
		is_portrait,
	)


func classify_width(width: float) -> SizeClass:
	if width <= compact_max_width:
		return SizeClass.COMPACT

	if width >= wide_min_width:
		return SizeClass.WIDE

	return SizeClass.REGULAR


func is_compact() -> bool:
	return size_class == SizeClass.COMPACT


func is_regular() -> bool:
	return size_class == SizeClass.REGULAR


func is_wide() -> bool:
	return size_class == SizeClass.WIDE
