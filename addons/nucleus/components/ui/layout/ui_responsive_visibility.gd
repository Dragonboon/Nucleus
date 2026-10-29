class_name NucleusUIResponsiveVisibility
extends Node
## Declaratively shows one Control at selected responsive breakpoints.

@export var target: Control
@export var breakpoints: NucleusUIBreakpoints

@export_group("Size classes")
@export var visible_compact: bool = true
@export var visible_regular: bool = true
@export var visible_wide: bool = true

@export_group("Orientation")
@export var visible_portrait: bool = true
@export var visible_landscape: bool = true


func _ready() -> void:
	if not _resolve_dependencies():
		return

	breakpoints.breakpoint_changed.connect(_on_breakpoint_changed)
	_apply_visibility(
		breakpoints.size_class,
		breakpoints.is_portrait,
	)


func _resolve_dependencies() -> bool:
	if target == null:
		target = get_parent() as Control

	if breakpoints == null:
		breakpoints = _find_breakpoints()

	if target and breakpoints:
		return true

	NucleusLog.error(
		"%s requires a Control target and NucleusUIBreakpoints."
		% get_path(),
		&"UIResponsive",
	)

	return false


func _find_breakpoints() -> NucleusUIBreakpoints:
	var current: Node = get_parent()

	while current:
		for child: Node in current.get_children():
			if child is NucleusUIBreakpoints:
				return child as NucleusUIBreakpoints

		current = current.get_parent()

	return null


func _on_breakpoint_changed(
	size_class: int,
	is_portrait: bool,
) -> void:
	_apply_visibility(size_class, is_portrait)


func _apply_visibility(
	size_class: int,
	is_portrait: bool,
) -> void:
	var size_visible: bool

	match size_class:
		NucleusUIBreakpoints.SizeClass.COMPACT:
			size_visible = visible_compact

		NucleusUIBreakpoints.SizeClass.WIDE:
			size_visible = visible_wide

		_:
			size_visible = visible_regular

	var orientation_visible: bool = (
		visible_portrait
		if is_portrait
		else visible_landscape
	)

	target.visible = size_visible and orientation_visible
