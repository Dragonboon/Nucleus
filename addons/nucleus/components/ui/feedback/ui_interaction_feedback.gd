class_name NucleusUIInteractionFeedback
extends Node
## Adds polished hover, focus, press, selection, and optional audio feedback.
##
## The component is presentation-only. It never handles the Control's business
## action and it does not replace Theme states.

@export var target: Control
@export var profile: NucleusUIFeedbackProfile

var _base_scale: Vector2
var _base_alpha: float
var _base_position: Vector2
var _base_rotation: float

var _hovered: bool = false
var _focused: bool = false
var _pressed: bool = false
var _selected: bool = false

var _tween: Tween


func _ready() -> void:
	if not _resolve_dependencies():
		return

	if profile == null:
		profile = NucleusUIFeedbackProfile.new()

	if profile.motion == null:
		profile.motion = NucleusUIMotionProfile.new()
		profile.motion.duration = 0.1

	_capture_base_state()
	_update_pivot()

	target.resized.connect(_update_pivot)
	target.mouse_entered.connect(_on_mouse_entered)
	target.mouse_exited.connect(_on_mouse_exited)
	target.focus_entered.connect(_on_focus_entered)
	target.focus_exited.connect(_on_focus_exited)

	if target is BaseButton:
		var button := target as BaseButton
		button.button_down.connect(_on_button_down)
		button.button_up.connect(_on_button_up)
		button.toggled.connect(_on_toggled)
		_selected = button.toggle_mode and button.button_pressed


func set_selected(
	selected: bool,
	animated: bool = true,
) -> void:
	if _selected == selected:
		return

	_selected = selected
	_refresh_visual_state(animated)


func is_selected() -> bool:
	return _selected


func refresh(animated: bool = true) -> void:
	_refresh_visual_state(animated)


func capture_current_as_base() -> void:
	_kill_tween()
	_capture_base_state()
	_refresh_visual_state(false)


func reset_immediately() -> void:
	_kill_tween()

	_hovered = false
	_focused = false
	_pressed = false
	_selected = false

	_apply_values(
		_base_scale,
		_base_alpha,
		_base_position,
		_base_rotation,
	)


func _resolve_dependencies() -> bool:
	if target == null:
		target = get_parent() as Control

	if target:
		return true

	NucleusLog.error(
		"%s requires a Control target or parent." % get_path(),
		&"UIFeedback",
	)

	return false


func _capture_base_state() -> void:
	_base_scale = target.scale
	_base_alpha = target.modulate.a
	_base_position = target.position
	_base_rotation = target.rotation


func _refresh_visual_state(animated: bool = true) -> void:
	_kill_tween()

	var state_profile := _get_visual_state()
	var motion_profile := (
		state_profile.get_motion(profile.motion)
		if state_profile
		else profile.motion
	)
	var values := (
		_get_profile_values(state_profile, motion_profile)
		if state_profile
		else _get_legacy_values(motion_profile)
	)

	if not animated:
		_apply_values(
			values["scale"],
			values["alpha"],
			values["position"],
			values["rotation"],
		)
		return

	var duration: float = NucleusUIMotion.get_duration(motion_profile)
	_tween = NucleusUIMotion.create_tween(
		target,
		motion_profile,
	).set_parallel(true)
	var added: bool = false

	if _owns_scale():
		_tween.tween_property(
			target,
			"scale",
			values["scale"],
			duration,
		)
		added = true

	if _owns_alpha():
		_tween.tween_property(
			target,
			"modulate:a",
			values["alpha"],
			duration,
		)
		added = true

	if _owns_position():
		_tween.tween_property(
			target,
			"position",
			values["position"],
			duration,
		)
		added = true

	if _owns_rotation():
		_tween.tween_property(
			target,
			"rotation",
			values["rotation"],
			duration,
		)
		added = true

	if not added:
		_tween.tween_interval(0.0)


func _get_profile_values(
	state_profile: NucleusUIVisualStateProfile,
	motion_profile: NucleusUIMotionProfile,
) -> Dictionary:
	var amplitude := NucleusUIMotion.get_effect_amplitude_scale(
		motion_profile
	)

	return {
		"scale": state_profile.get_scale(
			_base_scale,
			amplitude,
		),
		"alpha": state_profile.get_alpha(_base_alpha),
		"position": state_profile.get_position(
			_base_position,
			amplitude,
		),
		"rotation": state_profile.get_rotation(
			_base_rotation,
			amplitude,
		),
	}


