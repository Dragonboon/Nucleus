class_name NucleusUIToastRequest
extends RefCounted
## Runtime request consumed by [NucleusUIToastHost].

var title: String
var message: String
var duration: float
var dedupe_key: StringName
var priority: int
var order: int


func _init(
	request_message: String = "",
	request_title: String = "",
	request_duration: float = 3.0,
	request_dedupe_key: StringName = &"",
	request_priority: int = 0,
) -> void:
	message = request_message
	title = request_title
	duration = maxf(0.1, request_duration)
	dedupe_key = request_dedupe_key
	priority = request_priority
