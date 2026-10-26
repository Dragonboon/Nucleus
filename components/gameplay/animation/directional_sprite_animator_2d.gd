class_name NucleusDirectionalSpriteAnimator2D
extends Node
## Sole clip selector for an AnimatedSprite2D; never writes gameplay transforms.

signal action_finished(action: StringName)
signal action_canceled(action: StringName)

@export var sprite: AnimatedSprite2D
@export var profile: NucleusDirectionalSpriteProfile2D
var _bound: AnimatedSprite2D
var _configuration: NucleusDirectionalSpriteProfile2D
var _direction: int = 0
var _moving: bool = false
var _action: StringName = &""
var _held: bool = false
var _hold_on_finish: bool = false


func _enter_tree() -> void:
	if is_node_ready():
		configure(sprite, profile)


func _ready() -> void:
	configure(sprite, profile)


## Atomic replacement: invalid profiles leave the previous binding untouched.
func configure(
	value: AnimatedSprite2D, settings: NucleusDirectionalSpriteProfile2D,
) -> Error:
	if not is_instance_valid(value) or settings == null:
		return ERR_UNCONFIGURED
	if not settings.get_validation_errors(value.sprite_frames).is_empty():
		return ERR_INVALID_DATA
	_disconnect()
	sprite = value
	profile = settings
	_bound = value
	_configuration = settings.duplicate(true)
	_direction = 0
	_moving = false
	_action = &""
	_held = false
	_bound.animation_finished.connect(_on_animation_finished)
	_play_locomotion()
	return OK


func update_motion(velocity: Vector2, aim: Vector2 = Vector2.ZERO) -> Error:
	if not _available():
		return ERR_UNCONFIGURED
	if not velocity.is_finite() or not aim.is_finite():
		return ERR_INVALID_PARAMETER
	var speed := velocity.length()
	if speed >= _configuration.start_speed:
		_moving = true
	elif speed <= _configuration.stop_speed:
		_moving = false
	var facing := aim if not aim.is_zero_approx() else velocity
	if not facing.is_zero_approx():
		var step := TAU / float(_configuration.idle_clips.size())
		var angle := facing.angle()
		if absf(angle_difference(float(_direction) * step, angle)) > (
			step * 0.5 + _configuration.direction_hysteresis
		):
			_direction = posmod(roundi(angle / step), _configuration.idle_clips.size())
	if _action == &"" and not _held:
		_play_locomotion()
	return OK


## Actions lock their starting direction. Repeated requests never restart the clip.
## hold_last_frame keeps a terminal pose until cancel_action or configure.
func play_action(
	action: StringName, interrupt: bool = false, hold_last_frame: bool = false,
) -> Error:
	if not _available():
		return ERR_UNCONFIGURED
	if not _configuration.action_clips.has(action):
		return ERR_DOES_NOT_EXIST
	if _held or (_action != &"" and _action != action):
		if not interrupt:
			return ERR_BUSY
	if _action == action:
		return OK
	var previous := _action
	_action = action
	_held = false
	_hold_on_finish = hold_last_frame
	_bound.play(_configuration.action_clips[action][_direction])
	if previous != &"":
		action_canceled.emit(previous)
	return OK


func cancel_action() -> void:
	var previous := _action
	_action = &""
	_held = false
	if _available():
		_play_locomotion()
	if previous != &"":
		action_canceled.emit(previous)


func get_current_action() -> StringName:
	return _action


func _available() -> bool:
	return is_instance_valid(_bound) and _configuration != null


func _play_locomotion() -> void:
	var clips := _configuration.move_clips if _moving else _configuration.idle_clips
	var clip := StringName(clips[_direction])
	if _bound.animation != clip or not _bound.is_playing():
		_bound.play(clip)


func _on_animation_finished() -> void:
	if _action == &"":
		return
	var finished := _action
	_action = &""
	_held = _hold_on_finish
	if not _held:
		_play_locomotion()
	action_finished.emit(finished)


func _exit_tree() -> void:
	_disconnect()
	_action = &""
	_held = false


func _disconnect() -> void:
	if is_instance_valid(_bound) and _bound.animation_finished.is_connected(_on_animation_finished):
		_bound.animation_finished.disconnect(_on_animation_finished)
	_bound = null
	_configuration = null
