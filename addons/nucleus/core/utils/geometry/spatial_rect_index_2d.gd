class_name NucleusSpatialRectIndex2D
extends RefCounted
## Deterministic, mutable rectangle broad phase for editor/UI/gameplay use.
## Returns AABB candidates only; consumers own exact geometry hit testing.

var max_cells_per_item: int = 1024
var max_query_cells: int = 4096

var _cell_size: float = 64.0
var _items: Dictionary = {} # integer ID -> {bounds, order, cells}
var _cells: Dictionary = {} # Vector2i -> {integer ID: true}
var _overflow: Dictionary = {} # oversized rectangles -> true


func configure_cell_size(value: float) -> Error:
	if not is_finite(value) or value <= 0.0:
		return ERR_INVALID_PARAMETER
	if is_equal_approx(value, _cell_size):
		return OK
	var previous := _cell_size
	_cell_size = value
	for id: Variant in _items:
		if not _can_index(_items[id]["bounds"]):
			_cell_size = previous
			return ERR_INVALID_PARAMETER
	var old_items := _items.duplicate(true)
	clear()
	for id: Variant in old_items:
		var item: Dictionary = old_items[id]
		upsert(int(id), item["bounds"], int(item["order"]))
	return OK


func clear() -> void:
	_items.clear()
	_cells.clear()
	_overflow.clear()


func size() -> int:
	return _items.size()


func contains(id: int) -> bool:
	return _items.has(id)


func upsert(id: int, bounds: Rect2, draw_order: int = 0) -> Error:
	if id < 0 or not _valid_rect(bounds) or not _can_index(bounds):
		return ERR_INVALID_PARAMETER
	remove(id)
	var first := _cell(bounds.position)
	var last := _cell(bounds.end)
	var span_x := float(last.x - first.x + 1)
	var span_y := float(last.y - first.y + 1)
	var item_cells: Array[Vector2i] = []
	if span_x * span_y > float(maxi(1, max_cells_per_item)):
		_overflow[id] = true
	else:
		for y: int in range(first.y, last.y + 1):
			for x: int in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				var bucket: Dictionary = _cells.get(cell, {})
				bucket[id] = true
				_cells[cell] = bucket
				item_cells.append(cell)
	_items[id] = {"bounds": bounds, "order": draw_order, "cells": item_cells}
	return OK


func remove(id: int) -> bool:
	if not _items.has(id):
		return false
	var item: Dictionary = _items[id]
	for cell: Vector2i in item["cells"]:
		var bucket: Dictionary = _cells[cell]
		bucket.erase(id)
		if bucket.is_empty():
			_cells.erase(cell)
		else:
			_cells[cell] = bucket
	_overflow.erase(id)
	_items.erase(id)
	return true


func query_point(point: Vector2) -> Array[int]:
	if not point.is_finite() or not _cell_position_fits(point):
		return []
	var found: Dictionary = _overflow.duplicate()
	var cell := _cell(point)
	for id: Variant in _cells.get(cell, {}):
		found[id] = true
	var result: Array[int] = []
	for id: Variant in found:
		var item: Dictionary = _items[id]
		if (item["bounds"] as Rect2).has_point(point):
			result.append(int(id))
	_sort_candidates(result)
	return result


func query_region(region: Rect2, include_borders: bool = true) -> Array[int]:
	var result: Array[int] = []
	var scratch: Dictionary = {}
	query_region_into(region, result, scratch, include_borders)
	return result


## Caller-owned output/scratch are cleared on every call. Do not share during a query.
## Sorting defaults to the existing deterministic draw-order contract.
func query_region_into(
	region: Rect2,
	result: Array[int],
	scratch: Dictionary,
	include_borders: bool = true,
	sorted_results: bool = true,
) -> void:
	result.clear()
	scratch.clear()
	if not _valid_rect(region) or not _can_index(region):
		return
	var first := _cell(region.position)
	var last := _cell(region.end)
	var span_x := float(last.x - first.x + 1)
	var span_y := float(last.y - first.y + 1)
	if span_x * span_y > float(maxi(1, max_query_cells)):
		for id: Variant in _items:
			_append_intersection(int(id), region, include_borders, result)
	else:
		for id: Variant in _overflow:
			scratch[id] = true
		for y: int in range(first.y, last.y + 1):
			for x: int in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				if not _cells.has(cell):
					continue
				for id: Variant in _cells[cell]:
					scratch[id] = true
		for id: Variant in scratch:
			_append_intersection(int(id), region, include_borders, result)
	if sorted_results:
		_sort_candidates(result)


func _append_intersection(
	id: int, region: Rect2, include_borders: bool, result: Array[int],
) -> void:
	var bounds: Rect2 = _items[id]["bounds"]
	if bounds.intersects(region, include_borders):
		result.append(id)


func _sort_candidates(ids: Array[int]) -> void:
	ids.sort_custom(func(a: int, b: int) -> bool:
		var order_a: int = int(_items[a]["order"])
		var order_b: int = int(_items[b]["order"])
		return order_a > order_b if order_a != order_b else a > b
	)


func _valid_rect(rect: Rect2) -> bool:
	return (
		rect.position.is_finite()
		and rect.size.is_finite()
		and rect.end.is_finite()
		and rect.size.x >= 0.0
		and rect.size.y >= 0.0
	)


func _can_index(rect: Rect2) -> bool:
	return _cell_position_fits(rect.position) and _cell_position_fits(rect.end)


func _cell_position_fits(point: Vector2) -> bool:
	if not point.is_finite():
		return false
	var scaled := point / _cell_size
	return (
		scaled.is_finite()
		and absf(scaled.x) < 2000000000.0
		and absf(scaled.y) < 2000000000.0
	)


func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / _cell_size), floori(point.y / _cell_size))
