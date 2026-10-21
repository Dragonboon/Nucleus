class_name NucleusSpriteSequencePipeline2D
extends RefCounted
## Keeps generated resources external; never edits scenes on reimport.


static func build_library(profile: NucleusSpriteSequenceProfile2D) -> AnimationLibrary:
	if profile == null or not profile.validate().is_empty():
		return null
	var library := AnimationLibrary.new()
	for clip: NucleusSpriteSequenceClip2D in profile.clips:
		var animation := Animation.new()
		animation.length = float(clip.frame_paths.size()) / clip.fps
		animation.loop_mode = (
			Animation.LOOP_LINEAR if clip.loop else Animation.LOOP_NONE
		)
		var property_track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(property_track, NodePath("AnimatedSprite2D:animation"))
		animation.value_track_set_update_mode(property_track, Animation.UPDATE_DISCRETE)
		animation.track_insert_key(property_track, 0.0, String(clip.animation_name))
		var frame_track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(frame_track, NodePath("AnimatedSprite2D:frame"))
		animation.value_track_set_update_mode(frame_track, Animation.UPDATE_DISCRETE)
		for index in range(clip.frame_paths.size()):
			animation.track_insert_key(frame_track, float(index) / clip.fps, index)
		library.add_animation(clip.animation_name, animation)
	return library


static func create_scene(
	frames: SpriteFrames,
	library: AnimationLibrary,
) -> Node2D:
	if frames == null or library == null:
		return null
	var root := Node2D.new()
	root.name = "SpriteVisual"
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = frames
	root.add_child(sprite)
	sprite.owner = root
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	player.root_node = NodePath("..")
	player.add_animation_library(&"", library)
	return root


static func merge_frames(
	expected: SpriteFrames,
	existing: SpriteFrames,
	last_managed: Dictionary,
) -> Dictionary:
	var managed := last_managed.duplicate()
	var conflicts: Array[String] = []
	if expected == null:
		return {"error": ERR_INVALID_DATA}
	var output: SpriteFrames = (
		existing.duplicate(true) as SpriteFrames if existing != null else expected
	)
	if existing == null:
		for animation_name: StringName in expected.get_animation_names():
			managed[String(animation_name)] = (
				NucleusSpriteSheetBuilder2D.frames_signature(expected, animation_name)
			)
		return {"error": OK, "resource": output, "managed": managed, "conflicts": conflicts}
	for animation_name: StringName in expected.get_animation_names():
		var key := String(animation_name)
		if output.has_animation(animation_name):
			if not managed.has(key) or (
				NucleusSpriteSheetBuilder2D.frames_signature(output, animation_name)
				!= str(managed[key])
			):
				conflicts.append(key)
				continue
		if not output.has_animation(animation_name):
			output.add_animation(animation_name)
		else:
			output.clear(animation_name)
		output.set_animation_speed(animation_name, expected.get_animation_speed(animation_name))
		output.set_animation_loop(animation_name, expected.get_animation_loop(animation_name))
		for index in range(expected.get_frame_count(animation_name)):
			output.add_frame(
				animation_name,
				expected.get_frame_texture(animation_name, index),
				expected.get_frame_duration(animation_name, index),
			)
		managed[key] = NucleusSpriteSheetBuilder2D.frames_signature(output, animation_name)
	for old_key: Variant in last_managed.keys():
		var key := str(old_key)
		var animation_name := StringName(key)
		if expected.has_animation(animation_name):
			continue
		if output.has_animation(animation_name):
			if (
				NucleusSpriteSheetBuilder2D.frames_signature(output, animation_name)
				!= str(last_managed[old_key])
			):
				conflicts.append(key)
				continue
			output.remove_animation(animation_name)
		managed.erase(key)
	return {"error": OK, "resource": output, "managed": managed, "conflicts": conflicts}


static func merge_library(
	expected: AnimationLibrary,
	existing: AnimationLibrary,
	last_managed: Dictionary,
) -> Dictionary:
	if expected == null:
		return {"error": ERR_INVALID_DATA}
	var output: AnimationLibrary = (
		existing.duplicate(true) as AnimationLibrary if existing != null else expected
	)
	var managed := last_managed.duplicate()
	var conflicts: Array[String] = []
	if existing == null:
		for animation_name: StringName in output.get_animation_list():
			managed[String(animation_name)] = NucleusSpriteSheetBuilder2D.animation_signature(
				output.get_animation(animation_name)
			)
		return {"error": OK, "resource": output, "managed": managed, "conflicts": conflicts}
	for animation_name: StringName in expected.get_animation_list():
		var key := String(animation_name)
		if output.has_animation(animation_name):
			if not managed.has(key) or (
				NucleusSpriteSheetBuilder2D.animation_signature(output.get_animation(animation_name))
				!= str(managed[key])
			):
				conflicts.append(key)
				continue
			output.remove_animation(animation_name)
		output.add_animation(animation_name, expected.get_animation(animation_name))
		managed[key] = NucleusSpriteSheetBuilder2D.animation_signature(
			output.get_animation(animation_name)
		)
	for old_key: Variant in last_managed.keys():
		var key := str(old_key)
		var animation_name := StringName(key)
		if expected.has_animation(animation_name):
			continue
		if output.has_animation(animation_name):
			if NucleusSpriteSheetBuilder2D.animation_signature(
				output.get_animation(animation_name)
			) != str(last_managed[old_key]):
				conflicts.append(key)
				continue
			output.remove_animation(animation_name)
		managed.erase(key)
	return {"error": OK, "resource": output, "managed": managed, "conflicts": conflicts}
