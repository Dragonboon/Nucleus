class_name NucleusSceneTransitionOverlay
extends CanvasLayer
## Temporary full-screen presentation used by NucleusSceneFlow.
##
## Subclass this Node when a project needs a custom transition scene. Override
## begin_cover() and begin_reveal(), then emit covered/revealed when finished.

signal covered
signal revealed

@export var build_default_visuals: bool = true

const DEFAULT_TILE_SHADER: Shader = preload(
	"res://addons/nucleus/core/scene_flow/scene_transition_tiles.gdshader"
)

var _profile: NucleusSceneTransitionProfile
var _root: Control
var _primary: ColorRect
var _secondary: ColorRect
var _shader_material: ShaderMaterial
var _tween: Tween
var _visual_progress: float = 0.0


func configure(profile: NucleusSceneTransitionProfile) -> void:
	_profile = profile

	if is_node_ready():
		_apply_profile()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if build_default_visuals:
		_build_default_visuals()
	_apply_profile()
	_set_visual_progress(0.0)


func begin_cover() -> Error:
	if _profile == null:
		return ERR_UNCONFIGURED

	_animate_progress(
		1.0,
		_profile.cover_duration,
		Callable(self, "_emit_covered"),
		_profile.covered_hold_seconds,
	)
	return OK


func begin_reveal() -> Error:
	if _profile == null:
		return ERR_UNCONFIGURED

	_animate_progress(
		0.0,
		_profile.reveal_duration,
		Callable(self, "_emit_revealed"),
	)
	return OK


func get_visual_progress() -> float:
	return _visual_progress


func get_profile() -> NucleusSceneTransitionProfile:
	return _profile


func cancel_animation() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = null


func _build_default_visuals() -> void:
	if _root != null:
		return

	_root = Control.new()
	_root.name = "TransitionSurface"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_primary = ColorRect.new()
	_primary.name = "Primary"
	_primary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_primary)

	_secondary = ColorRect.new()
	_secondary.name = "Secondary"
	_secondary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_secondary)


func _apply_profile() -> void:
	if _profile == null or _root == null:
		return

	layer = _profile.canvas_layer
	_root.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if _profile.block_input
		else Control.MOUSE_FILTER_IGNORE
	)
	_primary.material = null
	_secondary.material = null
	_shader_material = null

	if _profile.mode == NucleusSceneTransitionProfile.Mode.SHADER:
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = (
			_profile.shader
			if _profile.shader != null
			else DEFAULT_TILE_SHADER
		)
		_primary.material = _shader_material

		if _profile.shader == null:
			_shader_material.set_shader_parameter(
				&"transition_color",
				_profile.color,
			)

		for key: Variant in _profile.shader_parameters:
			_shader_material.set_shader_parameter(
				StringName(str(key)),
				_profile.shader_parameters[key],
			)

	_set_visual_progress(_visual_progress)


func _animate_progress(
	target: float,
	duration: float,
	finished_callback: Callable,
	hold_seconds: float = 0.0,
) -> void:
	cancel_animation()

	if duration <= 0.0:
		_set_visual_progress(target)
		if hold_seconds <= 0.0:
			finished_callback.call_deferred()
			return

	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_ignore_time_scale(true)

	if duration > 0.0:
		_tween.tween_method(
			Callable(self, "_set_visual_progress"),
			_visual_progress,
			target,
			duration,
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	if hold_seconds > 0.0:
		_tween.tween_interval(hold_seconds)

	_tween.finished.connect(finished_callback, CONNECT_ONE_SHOT)


func _set_visual_progress(value: float) -> void:
	_visual_progress = clampf(value, 0.0, 1.0)

	if _profile == null or _primary == null:
		return

	match _profile.mode:
		NucleusSceneTransitionProfile.Mode.CURTAIN:
			_layout_curtain(_visual_progress)
		NucleusSceneTransitionProfile.Mode.SHADER:
			_layout_full_rect(_primary)
			_secondary.hide()
			_primary.color = Color.WHITE
			if _shader_material != null:
				_shader_material.set_shader_parameter(
					_profile.shader_progress_parameter,
					_visual_progress,
				)
		_:
			_layout_full_rect(_primary)
			_secondary.hide()
			_primary.material = null
			_primary.color = Color(
				_profile.color.r,
				_profile.color.g,
				_profile.color.b,
				_profile.color.a * _visual_progress,
			)


func _layout_full_rect(rect: Control) -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	rect.show()
	rect.position = Vector2.ZERO
	rect.size = size


func _layout_curtain(progress: float) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var color := _profile.color

	_primary.show()
	_secondary.show()
	_primary.material = null
	_secondary.material = null
	_primary.color = color
	_secondary.color = color

	if _profile.curtain_axis == NucleusSceneTransitionProfile.CurtainAxis.HORIZONTAL:
		var half_width: float = viewport_size.x * 0.5
		var covered_width: float = half_width * progress
		_primary.position = Vector2.ZERO
		_primary.size = Vector2(covered_width, viewport_size.y)
		_secondary.position = Vector2(
			viewport_size.x - covered_width,
			0.0,
		)
		_secondary.size = Vector2(covered_width, viewport_size.y)
		return

	var half_height: float = viewport_size.y * 0.5
	var covered_height: float = half_height * progress
	_primary.position = Vector2.ZERO
	_primary.size = Vector2(viewport_size.x, covered_height)
	_secondary.position = Vector2(
		0.0,
		viewport_size.y - covered_height,
	)
	_secondary.size = Vector2(viewport_size.x, covered_height)


func _emit_covered() -> void:
	covered.emit()


func _emit_revealed() -> void:
	revealed.emit()
