extends Resource
class_name NucleusAdventurePage
## Authored image and interactive regions for a single semantic screen.

@export var id: StringName
@export var image: Texture2D
@export var hotspots: Array[NucleusScreenHotspot] = []
@export var effect_passes: Array[NucleusScreenEffectPass] = []
## Explicit links, never inferred from visit history. Empty links are unavailable.
@export var back_page: StringName
@export var left_page: StringName
@export var right_page: StringName
## Opt-in normalized side width / bottom height. Zero leaves authoring unchanged.
@export var navigation_edge_fraction := Vector2.ZERO
@export var side_navigation_priority := -100
@export var back_navigation_priority := 100

const NAVIGATION_PREFIX := "nucleus:nav:"


func is_valid_page() -> bool:
	if id == &"" or image == null or not navigation_edge_fraction.is_finite():
		return false
	if navigation_edge_fraction.x < 0 or navigation_edge_fraction.y < 0:
		return false
	if navigation_edge_fraction.x > 0.5 or navigation_edge_fraction.y > 0.5:
		return false
	var seen := {}
	for hotspot in hotspots:
		if hotspot == null or not hotspot.is_valid_hotspot() or seen.has(hotspot.id):
			return false
		if navigation_edge_fraction != Vector2.ZERO and (
			String(hotspot.id).begins_with(NAVIGATION_PREFIX)
		):
			return false
		seen[hotspot.id] = true
	return true


## Return a new array; shared authored Resources are never modified.
func screen_hotspots() -> Array[NucleusScreenHotspot]:
	var result: Array[NucleusScreenHotspot] = hotspots.duplicate()
	var width := navigation_edge_fraction.x
	var height := navigation_edge_fraction.y
	var side_height := 1.0 - height if back_page != &"" else 1.0
	if width > 0.0:
		if left_page != &"":
			result.append(_navigation_hotspot(&"left", left_page,
				Rect2(0.0, 0.0, width, side_height), side_navigation_priority))
		if right_page != &"":
			result.append(_navigation_hotspot(&"right", right_page,
				Rect2(1.0 - width, 0.0, width, side_height), side_navigation_priority))
	if height > 0.0 and back_page != &"":
		result.append(_navigation_hotspot(&"back", back_page,
			Rect2(0.0, 1.0 - height, 1.0, height), back_navigation_priority))
	return result


func _navigation_hotspot(
	direction: StringName, destination: StringName, area: Rect2, order: int
) -> NucleusScreenHotspot:
	var region := NucleusScreenHotspot.new()
	region.id = StringName(NAVIGATION_PREFIX + String(direction))
	region.destination = destination
	region.bounds = area
	region.priority = order
	return region
