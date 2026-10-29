@tool
class_name NucleusFracturePattern3D
extends Resource
## Shared immutable-by-convention shard geometry preset.

@export var shards: Array[NucleusFractureShard3D] = []


func is_usable() -> bool:
	if shards.size() < 2:
		return false
	for shard: NucleusFractureShard3D in shards:
		if shard == null or shard.mesh == null or shard.mass <= 0.0:
			return false
	return true
