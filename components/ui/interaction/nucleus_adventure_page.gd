extends Resource
class_name NucleusAdventurePage
## Authored image and interactive regions for a single semantic screen.

@export var id: StringName
@export var image: Texture2D
@export var hotspots: Array[NucleusScreenHotspot] = []
@export var effect_passes: Array[NucleusScreenEffectPass] = []


func is_valid_page() -> bool:
	if id == &"" or image == null:
		return false
	var seen := {}
	for hotspot in hotspots:
		if hotspot == null or not hotspot.is_valid_hotspot() or seen.has(hotspot.id):
			return false
		seen[hotspot.id] = true
	return true
