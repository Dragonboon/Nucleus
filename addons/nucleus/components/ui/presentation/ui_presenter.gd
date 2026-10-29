class_name NucleusUIPresenter
extends Node
## Reusable animated show/hide behavior for panels, dialogs, and HUD groups.
##
## New integrations should assign [member transition]. Legacy fade/scale exports
## remain a fallback for existing scenes.

signal transition_started(showing: bool)
signal shown
signal hidden

@export var target: Control
@export var transition: NucleusUITransitionProfile

@export_group("Legacy fallback")
@export var motion: NucleusUIMotionProfile
@export var fade: bool = true
@export var scale: bool = true
@export var hidden_scale: Vector2 = Vector2(0.96, 0.96)

@export_group("Lifecycle")
@export var hide_on_ready: bool = false

var _base_scale: Vector2
var _base_alpha: float
var _base_position: Vector2
var _base_rotation: float
var _base_mouse_filter: Control.MouseFilter

var _tween: Tween


func _ready() -> void:
	if not _resolve_target():
		return

	if motion == null:
		motion = NucleusUIMotionProfile.new()

	_capture_base_state()
	_update_pivot()
	target.resized.connect(_update_pivot)

	if hide_on_ready:
		hide_immediately()


func show_animated() -> Tween:
	_kill_tween()

	target.show()
	target.mouse_filter = _base_mouse_filter
	transition_started.emit(true)

	var profile := _resolve_transition()
	var motion_profile := profile.get_motion()
	var amplitude := NucleusUIMotion.get_effect_amplitude_scale(
		motion_profile
	)

	NucleusUIMotion.set_pivot_ratio(
		target,
		profile.get_pivot_ratio(),
	)
	_apply_hidden_state(profile, amplitude)

	var duration: float = NucleusUIMotion.get_duration(motion_profile)
	_tween = NucleusUIMotion.create_tween(
		target,
		motion_profile,
	).set_parallel(true)

	_append_visible_tween(profile, duration)

	_tween.finished.connect(
		_on_show_finished,
		CONNECT_ONE_SHOT,
	)

	return _tween


func hide_animated() -> Tween:
	_kill_tween()

	transition_started.emit(false)
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var profile := _resolve_transition()
	var motion_profile := profile.get_motion()
	var amplitude := NucleusUIMotion.get_effect_amplitude_scale(
		motion_profile
	)
	var duration: float = NucleusUIMotion.get_duration(motion_profile)

	NucleusUIMotion.set_pivot_ratio(
		target,
		profile.get_pivot_ratio(),
	)

	_tween = NucleusUIMotion.create_tween(
		target,
		motion_profile,
	).set_parallel(true)

	_append_hidden_tween(
		profile,
		amplitude,
		duration,
	)

	_tween.finished.connect(
		_on_hide_finished,
		CONNECT_ONE_SHOT,
	)

	return _tween


func show_immediately() -> void:
	_kill_tween()

	target.show()
	target.mouse_filter = _base_mouse_filter
	_restore_base_state()

	shown.emit()


func hide_immediately() -> void:
	_kill_tween()

	target.hide()
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_restore_base_state()

	hidden.emit()


func capture_current_as_base() -> void:
	_kill_tween()
	_capture_base_state()
	_update_pivot()


func _capture_base_state() -> void:
	_base_scale = target.scale
	_base_alpha = target.modulate.a
	_base_position = target.position
	_base_rotation = target.rotation
	_base_mouse_filter = target.mouse_filter


func _restore_base_state() -> void:
	target.scale = _base_scale
	target.modulate.a = _base_alpha
	target.position = _base_position
	target.rotation = _base_rotation


func _resolve_transition() -> NucleusUITransitionProfile:
	if transition:
		return transition

	var fallback := NucleusUITransitionProfile.new()
	fallback.motion = motion
	fallback.fade = fade
	fallback.use_scale = scale
	fallback.hidden_scale = hidden_scale
	return fallback


func _apply_hidden_state(
	profile: NucleusUITransitionProfile,
	amplitude: float,
) -> void:
	if profile.fade:
		target.modulate.a = profile.hidden_alpha

	if profile.use_scale:
		target.scale = profile.get_hidden_scale(
			_base_scale,
			amplitude,
		)

	if profile.use_offset:
		target.position = profile.get_hidden_position(
			_base_position,
			amplitude,
		)

	if profile.use_rotation:
		target.rotation = profile.get_hidden_rotation(
			_base_rotation,
			amplitude,
		)


func _append_visible_tween(
	profile: NucleusUITransitionProfile,
	duration: float,
) -> void:
	var added: bool = false

	if profile.fade:
		_tween.tween_property(
			target,
			"modulate:a",
			_base_alpha,
			duration,
		)
		added = true

	if profile.use_scale:
		_tween.tween_property(
			target,
			"scale",
			_base_scale,
			duration,
		)
		added = true

	if profile.use_offset:
		_tween.tween_property(
			target,
			"position",
			_base_position,
			duration,
		)
		added = true

	if profile.use_rotation:
		_tween.tween_property(
			target,
			"rotation",
			_base_rotation,
			duration,
		)
		added = true

	if not added:
		_tween.tween_interval(0.0)


func _append_hidden_tween(
	profile: NucleusUITransitionProfile,
	amplitude: float,
	duration: float,
) -> void:
	var added: bool = false

	if profile.fade:
		_tween.tween_property(
			target,
			"modulate:a",
			profile.hidden_alpha,
			duration,
		)
		added = true

	if profile.use_scale:
		_tween.tween_property(
			target,
			"scale",
			profile.get_hidden_scale(
				_base_scale,
				amplitude,
			),
			duration,
		)
		added = true

	if profile.use_offset:
		_tween.tween_property(
			target,
			"position",
			profile.get_hidden_position(
				_base_position,
				amplitude,
			),
			duration,
		)
		added = true

	if profile.use_rotation:
		_tween.tween_property(
			target,
			"rotation",
			profile.get_hidden_rotation(
				_base_rotation,
				amplitude,
			),
			duration,
		)
		added = true

	if not added:
		_tween.tween_interval(0.0)


func _update_pivot() -> void:
	if not target:
		return

	var ratio := (
		transition.get_pivot_ratio()
		if transition
		else Vector2(0.5, 0.5)
	)
	NucleusUIMotion.set_pivot_ratio(target, ratio)


func _resolve_target() -> bool:
	if target == null:
		target = get_parent() as Control

	if target:
		return true

	NucleusLog.error(
		"%s requires a Control target or parent." % get_path(),
		&"UIPresenter",
	)

	return false


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = null


func _on_show_finished() -> void:
	_tween = null
	_restore_base_state()
	shown.emit()


func _on_hide_finished() -> void:
	_tween = null
	_restore_base_state()
	target.hide()
	hidden.emit()