func _get_legacy_values(
	motion_profile: NucleusUIMotionProfile,
) -> Dictionary:
	var scale_multiplier: float = 1.0
	var alpha: float = profile.idle_alpha

	if _pressed:
		scale_multiplier = profile.pressed_scale
		alpha = profile.pressed_alpha
	elif _focused:
		scale_multiplier = profile.focus_scale
		alpha = profile.active_alpha
	elif _hovered:
		scale_multiplier = profile.hover_scale
		alpha = profile.active_alpha
	elif _selected:
		scale_multiplier = profile.focus_scale
		alpha = profile.active_alpha

	var amplitude := NucleusUIMotion.get_effect_amplitude_scale(
		motion_profile
	)
	if (
		profile.disable_scale_with_reduced_motion
		and NucleusUIMotionPolicy.is_reduced_motion_enabled()
	):
		amplitude = 0.0

	var effective_multiplier := lerpf(
		1.0,
		scale_multiplier,
		amplitude,
	)

	return {
		"scale": (
			_base_scale * effective_multiplier
			if profile.use_scale
			else _base_scale
		),
		"alpha": (
			clampf(_base_alpha * alpha, 0.0, 1.0)
			if profile.use_opacity
			else _base_alpha
		),
		"position": _base_position,
		"rotation": _base_rotation,
	}


func _get_visual_state() -> NucleusUIVisualStateProfile:
	if _pressed and profile.pressed_state:
		return profile.pressed_state

	if _focused and profile.focus_state:
		return profile.focus_state

	if _hovered and profile.hover_state:
		return profile.hover_state

	if _selected and profile.selected_state:
		return profile.selected_state

	return profile.idle_state


func _apply_values(
	scale: Vector2,
	alpha: float,
	position: Vector2,
	rotation: float,
) -> void:
	if _owns_scale():
		target.scale = scale

	if _owns_alpha():
		target.modulate.a = alpha

	if _owns_position():
		target.position = position

	if _owns_rotation():
		target.rotation = rotation


func _owns_scale() -> bool:
	if profile.use_scale:
		return true

	for state: NucleusUIVisualStateProfile in _visual_states():
		if (state.scale_multiplier - Vector2.ONE).length_squared() > 0.000001:
			return true

	return false


func _owns_alpha() -> bool:
	if profile.use_opacity:
		return true

	for state: NucleusUIVisualStateProfile in _visual_states():
		if not is_equal_approx(state.alpha_multiplier, 1.0):
			return true

	return false


func _owns_position() -> bool:
	for state: NucleusUIVisualStateProfile in _visual_states():
		if state.offset.length_squared() > 0.000001:
			return true

	return false


func _owns_rotation() -> bool:
	for state: NucleusUIVisualStateProfile in _visual_states():
		if not is_zero_approx(state.rotation_degrees):
			return true

	return false


func _visual_states() -> Array[NucleusUIVisualStateProfile]:
	var states: Array[NucleusUIVisualStateProfile] = []

	if profile.idle_state:
		states.append(profile.idle_state)

	if profile.hover_state:
		states.append(profile.hover_state)

	if profile.focus_state:
		states.append(profile.focus_state)

	if profile.pressed_state:
		states.append(profile.pressed_state)

	if profile.selected_state:
		states.append(profile.selected_state)

	return states


func _update_pivot() -> void:
	if target:
		NucleusUIMotion.set_pivot_ratio(
			target,
			Vector2(0.5, 0.5),
		)


func _play_cue(cue: NucleusAudioCue) -> void:
	if cue:
		NucleusAudio.play_cue(cue)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = null


func _on_mouse_entered() -> void:
	_hovered = true
	_play_cue(profile.hover_cue)
	_refresh_visual_state()


func _on_mouse_exited() -> void:
	_hovered = false
	_refresh_visual_state()


func _on_focus_entered() -> void:
	_focused = true
	_play_cue(profile.focus_cue)
	_refresh_visual_state()


func _on_focus_exited() -> void:
	_focused = false
	_pressed = false
	_refresh_visual_state()


func _on_button_down() -> void:
	_pressed = true
	_play_cue(profile.pressed_cue)
	_refresh_visual_state()


func _on_button_up() -> void:
	_pressed = false
	_refresh_visual_state()


func _on_toggled(toggled_on: bool) -> void:
	_selected = toggled_on
	_refresh_visual_state()
