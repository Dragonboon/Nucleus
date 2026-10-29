class_name NucleusWindow
extends RefCounted
## Stateless helpers for viewport, screenshots, and desktop-window calculations.
##
## This replaces the pure portions of Barebone's WindowManager without adding
## another globally stateful Autoload.

const SCREENSHOT_EXTENSIONS := [
	"png",
	"jpg",
	"jpeg",
	"webp",
]


## Returns the visible size of a viewport.
static func get_viewport_size(viewport: Viewport) -> Vector2:
	if viewport == null:
		return Vector2.ZERO

	return viewport.get_visible_rect().size


## Returns the center point of a viewport in viewport coordinates.
static func get_viewport_center(viewport: Viewport) -> Vector2:
	return get_viewport_size(viewport) * 0.5


## Returns the viewport width divided by its height.
static func get_viewport_aspect_ratio(viewport: Viewport) -> float:
	var viewport_size: Vector2 = get_viewport_size(viewport)

	if is_zero_approx(viewport_size.y):
		return 0.0

	return viewport_size.x / viewport_size.y


## Returns the viewport center transformed into the CanvasItem's local canvas.
static func get_viewport_center_in_canvas(canvas_item: CanvasItem) -> Vector2:
	if canvas_item == null:
		return Vector2.ZERO

	var viewport: Viewport = canvas_item.get_viewport()
	var viewport_center: Vector2 = get_viewport_center(viewport)

	return canvas_item.get_canvas_transform().affine_inverse() * viewport_center


## Returns mouse displacement from viewport center normalized to [-1, 1]-like
## screen-relative coordinates independent from the current resolution.
static func get_relative_mouse_position(viewport: Viewport) -> Vector2:
	if viewport == null:
		return Vector2.ZERO

	var viewport_size: Vector2 = get_viewport_size(viewport)
	var largest_dimension: float = maxf(viewport_size.x, viewport_size.y)

	if is_zero_approx(largest_dimension):
		return Vector2.ZERO

	var mouse_offset: Vector2 = viewport.get_mouse_position() - viewport_size * 0.5

	return mouse_offset / largest_dimension


## Returns the center of the usable area of a physical display.
static func get_display_center(
	screen: int = DisplayServer.SCREEN_OF_MAIN_WINDOW,
) -> Vector2i:
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen)

	@warning_ignore("integer_division")
	return usable_rect.position + usable_rect.size / 2


## Centers a desktop window inside the usable area of a display.
static func center_window(
	window: Window,
	screen: int = DisplayServer.SCREEN_OF_MAIN_WINDOW,
) -> void:
	if window == null:
		return

	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var window_size: Vector2i = window.get_size_with_decorations()

	@warning_ignore("integer_division")
	window.position = usable_rect.position + (usable_rect.size - window_size) / 2


## Copies the viewport's last rendered frame into an Image.
##
## For a current frame, call after RenderingServer.frame_post_draw or use
## capture_viewport_after_draw().
static func capture_viewport(
	viewport: Viewport,
	include_alpha: bool = false,
) -> Image:
	if viewport == null:
		return null

	var viewport_texture: Texture2D = viewport.get_texture()

	if viewport_texture == null:
		return null

	var image: Image = viewport_texture.get_image()

	if image == null or image.is_empty():
		return null

	if include_alpha:
		image.convert(Image.FORMAT_RGBA8)
	else:
		image.convert(Image.FORMAT_RGB8)

	if viewport.use_hdr_2d:
		image.linear_to_srgb()

	if include_alpha:
		image.fix_alpha_edges()

	return image


## Waits for rendering to finish, then captures the viewport.
static func capture_viewport_after_draw(
	viewport: Viewport,
	include_alpha: bool = false,
) -> Image:
	await RenderingServer.frame_post_draw
	return capture_viewport(
		viewport,
		include_alpha,
	)


## Builds a collision-safe screenshot path using the current system date/time.
static func build_screenshot_path(
	directory: String = "",
	prefix: String = "screenshot",
	extension: String = "png",
) -> String:
	var normalized_extension: String = (
		extension
		.strip_edges()
		.trim_prefix(".")
		.to_lower()
	)

	if normalized_extension not in SCREENSHOT_EXTENSIONS:
		return ""

	var target_directory: String = directory.strip_edges()

	if target_directory.is_empty():
		target_directory = NucleusPaths.screenshots_directory()

	target_directory = ProjectSettings.globalize_path(target_directory)

	var safe_prefix: String = _sanitize_filename_part(prefix)

	if safe_prefix.is_empty():
		safe_prefix = "screenshot"

	var timestamp: String = (
		Time.get_datetime_string_from_system()
		.replace(":", "-")
		.replace("T", "_")
	)
	var candidate: String = target_directory.path_join(
		"%s_%s.%s"
		% [
			safe_prefix,
			timestamp,
			normalized_extension,
		]
	)

	return _next_available_path(candidate)


## Saves an already captured screenshot Image based on the target extension.
static func save_screenshot_image(
	image: Image,
	file_path: String,
	quality: float = 0.9,
	webp_lossy: bool = false,
) -> Error:
	if image == null or image.is_empty():
		return ERR_INVALID_DATA

	var requested_path: String = file_path.strip_edges()

	if requested_path.is_empty():
		return ERR_INVALID_PARAMETER

	var absolute_path: String = ProjectSettings.globalize_path(requested_path)
	var extension: String = absolute_path.get_extension().to_lower()

	if extension not in SCREENSHOT_EXTENSIONS:
		return ERR_INVALID_PARAMETER

	var directory_error: Error = NucleusFileUtils.ensure_directory(
		absolute_path.get_base_dir()
	)

	if directory_error != OK:
		return directory_error

	match extension:
		"png":
			return image.save_png(absolute_path)
		"jpg", "jpeg":
			return image.save_jpg(
				absolute_path,
				clampf(quality, 0.01, 1.0),
			)
		"webp":
			return image.save_webp(
				absolute_path,
				webp_lossy,
				clampf(quality, 0.0, 1.0),
			)
		_:
			return ERR_INVALID_PARAMETER


## Captures after the current frame is rendered and writes the screenshot.
static func capture_screenshot_to_file(
	viewport: Viewport,
	file_path: String,
	quality: float = 0.9,
	include_alpha: bool = false,
	webp_lossy: bool = false,
) -> Error:
	var image: Image = await capture_viewport_after_draw(
		viewport,
		include_alpha,
	)

	if image == null:
		return ERR_CANT_CREATE

	return save_screenshot_image(
		image,
		file_path,
		quality,
		webp_lossy,
	)


static func _sanitize_filename_part(value: String) -> String:
	var result: String = value.strip_edges()
	var invalid_characters := PackedStringArray([
		"<",
		">",
		":",
		"\"",
		"/",
		"\\",
		"|",
		"?",
		"*",
	])

	for character: String in invalid_characters:
		result = result.replace(
			character,
			"_",
		)

	return result


static func _next_available_path(file_path: String) -> String:
	var candidate: String = file_path

	if not FileAccess.file_exists(candidate):
		return candidate

	var base_path: String = file_path.get_basename()
	var extension: String = file_path.get_extension()
	var index: int = 1

	while FileAccess.file_exists(candidate):
		candidate = (
			"%s_%03d.%s"
			% [
				base_path,
				index,
				extension,
			]
		)
		index += 1

	return candidate
