class_name NucleusUIVirtualList
extends Node
## Fixed-row virtualized list for large UI datasets.
##
## Only enough item Controls to cover the viewport plus overscan are
## instantiated. Consumers populate recycled items through [signal bind_item].

signal bind_item(
	item: Control,
	index: int,
	data: Variant,
)
signal unbind_item(
	item: Control,
	previous_index: int,
)

@export var scroll_container: ScrollContainer
@export var content: Control
@export var item_scene: PackedScene

@export_range(1.0, 4096.0, 1.0)
var item_height: float = 48.0

@export_range(0.0, 512.0, 1.0)
var item_spacing: float = 4.0

@export_range(0, 20, 1)
var overscan_rows: int = 2

var _items: Array = []
var _pool: Array[Control] = []
var _bound_indices: Array[int] = []
var _initialized: bool = false


func _ready() -> void:
	if not _resolve_dependencies():
		return

	scroll_container.get_v_scroll_bar().value_changed.connect(
		_on_scroll_changed
	)
	scroll_container.resized.connect(_refresh)
	content.resized.connect(_refresh_visible_items)

	_initialized = true
	_refresh()


func set_items(items: Array) -> void:
	_items = items.duplicate()

	if _initialized:
		_refresh()
		call_deferred("_refresh_visible_items")


func clear_items() -> void:
	_items.clear()

	if _initialized:
		scroll_container.scroll_vertical = 0
		_refresh()


func get_item_count() -> int:
	return _items.size()


func refresh_visible_items() -> void:
	_refresh_visible_items()


func _resolve_dependencies() -> bool:
	if scroll_container == null:
		scroll_container = get_parent() as ScrollContainer

	if (
		content == null
		and scroll_container
		and scroll_container.get_child_count() > 0
	):
		content = scroll_container.get_child(0) as Control

	if scroll_container == null or content == null:
		NucleusLog.error(
			"%s requires ScrollContainer and Control content."
			% get_path(),
			&"UIVirtualList",
		)
		return false

	if item_scene == null:
		NucleusLog.error(
			"%s requires an item_scene." % get_path(),
			&"UIVirtualList",
		)
		return false

	return true


func _refresh() -> void:
	_refresh_content_size()
	_resize_pool()
	_refresh_visible_items()


func _refresh_content_size() -> void:
	var total_height: float = 0.0

	if not _items.is_empty():
		total_height = (
			_items.size() * item_height
			+ maxi(0, _items.size() - 1) * item_spacing
		)

	var minimum_size: Vector2 = content.custom_minimum_size
	minimum_size.y = total_height
	content.custom_minimum_size = minimum_size


func _resize_pool() -> void:
	var stride: float = item_height + item_spacing
	var visible_rows: int = ceili(
		scroll_container.size.y / maxf(1.0, stride)
	)
	var desired_pool_size: int = mini(
		_items.size(),
		visible_rows + overscan_rows * 2 + 1,
	)

	while _pool.size() < desired_pool_size:
		var instance: Node = item_scene.instantiate()

		if not (instance is Control):
			instance.queue_free()
			NucleusLog.error(
				"Virtual list item_scene root must inherit Control.",
				&"UIVirtualList",
			)
			return

		var item := instance as Control
		content.add_child(item)
		_pool.append(item)
		_bound_indices.append(-1)

	while _pool.size() > desired_pool_size:
		var item: Control = _pool.pop_back()
		var previous_index: int = _bound_indices.pop_back()

		if previous_index >= 0:
			unbind_item.emit(item, previous_index)

		item.queue_free()


func _refresh_visible_items() -> void:
	if _pool.is_empty():
		return

	var stride: float = item_height + item_spacing
	var first_visible: int = floori(
		float(scroll_container.scroll_vertical)
		/ maxf(1.0, stride)
	)
	var first_index: int = maxi(
		0,
		first_visible - overscan_rows,
	)

	for pool_index: int in range(_pool.size()):
		var item: Control = _pool[pool_index]
		var data_index: int = first_index + pool_index
		var previous_index: int = _bound_indices[pool_index]

		if data_index >= _items.size():
			if previous_index >= 0:
				unbind_item.emit(item, previous_index)

			_bound_indices[pool_index] = -1
			item.hide()
			continue

		_layout_item(item, data_index)
		item.show()

		if previous_index == data_index:
			continue

		if previous_index >= 0:
			unbind_item.emit(item, previous_index)

		_bound_indices[pool_index] = data_index
		bind_item.emit(
			item,
			data_index,
			_items[data_index],
		)


func _layout_item(
	item: Control,
	index: int,
) -> void:
	var y: float = index * (item_height + item_spacing)

	item.anchor_left = 0.0
	item.anchor_right = 1.0
	item.anchor_top = 0.0
	item.anchor_bottom = 0.0

	item.offset_left = 0.0
	item.offset_right = 0.0
	item.offset_top = y
	item.offset_bottom = y + item_height


func _on_scroll_changed(_value: float) -> void:
	_refresh_visible_items()
