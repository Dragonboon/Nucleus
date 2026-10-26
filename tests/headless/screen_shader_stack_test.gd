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
	var screen := Control.new()
	screen.size = Vector2(800, 450)
	var host := Node.new()
	host.add_child(screen)
	screen.add_child(stack)
	stack.backbuffer_target = screen
	stack.backend = NucleusScreenShaderStack.Backend.BACKBUFFER
	stack.max_passes = 2
	expect_equal(stack.configure(image, effects), OK,
		"Backbuffer configuration creates ordered native passes.")
	expect_equal(stack.stage_count(), 2, "One copy for each enabled shader.")
	expect_true(stack.get_pass_overlay(&"tint") != null,
		"Backbuffer passes expose an overlay for shader parameters.")
	expect_equal(stack.output_texture(), image,
		"Backbuffer draws in-place and retains the original texture contract.")
	expect_equal(stack.get_pass_canvas(&"tint"), null,
		"Viewport-only accessor remains explicit for backbuffer rendering.")
	expect_equal(stack.set_uniform(&"missing", &"value", 1.0), ERR_DOES_NOT_EXIST,
		"Unknown pass cannot mutate another material.")
	stack.max_passes = 1
	expect_equal(stack.rebuild(), ERR_OUT_OF_MEMORY,
		"Invalid rebuild must retain the previous render chain.")
	expect_equal(stack.stage_count(), 2, "Rejected rebuild retains native stages.")
	host.free()
	return finish()
