@tool
class_name NucleusMaterialInstanceBinding3D
extends Node
## Small runtime facade for GeometryInstance3D per-instance shader uniforms.
##
## Prefer this over duplicating ShaderMaterial when only scalar/vector values
## differ between otherwise shared geometry instances.

@export var target: GeometryInstance3D:
	set(value):
		target = value
		refresh_parameter_cache()
		update_configuration_warnings()

@export var validate_parameter_names: bool = true

var _parameter_names: Dictionary[StringName, bool] = {}


func _ready() -> void:
	refresh_parameter_cache()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if target == null:
		warnings.append("Assign a GeometryInstance3D target.")

	return warnings


func set_parameter(
	parameter: StringName,
	value: Variant,
) -> Error:
	if target == null:
		return ERR_UNCONFIGURED

	if parameter == &"":
		return ERR_INVALID_PARAMETER

	if not is_supported_instance_value(value):
		return ERR_INVALID_PARAMETER

	if validate_parameter_names and not has_parameter(parameter):
		return ERR_DOES_NOT_EXIST

	target.set_instance_shader_parameter(parameter, value)
	return OK


func set_parameters(values: Dictionary) -> Error:
	for key: Variant in values:
		var parameter := StringName(str(key))
		var error := set_parameter(parameter, values[key])

		if error != OK:
			return error

	return OK


func get_parameter(parameter: StringName) -> Variant:
	if target == null or parameter == &"":
		return null

	return target.get_instance_shader_parameter(parameter)


func has_parameter(parameter: StringName) -> bool:
	if target == null or parameter == &"":
		return false

	if _parameter_names.is_empty():
		refresh_parameter_cache()

	return _parameter_names.has(parameter)


func refresh_parameter_cache() -> void:
	_parameter_names.clear()

	if target == null:
		return

	for entry: Dictionary in target.get_instance_shader_parameter_list():
		var parameter: StringName = StringName(str(entry.get("name", "")))

		if parameter != &"":
			_parameter_names[parameter] = true


static func is_supported_instance_value(value: Variant) -> bool:
	return typeof(value) in [
		TYPE_BOOL,
		TYPE_INT,
		TYPE_FLOAT,
		TYPE_VECTOR2,
		TYPE_VECTOR3,
		TYPE_VECTOR4,
		TYPE_COLOR,
	]
