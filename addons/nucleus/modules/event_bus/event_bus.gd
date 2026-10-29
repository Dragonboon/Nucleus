class_name NucleusEventBus
extends Node
## Optional priority-aware event mediator.
##
## Prefer native Godot signals when producers and consumers have a natural
## relationship. This bus is intended for genuinely decoupled module events,
## non-SceneTree collaborators, or projects that explicitly choose a global bus.
##
## The bus is main-thread infrastructure. Do not publish from worker threads.

signal event_published(
	event: StringName,
	payload: Array,
	delivered_count: int,
)

@export_range(0, 10000, 1, "or_greater")
var max_history_length: int = 0

var _subscriptions: Dictionary[StringName, Array] = {}
var _history: Array[Dictionary] = []
var _next_order: int = 0


## Adds one callback. Higher priority callbacks run first.
##
## Duplicate subscriptions for the same event/callback pair are ignored.
func subscribe(
	event: StringName,
	callback: Callable,
	priority: int = 0,
	deferred: bool = false,
) -> Error:
	return _subscribe(
		event,
		callback,
		priority,
		deferred,
		false,
	)


## Adds one callback that is removed before its first delivery.
func subscribe_once(
	event: StringName,
	callback: Callable,
	priority: int = 0,
	deferred: bool = false,
) -> Error:
	return _subscribe(
		event,
		callback,
		priority,
		deferred,
		true,
	)


## Removes all subscriptions matching one event/callback pair.
func unsubscribe(
	event: StringName,
	callback: Callable,
) -> bool:
	if not _subscriptions.has(event):
		return false

	var listeners: Array = _subscriptions[event]
	var retained: Array = []
	var removed: bool = false

	for subscription: Dictionary in listeners:
		if subscription["callback"] == callback:
			removed = true
		else:
			retained.append(subscription)

	if retained.is_empty():
		_subscriptions.erase(event)
	else:
		_subscriptions[event] = retained

	return removed


## Removes every listener for one event.
func unsubscribe_all(event: StringName) -> void:
	_subscriptions.erase(event)


## Removes every event and listener.
func clear() -> void:
	_subscriptions.clear()


func has_subscriber(
	event: StringName,
	callback: Callable,
) -> bool:
	if not _subscriptions.has(event):
		return false

	for subscription: Dictionary in _subscriptions[event]:
		if subscription["callback"] == callback:
			return true

	return false


func get_subscriber_count(event: StringName) -> int:
	_prune_invalid(event)

	if not _subscriptions.has(event):
		return 0

	return _subscriptions[event].size()


## Publishes immediately and returns the number of scheduled/delivered calls.
func publish(
	event: StringName,
	...payload: Array,
) -> int:
	return _publish_array(event, payload)


## Defers the complete publication until idle time.
func publish_deferred(
	event: StringName,
	...payload: Array,
) -> void:
	call_deferred("_publish_array", event, payload)


func get_history() -> Array[Dictionary]:
	return _history.duplicate(true)


func clear_history() -> void:
	_history.clear()


func _subscribe(
	event: StringName,
	callback: Callable,
	priority: int,
	deferred: bool,
	one_shot: bool,
) -> Error:
	if event == &"" or not callback.is_valid():
		return ERR_INVALID_PARAMETER

	if has_subscriber(event, callback):
		return ERR_ALREADY_EXISTS

	var subscription: Dictionary = {
		"callback": callback,
		"priority": priority,
		"order": _next_order,
		"deferred": deferred,
		"one_shot": one_shot,
	}

	_next_order += 1

	if not _subscriptions.has(event):
		_subscriptions[event] = []

	_subscriptions[event].append(subscription)
	_subscriptions[event].sort_custom(_sort_subscriptions)

	return OK


func _publish_array(
	event: StringName,
	payload: Array,
) -> int:
	_prune_invalid(event)

	if not _subscriptions.has(event):
		_record_publication(event, payload, 0)
		event_published.emit(event, payload, 0)
		return 0

	var snapshot: Array = _subscriptions[event].duplicate()
	var delivered_count: int = 0

	for subscription: Dictionary in snapshot:
		var callback: Callable = subscription["callback"]

		if not callback.is_valid():
			unsubscribe(event, callback)
			continue

		if bool(subscription["one_shot"]):
			unsubscribe(event, callback)

		if bool(subscription["deferred"]):
			call_deferred(
				"_invoke_callback",
				callback,
				payload.duplicate(true),
			)
		else:
			callback.callv(payload)

		delivered_count += 1

	_record_publication(
		event,
		payload,
		delivered_count,
	)
	event_published.emit(
		event,
		payload,
		delivered_count,
	)

	return delivered_count


func _invoke_callback(
	callback: Callable,
	payload: Array,
) -> void:
	if callback.is_valid():
		callback.callv(payload)


func _prune_invalid(event: StringName) -> void:
	if not _subscriptions.has(event):
		return

	var retained: Array = []

	for subscription: Dictionary in _subscriptions[event]:
		var callback: Callable = subscription["callback"]

		if callback.is_valid():
			retained.append(subscription)

	if retained.is_empty():
		_subscriptions.erase(event)
	else:
		_subscriptions[event] = retained


func _record_publication(
	event: StringName,
	payload: Array,
	delivered_count: int,
) -> void:
	if max_history_length <= 0:
		return

	_history.append(
		{
			"event": event,
			"timestamp": Time.get_unix_time_from_system(),
			"delivered_count": delivered_count,
			"payload": payload.duplicate(true),
		}
	)

	while _history.size() > max_history_length:
		_history.pop_front()


func _sort_subscriptions(
	left: Dictionary,
	right: Dictionary,
) -> bool:
	var left_priority: int = left["priority"]
	var right_priority: int = right["priority"]

	if left_priority == right_priority:
		return int(left["order"]) < int(right["order"])

	return left_priority > right_priority
