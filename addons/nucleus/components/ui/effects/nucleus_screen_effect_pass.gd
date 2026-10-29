extends Resource
class_name NucleusScreenEffectPass
## One isolated canvas-item shader pass; materials remain authored resources.

@export var id: StringName
@export var material: ShaderMaterial
@export var enabled := true


func is_valid_pass() -> bool:
	return id != &"" and material != null and material.shader != null and (
		material.shader.get_mode() == Shader.MODE_CANVAS_ITEM
	)
