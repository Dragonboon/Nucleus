@tool
class_name NucleusLoadEntry
extends Resource
## One developer-authored resource request in a NucleusLoadPlan.
##
## Loading remains owned by Godot ResourceLoader. This Resource only describes
## scheduling, presentation metadata, and whether the queue should retain the
## loaded Resource after the batch finishes.

enum Priority {
	BACKGROUND = 0,
	NORMAL = 100,
	HIGH = 200,
	CRITICAL = 300,
}

@export_file var path: String = ""
@export var display_name: String = ""
@export var type_hint: String = ""
@export_enum("Background:0", "Normal:100", "High:200", "Critical:300")
var priority: int = Priority.NORMAL
@export_range(0.001, 10000.0, 0.001, "or_greater")
var weight: float = 1.0
@export var required: bool = true
@export var retain: bool = true
@export var use_sub_threads: bool = false


func get_display_name() -> String:
	var authored := display_name.strip_edges()

	if not authored.is_empty():
		return authored

	var normalized := path.strip_edges()

	if normalized.is_empty():
		return "<unnamed resource>"

	return normalized.get_file()


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var normalized := path.strip_edges()

	if normalized.is_empty():
		errors.append("Resource path cannot be empty.")
	elif (
		not normalized.begins_with("res://")
		and not normalized.begins_with("user://")
	):
		errors.append("Resource path must use res:// or user://.")

	if not is_finite(weight) or weight <= 0.0:
		errors.append("Load weight must be finite and greater than zero.")

	if priority < Priority.BACKGROUND:
		errors.append("Load priority cannot be negative.")

	return errors
