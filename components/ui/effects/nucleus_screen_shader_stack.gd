extends Node
class_name NucleusScreenShaderStack
## A bounded, ordered series of native SubViewport CanvasItem shader passes.
## Use output_texture() as an image source; never copy screen pixels each frame.

signal output_changed(texture: Texture2D)
signal filters_changed

@export_range(128, 8192, 1) var max_dimension := 2048
@export_range(1, 8, 1) var max_passes := 6
@export var source_texture: Texture2D
@export var passes: Array[NucleusScreenEffectPass] = []

var _stages: Array[SubViewport] = []
var _materials: Dictionary = {}
var _stage_controls: Dictionary = {}


func _ready() -> void:
	rebuild()


func validate_configuration(
	texture: Texture2D, effects: Array[NucleusScreenEffectPass]
) -> Error:
	if texture == null or texture.get_size().x <= 0 or texture.get_size().y <= 0:
		return ERR_INVALID_PARAMETER
	var count := 0
	var ids := {}
	for effect in effects:
		if effect == null or not effect.is_valid_pass() or ids.has(effect.id):
			return ERR_INVALID_DATA
		ids[effect.id] = true
		if effect.enabled:
			count += 1
	if count > max_passes:
		return ERR_OUT_OF_MEMORY
	return OK


func configure(
	texture: Texture2D, effects: Array[NucleusScreenEffectPass]
) -> Error:
	var validation := validate_configuration(texture, effects)
	if validation != OK:
		return validation
	source_texture = texture
	passes = effects.duplicate()
	return rebuild()


func rebuild() -> Error:
	for stage in _stages:
		if is_instance_valid(stage):
			remove_child(stage)
			stage.queue_free()
	_stages.clear()
	_materials.clear()
	_stage_controls.clear()
	if source_texture == null:
		output_changed.emit(null)
		return OK
	var error := validate_configuration(source_texture, passes)
	if error != OK:
		return error
	var image_size := source_texture.get_size()
	var ratio: float = minf(1.0, float(max_dimension) / maxf(
		float(image_size.x), float(image_size.y)))
	var stage_size := Vector2i(
		maxi(1, int(round(image_size.x * ratio))),
		maxi(1, int(round(image_size.y * ratio)))
	)
	var previous: Texture2D = source_texture
	for effect in passes:
		if not effect.enabled:
			continue
		var stage := SubViewport.new()
		stage.name = "Pass_%d" % _stages.size()
		stage.size = stage_size
		stage.disable_3d = true
		stage.transparent_bg = true
		stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(stage)
		var quad := TextureRect.new()
		quad.name = "Source"
		quad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		quad.stretch_mode = TextureRect.STRETCH_SCALE
		quad.texture = previous
		quad.material = effect.material.duplicate(true) as ShaderMaterial
		stage.add_child(quad)
		quad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_materials[effect.id] = quad.material
		_stage_controls[effect.id] = quad
		_stages.append(stage)
		previous = stage.get_texture()
	output_changed.emit(previous)
	filters_changed.emit()
	return OK


func output_texture() -> Texture2D:
	if not _stages.is_empty():
		return _stages.back().get_texture()
	return source_texture


func set_uniform(pass_id: StringName, uniform: StringName, value: Variant) -> Error:
	if uniform == &"" or not _materials.has(pass_id):
		return ERR_DOES_NOT_EXIST
	var local_material: ShaderMaterial = _materials[pass_id]
	local_material.set_shader_parameter(uniform, value)
	return OK


func get_pass_canvas(pass_id: StringName) -> TextureRect:
	return _stage_controls.get(pass_id) as TextureRect


func get_pass_material(pass_id: StringName) -> ShaderMaterial:
	return _materials.get(pass_id) as ShaderMaterial


func stage_count() -> int:
	return _stages.size()
