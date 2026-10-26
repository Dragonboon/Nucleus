extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	var stack := NucleusScreenShaderStack.new()
	var image := ImageTexture.create_from_image(
		Image.create(16, 8, false, Image.FORMAT_RGBA8))
	var effects: Array[NucleusScreenEffectPass] = []
	expect_equal(stack.validate_configuration(image, effects), OK,
		"Unfiltered image is valid.")
	expect_equal(stack.configure(image, effects), OK, "Zero-pass rendering works.")
	expect_equal(stack.output_texture(), image, "Identity stack preserves texture.")
	var pass_one := NucleusScreenEffectPass.new()
	pass_one.id = &"tint"
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { COLOR = texture(TEXTURE, UV); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	pass_one.material = material
	effects.append(pass_one)
	expect_equal(stack.validate_configuration(image, effects), OK,
		"One CanvasItem effect is accepted.")
	stack.max_passes = 1
	effects.append(pass_one)
	expect_equal(stack.validate_configuration(image, effects), ERR_INVALID_DATA,
		"Duplicate pass identifiers are rejected.")
	effects.pop_back()
	var second := NucleusScreenEffectPass.new()
	second.id = &"grain"
	second.material = material
	effects.append(second)
	expect_equal(stack.validate_configuration(image, effects), ERR_OUT_OF_MEMORY,
		"Configured pass budget is enforced.")
	stack.free()
	return finish()
