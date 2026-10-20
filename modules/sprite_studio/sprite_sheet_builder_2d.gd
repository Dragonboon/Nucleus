class_name NucleusSpriteSheetBuilder2D
extends RefCounted
## Native Godot sprite/animation resources; profile is the clipping source of truth.


static func build_frames(profile: NucleusSpriteSheetProfile2D) -> SpriteFrames:
	if profile == null or not profile.validate().is_empty():
		return null
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	for clip: NucleusSpriteClip2D in profile.clips:
		_write_clip(frames, _clip_frames(profile, clip), clip.animation_name)
	return frames


static func build_library(profile: NucleusSpriteSheetProfile2D) -> AnimationLibrary:
	if profile == null or not profile.validate().is_empty():
		return null
	var library := AnimationLibrary.new()
	for clip: NucleusSpriteClip2D in profile.clips:
		library.add_animation(clip.animation_name, _clip_animation(clip))
	return library


static func build_scene(
	profile: NucleusSpriteSheetProfile2D,
	with_animation_player: bool = false,
	external_frames: SpriteFrames = null,
	external_library: AnimationLibrary = null,
) -> Node2D:
	if profile == null or not profile.validate().is_empty():
		return null
	var frames := external_frames if external_frames != null else build_frames(profile)
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
	var library := (
		external_library if external_library != null else build_library(profile)
	)
	if library == null:
		root.free()
		return null
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	player.root_node = NodePath("..")
	player.add_animation_library(&"", library)
	return root


static func merge_frames(
	profile: NucleusSpriteSheetProfile2D,
	existing: SpriteFrames,
	last_managed: Dictionary,
) -> Dictionary:
	## Three-way guard: manually changed clips are never silently replaced.
	var expected := build_frames(profile)
	if expected == null:
		return {"error": ERR_INVALID_DATA}
	var output := (
		existing.duplicate(true) as SpriteFrames if existing != null else expected
	)
	var managed: Dictionary = last_managed.duplicate()
	var conflicts: Array[String] = []
	var updated := 0
	if existing == null:
		for name: StringName in output.get_animation_names():
			managed[String(name)] = frames_signature(output, name)
			updated += 1
		return {
			"error": OK, "resource": output, "managed": managed,
			"updated": updated, "conflicts": conflicts,
		}
	for name: StringName in expected.get_animation_names():
		var key := String(name)
		if output.has_animation(name):
			if not managed.has(key) or frames_signature(output, name) != str(managed[key]):
				conflicts.append(key)
				continue
		_write_clip(output, expected, name)
		managed[key] = frames_signature(output, name)
		updated += 1
	for old_key: Variant in last_managed.keys():
		var key := str(old_key)
		var name := StringName(key)
		if expected.has_animation(name):
			continue
		if output.has_animation(name):
			if frames_signature(output, name) != str(last_managed[old_key]):
				conflicts.append(key)
				continue
			output.remove_animation(name)
		managed.erase(key)
	return {
		"error": OK, "resource": output, "managed": managed,
		"updated": updated, "conflicts": conflicts,
	}


static func merge_library(
	profile: NucleusSpriteSheetProfile2D,
	existing: AnimationLibrary,
	last_managed: Dictionary,
) -> Dictionary:
	var expected := build_library(profile)
	if expected == null:
		return {"error": ERR_INVALID_DATA}
	var output := (
		existing.duplicate(true) as AnimationLibrary if existing != null else expected
	)
	var managed: Dictionary = last_managed.duplicate()
	var conflicts: Array[String] = []
	var updated := 0
	if existing == null:
		for name: StringName in output.get_animation_list():
			managed[String(name)] = animation_signature(output.get_animation(name))
			updated += 1
		return {
			"error": OK, "resource": output, "managed": managed,
			"updated": updated, "conflicts": conflicts,
		}
	for name: StringName in expected.get_animation_list():
		var key := String(name)
		if output.has_animation(name):
			var current := output.get_animation(name)
			if not managed.has(key) or animation_signature(current) != str(managed[key]):
				conflicts.append(key)
				continue
			output.remove_animation(name)
		output.add_animation(name, expected.get_animation(name))
		managed[key] = animation_signature(output.get_animation(name))
		updated += 1
	for old_key: Variant in last_managed.keys():
		var key := str(old_key)
		var name := StringName(key)
		if expected.has_animation(name):
			continue
		if output.has_animation(name):
			if animation_signature(output.get_animation(name)) != str(last_managed[old_key]):
				conflicts.append(key)
				continue
			output.remove_animation(name)
		managed.erase(key)
	return {
		"error": OK, "resource": output, "managed": managed,
		"updated": updated, "conflicts": conflicts,
	}


