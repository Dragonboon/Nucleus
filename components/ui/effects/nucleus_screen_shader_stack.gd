extends Node
class_name NucleusScreenShaderStack
## Optional native shader pass composition. Godot owns each rendering backend.
##
## VIEWPORT_CHAIN exposes a texture for downstream consumers. BACKBUFFER draws
## directly over an authored Control; output_texture() then returns the source.

signal output_changed(texture: Texture2D)
signal filters_changed

enum Backend {
	VIEWPORT_CHAIN,
	BACKBUFFER,
}

@export var backend: Backend = Backend.VIEWPORT_CHAIN
@export_range(128, 8192, 1) var max_dimension := 2048
@export_range(1, 8, 1) var max_passes := 6
@export var source_texture: Texture2D
@export var passes: Array[NucleusScreenEffectPass] = []

## The image Control that draws before the generated BackBufferCopy/ColorRect pairs.
## If omitted, the parent Control is used. No automatic CanvasLayer is created.
@export var backbuffer_target: Control
## Viewport copies avoid undefined sampling outside a smaller copied rectangle.
@export var backbuffer_full_viewport := true

var _stages: Array[SubViewport] = []
var _copies: Array[BackBufferCopy] = []
var _overlays: Array[ColorRect] = []
var _materials: Dictionary = {}
var _stage_controls: Dictionary = {}
var _screen_target: Control


func _ready() -> void:
	rebuild()


func _exit_tree() -> void:
	_clear_render_nodes()


func validate_configuration(
	texture: Texture2D, effects: Array[NucleusScreenEffectPass]
) -> Error:
	if texture == null or texture.get_size().x <= 0 or texture.get_size().y <= 0:
		return ERR_INVALID_PARAMETER
	if max_passes < 1 or (backend == Backend.VIEWPORT_CHAIN and max_dimension < 1):
		return ERR_INVALID_PARAMETER
	if backend == Backend.BACKBUFFER and _resolve_target() == null:
		return ERR_UNCONFIGURED
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
	var previous_texture := source_texture
	var previous_passes := passes
	source_texture = texture
	passes = effects.duplicate()
	var result := rebuild()
	if result != OK:
		source_texture = previous_texture
		passes = previous_passes
	return result


func rebuild() -> Error:
	if source_texture == null:
		_clear_render_nodes()
		output_changed.emit(null)
		filters_changed.emit()
		return OK
	var validation := validate_configuration(source_texture, passes)
	if validation != OK:
		return validation

	# Clone materials before replacing any existing render resources.
	var next_materials := {}
	for effect in passes:
		if not effect.enabled:
			continue
		var material_copy := effect.material.duplicate(true) as ShaderMaterial
		if material_copy == null:
			return ERR_CANT_CREATE
		next_materials[effect.id] = material_copy

	_clear_render_nodes()
	_materials = next_materials
	if backend == Backend.BACKBUFFER:
		_build_backbuffer()
	else:
		_build_viewports()
	output_changed.emit(output_texture())
	filters_changed.emit()
	return OK


func output_texture() -> Texture2D:
	## BACKBUFFER is an in-place overlay, not a postprocessed texture.
	if backend == Backend.BACKBUFFER or _stages.is_empty():
		return source_texture
	return _stages.back().get_texture()


func set_uniform(pass_id: StringName, uniform: StringName, value: Variant) -> Error:
	if uniform == &"" or not _materials.has(pass_id):
		return ERR_DOES_NOT_EXIST
	var local_material: ShaderMaterial = _materials[pass_id]
	local_material.set_shader_parameter(uniform, value)
	return OK


func get_pass_canvas(pass_id: StringName) -> TextureRect:
	## Compatibility: viewport passes have TextureRects, backbuffer passes do not.
	return _stage_controls.get(pass_id) as TextureRect


func get_pass_overlay(pass_id: StringName) -> ColorRect:
	for overlay in _overlays:
		if overlay.get_meta(&"nucleus_pass_id") == pass_id:
			return overlay
	return null


func get_pass_canvas_item(pass_id: StringName) -> CanvasItem:
	var overlay := get_pass_overlay(pass_id)
	if overlay != null:
		return overlay
	return get_pass_canvas(pass_id)


func get_pass_material(pass_id: StringName) -> ShaderMaterial:
	return _materials.get(pass_id) as ShaderMaterial


func stage_count() -> int:
	return _stages.size() + _copies.size()


func _resolve_target() -> Control:
	var target := backbuffer_target
	if target == null and get_parent() is Control:
		target = get_parent() as Control
	if target == null or not is_instance_valid(target):
		return null
	return target


func _build_viewports() -> void:
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
		stage.gui_disable_input = true
		add_child(stage)
		var quad := TextureRect.new()
		quad.name = "Source"
		quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		quad.stretch_mode = TextureRect.STRETCH_SCALE
		quad.texture = previous
		quad.material = _materials[effect.id]
		stage.add_child(quad)
		quad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_stage_controls[effect.id] = quad
		_stages.append(stage)
		previous = stage.get_texture()


func _build_backbuffer() -> void:
	_screen_target = _resolve_target()
	for effect in passes:
		if not effect.enabled:
			continue
		# BackBufferCopy and ColorRect must be consecutive siblings in draw order.
		var copy := BackBufferCopy.new()
		copy.name = "BackBuffer_%d" % _copies.size()
		copy.copy_mode = (
			BackBufferCopy.COPY_MODE_VIEWPORT if backbuffer_full_viewport
			else BackBufferCopy.COPY_MODE_RECT
		)
		_screen_target.add_child(copy)
		_copies.append(copy)
		var overlay := ColorRect.new()
		overlay.name = "Filter_%d" % _overlays.size()
		overlay.color = Color.WHITE
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.material = _materials[effect.id]
		overlay.set_meta(&"nucleus_pass_id", effect.id)
		_screen_target.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_overlays.append(overlay)
	_update_copy_rects()
	if not _copies.is_empty() and not _screen_target.resized.is_connected(_update_copy_rects):
		_screen_target.resized.connect(_update_copy_rects)


func _update_copy_rects() -> void:
	if not is_instance_valid(_screen_target):
		return
	for copy in _copies:
		if is_instance_valid(copy):
			copy.rect = Rect2(Vector2.ZERO, _screen_target.size)


func _clear_render_nodes() -> void:
	if is_instance_valid(_screen_target):
		if _screen_target.resized.is_connected(_update_copy_rects):
			_screen_target.resized.disconnect(_update_copy_rects)
	for overlay in _overlays:
		if is_instance_valid(overlay):
			overlay.free()
	for copy in _copies:
		if is_instance_valid(copy):
			copy.free()
	for stage in _stages:
		if is_instance_valid(stage):
			stage.free()
	_overlays.clear()
	_copies.clear()
	_stages.clear()
	_stage_controls.clear()
	_materials.clear()
	_screen_target = null
