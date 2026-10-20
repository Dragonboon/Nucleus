class_name NucleusSpriteSheetBuilder2D
extends RefCounted
## Converts explicit clip metadata into native Godot resources.


static func build_frames(profile: NucleusSpriteSheetProfile2D) -> SpriteFrames:
	if profile == null or not profile.validate().is_empty():
		return null
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	for clip: NucleusSpriteClip2D in profile.clips:
		frames.add_animation(clip.animation_name)
		frames.set_animation_speed(clip.animation_name, clip.fps)
		frames.set_animation_loop(clip.animation_name, clip.loop)
		for cell: Vector2i in clip.cells:
			var atlas := AtlasTexture.new()
			atlas.atlas = profile.texture
			atlas.region = Rect2(profile.frame_rect(cell))
			frames.add_frame(clip.animation_name, atlas)
	return frames


static func build_scene(
	profile: NucleusSpriteSheetProfile2D,
	with_animation_player: bool = false,
) -> Node2D:
	var frames := build_frames(profile)
	if frames == null:
		return null
	var root := Node2D.new()
	root.name = "SpriteVisual"
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = frames
	root.add_child(sprite)
	sprite.owner = root
	if not with_animation_player:
		return root
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	var library := AnimationLibrary.new()
	player.add_animation_library(&"", library)
	player.root_node = NodePath("..")
	for clip: NucleusSpriteClip2D in profile.clips:
		var animation := Animation.new()
		animation.resource_name = String(clip.animation_name)
		animation.length = float(clip.cells.size()) / clip.fps
		animation.loop_mode = (
			Animation.LOOP_LINEAR if clip.loop else Animation.LOOP_NONE
		)
		var clip_track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(clip_track, NodePath("AnimatedSprite2D:animation"))
		animation.value_track_set_update_mode(clip_track, Animation.UPDATE_DISCRETE)
		animation.track_insert_key(clip_track, 0.0, String(clip.animation_name))
		var frame_track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(frame_track, NodePath("AnimatedSprite2D:frame"))
		animation.value_track_set_update_mode(frame_track, Animation.UPDATE_DISCRETE)
		for index in range(clip.cells.size()):
			animation.track_insert_key(frame_track, float(index) / clip.fps, index)
		library.add_animation(clip.animation_name, animation)
	return root


static func suggest_grids(texture: Texture2D) -> Array[Vector2i]:
	## Shape-based candidates only; cannot infer semantic names from pixels.
	var candidates: Array[Vector2i] = []
	if texture == null:
		return candidates
	var size := Vector2i(texture.get_size())
	for dimension in [8, 16, 24, 32, 48, 64, 96, 128]:
		if size.x % dimension == 0 and size.y % dimension == 0:
			candidates.append(Vector2i(dimension, dimension))
	return candidates


static func create_row_clips(profile: NucleusSpriteSheetProfile2D, fps: float = 8.0) -> void:
	## Explicit user opt-in. Never overwrites an authored clip.
	if profile == null or not profile.clips.is_empty() or fps <= 0.0:
		return
	var grid := profile.grid_size()
	for y in range(grid.y):
		var clip := NucleusSpriteClip2D.new()
		clip.animation_name = StringName("row_%02d" % y)
		clip.fps = fps
		clip.cells.clear()
		for x in range(grid.x):
			clip.cells.append(Vector2i(x, y))
		profile.clips.append(clip)
