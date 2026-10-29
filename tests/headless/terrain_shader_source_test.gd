extends "res://tests/headless/test_case.gd"
## Regression for camera data passed into custom terrain shader helpers.

const SHADER_PATH := "res://addons/nucleus/modules/terrain/shaders/layered_terrain.gdshader"


func run() -> Dictionary:
	_test_detail_fade_camera_scope()
	return finish()


func _test_detail_fade_camera_scope() -> void:
	var source: String = FileAccess.get_file_as_string(SHADER_PATH)
	expect_false(
		source.is_empty(),
		"Built-in terrain shader source must remain accessible.",
	)
	if source.is_empty():
		return

	var helper_start: int = source.find("float detail_fade_at(")
	var vertex_start: int = source.find("void vertex()", helper_start)
	expect_true(
		helper_start >= 0 and vertex_start > helper_start,
		"Distance-fade helper must precede the vertex stage.",
	)
	if helper_start < 0 or vertex_start <= helper_start:
		return

	var helper: String = source.substr(
		helper_start,
		vertex_start - helper_start,
	)
	expect_false(
		helper.contains("CAMERA_POSITION_WORLD"),
		"Custom shader helpers cannot reference stage-only camera built-ins.",
	)
	expect_true(
		helper.contains("vec3 camera_position"),
		"Distance-fade helper must accept the camera position explicitly.",
	)
	expect_true(
		helper.contains("distance(camera_position, position)"),
		"Fade distance must still be computed in world coordinates.",
	)

	var fragment_start: int = source.find("void fragment()")
	expect_true(fragment_start >= 0, "Terrain must retain the fragment stage.")
	if fragment_start < 0:
		return

	var fragment_code: String = source.substr(fragment_start)
	expect_true(
		fragment_code.contains("CAMERA_POSITION_WORLD"),
		"Fragment stage must supply the supported camera-position built-in.",
	)
	expect_true(
		fragment_code.contains("detail_fade_at("),
		"Terrain fragment must still compute the detail fade.",
	)
