class_name NucleusUIRefreshCoalescer
extends Node
## Coalesces multiple refresh requests into one deferred UI update.
##
## Connect noisy source signals to request_refresh() and perform the actual UI
## read/write work from refresh_due. This keeps presentation event-driven while
## avoiding repeated updates during one burst of state changes.

signal refresh_due

var _pending: bool = false


func request_refresh() -> void:
	if _pending:
		return

	_pending = true
	call_deferred("_flush")


## Flushes a pending request immediately. Returns whether a refresh was emitted.
func flush_now() -> bool:
	if not _pending:
		return false

	_pending = false
	refresh_due.emit()
	return true


func cancel() -> void:
	_pending = false


func is_pending() -> bool:
	return _pending


func _flush() -> void:
	flush_now()