static func frames_signature(frames: SpriteFrames, name: StringName) -> String:
	if frames == null or not frames.has_animation(name):
		return ""
	var values := [
		str(frames.get_animation_speed(name)),
		str(frames.get_animation_loop(name)),
		str(frames.get_frame_count(name)),
	]
	for index in range(frames.get_frame_count(name)):
		var texture := frames.get_frame_texture(name, index)
		var rect := Rect2()
		var atlas_path := ""
		if texture is AtlasTexture:
			var atlas := texture as AtlasTexture
			rect = atlas.region
			if atlas.atlas != null:
				atlas_path = atlas.atlas.resource_path
		values.append(str(rect))
		values.append(atlas_path)
		values.append(str(frames.get_frame_duration(name, index)))
	return "|".join(values).sha256_text()


static func animation_signature(animation: Animation) -> String:
	if animation == null:
		return ""
	var values := [str(animation.length), str(animation.loop_mode)]
	for track in range(animation.get_track_count()):
		values.append(str(animation.track_get_type(track)))
		values.append(str(animation.track_get_path(track)))
		values.append(str(animation.track_get_key_count(track)))
		for key in range(animation.track_get_key_count(track)):
			values.append(str(animation.track_get_key_time(track, key)))
			values.append(str(animation.track_get_key_value(track, key)))
	return "|".join(values).sha256_text()


static func _clip_frames(
	profile: NucleusSpriteSheetProfile2D,
	clip: NucleusSpriteClip2D,
) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	frames.add_animation(clip.animation_name)
	frames.set_animation_speed(clip.animation_name, clip.fps)
	frames.set_animation_loop(clip.animation_name, clip.loop)
	for cell: Vector2i in clip.cells:
		var atlas := AtlasTexture.new()
		atlas.atlas = profile.texture
		atlas.region = Rect2(profile.frame_rect(cell))
		frames.add_frame(clip.animation_name, atlas)
	return frames


static func _write_clip(
	target: SpriteFrames,
	origin: SpriteFrames,
	name: StringName,
) -> void:
	if not target.has_animation(name):
		target.add_animation(name)
	else:
		target.clear(name)
	target.set_animation_speed(name, origin.get_animation_speed(name))
	target.set_animation_loop(name, origin.get_animation_loop(name))
	for index in range(origin.get_frame_count(name)):
		target.add_frame(
			name, origin.get_frame_texture(name, index),
			origin.get_frame_duration(name, index),
		)


static func _clip_animation(clip: NucleusSpriteClip2D) -> Animation:
	var animation := Animation.new()
	animation.resource_name = String(clip.animation_name)
	animation.length = float(clip.cells.size()) / clip.fps
	animation.loop_mode = Animation.LOOP_LINEAR if clip.loop else Animation.LOOP_NONE
	var clip_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(clip_track, NodePath("AnimatedSprite2D:animation"))
	animation.value_track_set_update_mode(clip_track, Animation.UPDATE_DISCRETE)
	animation.track_insert_key(clip_track, 0.0, String(clip.animation_name))
	var frame_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(frame_track, NodePath("AnimatedSprite2D:frame"))
	animation.value_track_set_update_mode(frame_track, Animation.UPDATE_DISCRETE)
	for index in range(clip.cells.size()):
		animation.track_insert_key(frame_track, float(index) / clip.fps, index)
	return animation


static func suggest_grids(texture: Texture2D) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	if texture == null:
		return candidates
	var size := Vector2i(texture.get_size())
	for dimension in [8, 16, 24, 32, 48, 64, 96, 128]:
		if size.x % dimension == 0 and size.y % dimension == 0:
			candidates.append(Vector2i(dimension, dimension))
	return candidates


static func create_row_clips(profile: NucleusSpriteSheetProfile2D, fps: float = 8.0) -> void:
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
