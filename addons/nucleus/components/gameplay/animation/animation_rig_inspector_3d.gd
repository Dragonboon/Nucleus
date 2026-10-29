class_name NucleusAnimationRigInspector3D
extends RefCounted
## Non-destructive inspection helpers for imported 3D character visual branches.


static func find_skeleton(root: Node) -> Skeleton3D:
	if root == null:
		return null

	if root is Skeleton3D:
		return root as Skeleton3D

	for node: Node in NucleusNodeUtils.descendants(root):
		if node is Skeleton3D:
			return node as Skeleton3D

	return null


static func find_animation_player(root: Node) -> AnimationPlayer:
	if root == null:
		return null

	if root is AnimationPlayer:
		return root as AnimationPlayer

	for node: Node in NucleusNodeUtils.descendants(root):
		if node is AnimationPlayer:
			return node as AnimationPlayer

	return null


static func count_skeletons(root: Node) -> int:
	return _count_type(root, &"Skeleton3D")


static func count_animation_players(root: Node) -> int:
	return _count_type(root, &"AnimationPlayer")


static func inspect(
	root: Node,
	profile: NucleusAnimationStarterProfile3D = null,
) -> Dictionary:
	var skeleton := find_skeleton(root)
	var player := find_animation_player(root)
	var warnings := PackedStringArray()
	var skeleton_count := count_skeletons(root)
	var player_count := count_animation_players(root)

	if skeleton == null:
		warnings.append("No Skeleton3D found below the visual root.")
	elif skeleton.get_bone_count() <= 0:
		warnings.append("Skeleton3D contains no bones.")

	if skeleton_count > 1:
		warnings.append(
			"Multiple Skeleton3D nodes found; assign the intended rig explicitly."
		)

	if player == null:
		warnings.append("No AnimationPlayer found below the visual root.")
	elif player.get_animation_list().is_empty():
		warnings.append("AnimationPlayer contains no animations.")

	if player_count > 1:
		warnings.append(
			"Multiple AnimationPlayer nodes found; assign the intended source explicitly."
		)

	if profile != null and player != null:
		warnings.append_array(
			profile.get_validation_errors(player)
		)

	return {
		"skeleton": skeleton,
		"animation_player": player,
		"skeleton_count": skeleton_count,
		"animation_player_count": player_count,
		"bone_count": skeleton.get_bone_count() if skeleton else 0,
		"animations": (
			player.get_animation_list()
			if player
			else PackedStringArray()
		),
		"warnings": warnings,
	}


static func _count_type(
	root: Node,
	type_name: StringName,
) -> int:
	if root == null:
		return 0

	var count := 0

	if root.is_class(type_name):
		count += 1

	for node: Node in NucleusNodeUtils.descendants(root):
		if node.is_class(type_name):
			count += 1

	return count
