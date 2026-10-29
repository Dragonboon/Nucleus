class_name NucleusUIShaderEffect
extends Node
## Animates parameters on a game-owned CanvasItem ShaderMaterial.
##
## Ordinary uniforms use a duplicated local material by default. Shaders that
## declare `instance uniform` can opt into INSTANCE_UNIFORM mode to retain
## shared material reuse.

signal parameter_animation_started(parameter: StringName)
signal parameter_animation_finished(parameter: StringName)

enum ParameterMode {
	DUPLICATED_MATERIAL,
	INSTANCE_UNIFORM,
	SHARED_MATERIAL,
}

@export var target: CanvasItem
@export var motion: NucleusUIMotionProfile
@export var parameter_mode: ParameterMode = ParameterMode.DUPLICATED_MATERIAL

var _shader_material: ShaderMaterial
var _tweens: Dictionary[StringName, Tween] = {}


func _ready() -> void:
	if motion == null:
		motion = NucleusUIMotionProfile.new()

	var error := refresh_material()

	if error != OK:
		NucleusLog.error(
			"%s requires a target with ShaderMaterial." % get_path(),
			&"UIShaderEffect",
		)


func refresh_material() -> Error:
	if target == null:
		target = get_parent() as CanvasItem

	if target == null or not target.material is ShaderMaterial:
		_shader_material = null
		return ERR_UNCONFIGURED

	var source := target.material as ShaderMaterial

	if parameter_mode == ParameterMode.DUPLICATED_MATERIAL:
		var duplicated := source.duplicate(true)

		if not duplicated is ShaderMaterial:
			_shader_material = null
			return ERR_CANT_CREATE

		_shader_material = duplicated as ShaderMaterial
		target.material = _shader_material
	else:
		_shader_material = source

	return OK


func get_shader_material() -> ShaderMaterial:
	return _shader_material


func set_parameter(
	parameter: StringName,
	value: Variant,
) -> Error:
	if _shader_material == null or parameter == &"":
		return ERR_UNCONFIGURED

	_kill_parameter_tween(parameter)
	_apply_parameter(value, parameter)
	return OK


func animate_parameter(
	parameter: StringName,
	target_value: Variant,
	duration_multiplier: float = 1.0,
) -> Tween:
	if _shader_material == null or parameter == &"":
		return null

	var start_value: Variant = _get_parameter(parameter)

	if (
		not is_interpolatable_value(start_value)
		or not is_interpolatable_value(target_value)
		or typeof(start_value) != typeof(target_value)
	):
		return null

	_kill_parameter_tween(parameter)

	var tween := NucleusUIMotion.create_tween(self, motion)
	var duration := NucleusUIMotion.get_duration(
		motion,
		maxf(0.0, duration_multiplier),
	)

	tween.tween_method(
		_apply_parameter.bind(parameter),
		start_value,
		target_value,
		duration,
	)
	tween.finished.connect(
		_on_parameter_finished.bind(parameter),
		CONNECT_ONE_SHOT,
	)

	_tweens[parameter] = tween
	parameter_animation_started.emit(parameter)
	return tween


func stop_parameter(parameter: StringName) -> void:
	_kill_parameter_tween(parameter)


func stop_all() -> void:
	for parameter: StringName in _tweens.keys():
		_kill_parameter_tween(parameter)


static func is_interpolatable_value(value: Variant) -> bool:
	return typeof(value) in [
		TYPE_FLOAT,
		TYPE_INT,
		TYPE_VECTOR2,
		TYPE_VECTOR3,
		TYPE_VECTOR4,
		TYPE_COLOR,
	]


func _get_parameter(parameter: StringName) -> Variant:
	if parameter_mode == ParameterMode.INSTANCE_UNIFORM:
		var value: Variant = target.get_instance_shader_parameter(parameter)

		if value != null:
			return value

	return _shader_material.get_shader_parameter(parameter)


func _apply_parameter(
	value: Variant,
	parameter: StringName,
) -> void:
	if _shader_material == null:
		return

	if parameter_mode == ParameterMode.INSTANCE_UNIFORM:
		target.set_instance_shader_parameter(parameter, value)
	else:
		_shader_material.set_shader_parameter(parameter, value)


func _kill_parameter_tween(parameter: StringName) -> void:
	if not _tweens.has(parameter):
		return

	var tween: Tween = _tweens[parameter]

	if tween and tween.is_valid():
		tween.kill()

	_tweens.erase(parameter)


func _on_parameter_finished(parameter: StringName) -> void:
	_tweens.erase(parameter)
	parameter_animation_finished.emit(parameter)
