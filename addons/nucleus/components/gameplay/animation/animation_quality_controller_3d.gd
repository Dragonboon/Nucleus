@tool
class_name NucleusAnimationQualityController3D
extends Node
## Optional presentation-quality controller for 3D character animation.
##
## FULL restores authored behavior. REDUCED/MINIMAL may throttle pose evaluation
## and disable explicitly listed optional SkeletonModifier3D nodes.

signal quality_changed(quality: int)

@export var animation_tree: AnimationTree:
	set(value):
		_restore_animation_tree_mode()
		animation_tree = value
		_capture_animation_tree_mode()
		_apply_quality()
		update_configuration_warnings()

@export var quality_profile: NucleusAnimationQualityProfile3D:
	set(value):
		_disconnect_profile()
		quality_profile = value
		_connect_profile()
		_apply_quality()
		update_configuration_warnings()

@export_enum("Minimal", "Reduced", "Full")
var quality: int = NucleusAnimationQualityProfile3D.Quality.FULL:
	set(value):
		var resolved := clampi(
			value,
			NucleusAnimationQualityProfile3D.Quality.MINIMAL,
			NucleusAnimationQualityProfile3D.Quality.FULL,
		)

		if quality == resolved:
			return

		quality = resolved
		_apply_quality()

		if is_node_ready():
			quality_changed.emit(quality)

@export_group("Pose throttling")
## Opt in only when delayed animation-track callbacks are acceptable.
@export var allow_pose_throttling: bool = false:
	set(value):
		allow_pose_throttling = value
		_apply_quality()

@export_group("Optional modifiers")
## Disabled in Reduced and Minimal. Restored to authored state in Full.
@export var full_only_modifiers: Array[SkeletonModifier3D] = []
## Enabled in Reduced/Full and disabled in Minimal.
@export var reduced_or_full_modifiers: Array[SkeletonModifier3D] = []

var _profile_connected: NucleusAnimationQualityProfile3D
var _original_callback_mode: int = -1
var _modifier_states: Dictionary[int, bool] = {}
var _accumulated_delta: float = 0.0
var _manual_interval: float = 0.0


func _ready() -> void:
	_capture_animation_tree_mode()
	_capture_modifier_states()
	_connect_profile()
	_apply_quality()


func _exit_tree() -> void:
	_disconnect_profile()
	_restore_animation_tree_mode()
	_restore_modifiers()


func _process(delta: float) -> void:
	if (
		_manual_interval <= 0.0
		or animation_tree == null
		or not animation_tree.active
	):
		return

	_accumulated_delta += maxf(delta, 0.0)

	if _accumulated_delta < _manual_interval:
		return

	animation_tree.advance(_accumulated_delta)
	_accumulated_delta = 0.0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if animation_tree == null:
		warnings.append(
			"Assign AnimationTree to control pose evaluation quality."
		)

	if quality_profile != null:
		for error: String in quality_profile.get_validation_errors():
			warnings.append("Quality profile: %s" % error)

	if allow_pose_throttling:
		warnings.append(
			"Pose throttling can delay AnimationPlayer method tracks. "
			+ "Do not use it where animation callbacks are gameplay authority."
		)

	return warnings


func set_quality(value: int) -> void:
	quality = value


func apply_now() -> void:
	_capture_animation_tree_mode()
	_capture_modifier_states()
	_apply_quality()


func _apply_quality() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return

	_apply_modifier_quality()
	_apply_pose_quality()


func _apply_modifier_quality() -> void:
	_capture_modifier_states()

	match quality:
		NucleusAnimationQualityProfile3D.Quality.FULL:
			_restore_modifiers()

		NucleusAnimationQualityProfile3D.Quality.REDUCED:
			_set_modifier_group(full_only_modifiers, false)
			_restore_modifier_group(reduced_or_full_modifiers)

		_:
			_set_modifier_group(full_only_modifiers, false)
			_set_modifier_group(reduced_or_full_modifiers, false)


func _apply_pose_quality() -> void:
	if animation_tree == null:
		set_process(false)
		return

	_capture_animation_tree_mode()

	if (
		quality == NucleusAnimationQualityProfile3D.Quality.FULL
		or not allow_pose_throttling
		or quality_profile == null
	):
		_restore_animation_tree_mode()
		_manual_interval = 0.0
		_accumulated_delta = 0.0
		set_process(false)
		return

	var update_hz := quality_profile.get_update_hz(quality)

	if update_hz <= 0.0:
		_restore_animation_tree_mode()
		set_process(false)
		return

	animation_tree.callback_mode_process = (
		AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	)
	_manual_interval = 1.0 / update_hz
	_accumulated_delta = 0.0
	set_process(true)


func _capture_animation_tree_mode() -> void:
	if animation_tree == null or _original_callback_mode >= 0:
		return

	_original_callback_mode = animation_tree.callback_mode_process


func _restore_animation_tree_mode() -> void:
	if animation_tree == null or _original_callback_mode < 0:
		return

	if _accumulated_delta > 0.0 and animation_tree.active:
		animation_tree.advance(_accumulated_delta)

	animation_tree.callback_mode_process = _original_callback_mode
	_original_callback_mode = -1
	_accumulated_delta = 0.0


func _capture_modifier_states() -> void:
	_capture_modifier_group(full_only_modifiers)
	_capture_modifier_group(reduced_or_full_modifiers)


func _capture_modifier_group(
	modifiers: Array[SkeletonModifier3D],
) -> void:
	for modifier: SkeletonModifier3D in modifiers:
		if modifier == null:
			continue

		var key := modifier.get_instance_id()

		if not _modifier_states.has(key):
			_modifier_states[key] = modifier.active


func _restore_modifiers() -> void:
	_restore_modifier_group(full_only_modifiers)
	_restore_modifier_group(reduced_or_full_modifiers)


func _restore_modifier_group(
	modifiers: Array[SkeletonModifier3D],
) -> void:
	for modifier: SkeletonModifier3D in modifiers:
		if modifier == null:
			continue

		var key := modifier.get_instance_id()

		if _modifier_states.has(key):
			modifier.active = bool(_modifier_states[key])


func _set_modifier_group(
	modifiers: Array[SkeletonModifier3D],
	active: bool,
) -> void:
	for modifier: SkeletonModifier3D in modifiers:
		if modifier != null:
			modifier.active = active


func _connect_profile() -> void:
	if quality_profile == null or _profile_connected == quality_profile:
		return

	_profile_connected = quality_profile

	if not quality_profile.changed.is_connected(_on_profile_changed):
		quality_profile.changed.connect(_on_profile_changed)


func _disconnect_profile() -> void:
	if _profile_connected == null:
		return

	if _profile_connected.changed.is_connected(_on_profile_changed):
		_profile_connected.changed.disconnect(_on_profile_changed)

	_profile_connected = null


func _on_profile_changed() -> void:
	update_configuration_warnings()
	_apply_quality()
