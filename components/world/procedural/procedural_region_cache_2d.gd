class_name NucleusProceduralRegionCache2D
extends RefCounted
## Bounded least-recently-used cell cache; no TileMap/SceneTree ownership.

var generator: NucleusProceduralGrid2D
var maximum_regions: int = 48

var _entries: Dictionary = {}
var _recent: Array[Vector2i] = []


func get_region(region: Vector2i) -> PackedByteArray:
	if generator == null or maximum_regions <= 0:
		return PackedByteArray()
	if _entries.has(region):
		_touch(region)
		var cached: PackedByteArray = _entries[region]
		return cached.duplicate()
	var generated := generator.generate(region)
	if generated.is_empty():
		return generated
	_entries[region] = generated.duplicate()
	_touch(region)
	while _recent.size() > maximum_regions:
		var evicted: Vector2i = _recent.pop_front()
		_entries.erase(evicted)
	return generated


func invalidate(region: Vector2i) -> void:
	_entries.erase(region)
	_recent.erase(region)


func clear() -> void:
	_entries.clear()
	_recent.clear()


func cached_count() -> int:
	return _entries.size()


func _touch(region: Vector2i) -> void:
	_recent.erase(region)
	_recent.append(region)
