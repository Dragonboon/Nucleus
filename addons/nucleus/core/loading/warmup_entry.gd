class_name NucleusWarmupEntry
extends Resource
## One explicitly authored scene-instantiation warmup operation.


enum Mode {
	INSTANTIATE_ONLY,
	ENTER_TREE_INACTIVE,
}

@export var scene: PackedScene
@export var display_name: String
@export_range(1, 1024, 1, "or_greater")
var instance_count: int = 1
@export var mode: Mode = Mode.INSTANTIATE_ONLY
@export_range(0, 8, 1, "or_greater")
var settle_frames: int = 0


func get_display_name() -> String:
	if not display_name.strip_edges().is_empty():
		return display_name.strip_edges()
	if scene != null and not scene.resource_path.is_empty():
		return scene.resource_path.get_file()
	return "Warmup scene"


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if scene == null:
		errors.append("scene cannot be null")
	if instance_count <= 0:
		errors.append("instance_count must be greater than zero")
	return errors
