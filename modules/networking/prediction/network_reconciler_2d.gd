class_name NucleusNetworkReconciler2D
extends RefCounted
## Stores pending predicted inputs and replays after a server acknowledgment.
var history := NucleusNetworkInputBuffer.new()

func reset() -> void:
	history.reset()
