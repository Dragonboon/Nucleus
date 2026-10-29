class_name NucleusUITypewriter
extends Node
## Reveals a RichTextLabel progressively without owning dialogue or text data.
##
## RichTextLabel remains authoritative for BBCode, shaping and localization.
## Reduced-motion users receive the full text immediately by default.

signal reveal_started(total_characters: int)
signal progress_changed(
	visible_characters: int,
	total_characters: int,
)
signal reveal_finished
signal skipped

const MICROSECONDS_PER_SECOND: float = 1_000_000.0

@export var target: RichTextLabel

@export_group("Reveal")
@export_range(1.0, 1000.0, 1.0, "or_greater")
var characters_per_second: float = 40.0
@export var start_on_ready: bool = false
@export var ignore_time_scale: bool = true

@export_group("Cadence")
@export_range(0.0, 2.0, 0.01, "or_greater")
var minor_punctuation_delay: float = 0.06
@export_range(0.0, 2.0, 0.01, "or_greater")
var major_punctuation_delay: float = 0.16
@export var minor_punctuation_characters: String = ",;:،؛，；：、"
@export var major_punctuation_characters: String = ".!?؟…。！？"
@export var pause_on_line_break: bool = true

@export_group("Accessibility")
@export var respect_reduced_motion: bool = true
@export var reveal_immediately_with_reduced_motion: bool = true

var _revealing: bool = false
var _total_characters: int = 0
var _parsed_text: String = ""
var _character_elapsed: float = 0.0
var _pause_remaining: float = 0.0
var _last_tick_usec: int = 0


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _ready() -> void:
	if target == null:
		target = get_parent() as RichTextLabel

	if target == null:
		NucleusLog.error(
			"%s requires a RichTextLabel target or parent." % get_path(),
			&"UITypewriter",
		)
		return

	if start_on_ready:
		call_deferred("restart")


func _process(delta: float) -> void:
	if not _revealing or target == null:
		set_process(false)
		return

	var elapsed := delta

	if ignore_time_scale:
		var now := Time.get_ticks_usec()
		elapsed = float(now - _last_tick_usec) / MICROSECONDS_PER_SECOND
		_last_tick_usec = now

	_advance_reveal(maxf(0.0, elapsed))


func restart() -> Error:
	if target == null:
		return ERR_UNCONFIGURED

	_revealing = false
	set_process(false)
	_cache_target_text()
	_reset_timing()
	target.visible_characters = 0
	reveal_started.emit(_total_characters)

	if _total_characters <= 0:
		_finish_reveal(false)
		return OK

	if (
		respect_reduced_motion
		and reveal_immediately_with_reduced_motion
		and NucleusMotionPolicy.is_reduced_motion_enabled()
	):
		_finish_reveal(false)
		return OK

	_revealing = true
	_last_tick_usec = Time.get_ticks_usec()
	set_process(true)
	progress_changed.emit(0, _total_characters)
	return OK


func skip() -> void:
	if target == null:
		return

	if _total_characters <= 0:
		_cache_target_text()

	if not _revealing:
		if target.visible_characters < 0:
			return

		if target.visible_characters >= _total_characters:
			return

	_finish_reveal(true)


func reveal_immediately() -> Error:
	if target == null:
		return ERR_UNCONFIGURED

	_cache_target_text()
	_finish_reveal(false)
	return OK


func reset() -> Error:
	if target == null:
		return ERR_UNCONFIGURED

	_revealing = false
	set_process(false)
	_cache_target_text()
	_reset_timing()
	target.visible_characters = 0
	progress_changed.emit(0, _total_characters)
	return OK


func is_revealing() -> bool:
	return _revealing


func get_progress() -> float:
	if _total_characters <= 0 or target == null:
		return 1.0

	return clampf(
		float(maxi(0, target.visible_characters))
		/ float(_total_characters),
		0.0,
		1.0,
	)


func _advance_reveal(elapsed: float) -> void:
	var remaining := elapsed

	if _pause_remaining > 0.0:
		var pause_consumed := minf(remaining, _pause_remaining)
		_pause_remaining -= pause_consumed
		remaining -= pause_consumed

		if remaining <= 0.0:
			return

	_character_elapsed += remaining

	var seconds_per_character := 1.0 / maxf(1.0, characters_per_second)
	var visible := clampi(
		target.visible_characters,
		0,
		_total_characters,
	)
	var previous_visible := visible

	while (
		visible < _total_characters
		and _character_elapsed >= seconds_per_character
	):
		_character_elapsed -= seconds_per_character
		visible += 1

		if visible >= _total_characters:
			break

		var punctuation_delay := _get_pause_after_character(visible - 1)

		if punctuation_delay <= 0.0:
			continue

		if _character_elapsed >= punctuation_delay:
			_character_elapsed -= punctuation_delay
			continue

		_pause_remaining = punctuation_delay - _character_elapsed
		_character_elapsed = 0.0
		break

	if visible != previous_visible:
		target.visible_characters = visible
		progress_changed.emit(visible, _total_characters)

	if visible >= _total_characters:
		_finish_reveal(false)


func _get_pause_after_character(character_index: int) -> float:
	if character_index < 0 or character_index >= _parsed_text.length():
		return 0.0

	var codepoint := _parsed_text.unicode_at(character_index)

	if pause_on_line_break and codepoint == 10:
		return maxf(0.0, major_punctuation_delay)

	if _contains_codepoint(major_punctuation_characters, codepoint):
		return maxf(0.0, major_punctuation_delay)

	if _contains_codepoint(minor_punctuation_characters, codepoint):
		return maxf(0.0, minor_punctuation_delay)

	return 0.0


func _cache_target_text() -> void:
	_parsed_text = target.get_parsed_text()
	_total_characters = target.get_total_character_count()

	if _total_characters <= 0 and not _parsed_text.is_empty():
		_total_characters = _parsed_text.length()


func _reset_timing() -> void:
	_character_elapsed = 0.0
	_pause_remaining = 0.0


func _finish_reveal(was_skipped: bool) -> void:
	_revealing = false
	set_process(false)
	_reset_timing()

	if target:
		target.visible_characters = _total_characters

	progress_changed.emit(
		_total_characters,
		_total_characters,
	)

	if was_skipped:
		skipped.emit()

	reveal_finished.emit()


static func _contains_codepoint(
	characters: String,
	codepoint: int,
) -> bool:
	for index in range(characters.length()):
		if characters.unicode_at(index) == codepoint:
			return true

	return false
