extends SceneTree
## Run with: godot --headless --path . --script res://examples/placement/placement_lab_smoke.gd
## Checks composition and lifetime, not render appearance or every physics contact.

const LAB_PATH := "res://examples/placement/placement_lab.tscn"
const ASSET_PATHS: Array[String] = [
	"res://examples/placement/assets/house.tscn",
	"res://examples/placement/assets/fence.tscn",
	"res://examples/placement/assets/pillar.tscn",
	"res://examples/placement/assets/platform.tscn",
	"res://examples/placement/assets/crate.tscn",
]

var _checks: int = 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for asset_path: String in ASSET_PATHS:
		var resource: Resource = load(asset_path)
		_check(resource is PackedScene, "Scene load: " + asset_path)
		if not resource is PackedScene:
			continue
		var root_node: Node = (resource as PackedScene).instantiate()
		var component := NucleusPlaceable3D.find_in(root_node)
		_check(component != null, "Placeable component: " + asset_path)
		if component != null:
			_check(component.profile != null, "Authored placement profile: " + asset_path)
			if component.profile != null:
				_check(component.profile.validate().is_empty(), "Valid placement profile: " + asset_path)
			_check(not NucleusPlaceable3D.collision_rids(root_node).is_empty(),
				"Native collider: " + asset_path)
		root_node.free()

	var resource: Resource = load(LAB_PATH)
	_check(resource is PackedScene, "Placement lab scene loads")
	if not resource is PackedScene:
		_finish()
		return
	var lab := (resource as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await physics_frame
	var world := lab.get_node_or_null("World") as Node3D
	var session := lab.get_node_or_null("RuntimePlacementSession") as NucleusPlacementSession3D
	_check(world != null, "Lab owns one World node")
	_check(session != null, "Lab composes NucleusPlacementSession3D")
	if world != null and session != null:
		_check(session.world_parent == world, "Session owns no world; explicit reference is wired")
		var original_count: int = world.get_child_count()
		_check(session.begin_new(load(ASSET_PATHS[0]) as PackedScene) == OK,
			"PackedScene starts a preview")
		_check(world.get_child_count() == original_count + 1,
			"Preview creates one world instance")
		session.cancel()
		_check(world.get_child_count() == original_count,
			"Cancelled preview leaves no placeable")
		var placed := load(ASSET_PATHS[4]).instantiate() as Node3D
		world.add_child(placed)
		placed.global_position = Vector3(1.0, 0.03, 2.0)
		var original: Transform3D = placed.global_transform
		_check(session.begin_edit(NucleusPlaceable3D.find_in(placed)) == OK,
			"Existing piece can enter edit mode")
		placed.global_position += Vector3(4.0, 0.0, 0.0)
		session.cancel()
		_check(placed.global_transform.is_equal_approx(original),
			"Cancelling edit restores original transform")
		placed.free()

	var fence_profile := load(
		"res://examples/placement/profiles/fence_profile.tres"
	) as NucleusPlacementProfile3D
	_check(fence_profile != null and fence_profile.allow_chains,
		"Fence explicitly supports chains")
	_check(fence_profile != null and fence_profile.chain_max_count == 20,
		"Lab fence maximum is authored per asset and editable in Inspector")
	_check(fence_profile != null and not fence_profile.resolve_snap(true)["enabled"],
		"Fence opts out of global snap to preserve smooth curved chains")
	var crate_profile := load(
		"res://examples/placement/profiles/crate_profile.tres"
	) as NucleusPlacementProfile3D
	_check(crate_profile != null and crate_profile.resolve_snap(false)["enabled"],
		"Crates explicitly snap on their own grid")
	var layout: Array[Vector3] = NucleusPlacementChain3D.points(
		Vector3.ZERO, Vector3(0, 0, -4.1), 2.0, 20,
	)
	_check(layout.size() == 3, "Four-metre chain lays out three independent segments")
	var bend := NucleusPlacementChain3D.path_layout(
		[Vector3.ZERO, Vector3(0, 0, -4), Vector3(4, 0, -4)], 2.0, 20,
	)
	_check(bend.size() >= 4, "Curved chain samples multiple independently editable segments")
	_check(session != null and session.max_checks_per_tick == 3,
		"Live preview enforces a per-frame validation budget")
	_check(session != null and not session.snap_enabled_by_default,
		"Snap is opt-in for inheriting placeables")
	_check(session != null and session.force_free_placement,
		"The lab starts in genuinely free placement mode")
	if session != null and crate_profile != null:
		_check(not session.get_snap_settings(crate_profile)["enabled"],
			"Lab free mode bypasses forced crate snapping")
	var canvas := lab.get_node_or_null("Interfaz del laboratorio")
	_check(canvas != null, "Interactive lab owns one UI canvas")
	_check(canvas != null and canvas.find_child("SnapGlobal", true, false) != null,
		"Lab exposes its session snap toggle")
	_check(canvas != null and canvas.find_child("SnapStep", true, false) != null,
		"Lab exposes a choice of grid cell sizes")
	if world != null and session != null and crate_profile != null and fence_profile != null:
		var grid := world.get_node_or_null(
			"Cuadricula visual sin colision"
		) as MeshInstance3D
		_check(grid != null and not grid.visible,
			"The visual grid is hidden in free mode")
		lab.call("_toggle_default_snap")
		_check(session.snap_enabled_by_default and not session.force_free_placement,
			"G enables the authored snapping rules")
		_check(session.get_snap_settings(crate_profile)["enabled"],
			"G enables the crate's authored 1 m snap")
		_check(not session.get_snap_settings(fence_profile)["enabled"],
			"Fences still opt out of global snap")
		_check(grid != null and grid.visible,
			"Grid visualization only appears in snap mode")
		lab.call("_toggle_default_snap")
		_check(not session.snap_enabled_by_default and session.force_free_placement,
			"G returns to truly free mode")
		_check(not session.get_snap_settings(crate_profile)["enabled"],
			"Free mode bypasses asset snapping again")
	var platform_profile := load(
		"res://examples/placement/profiles/platform_profile.tres"
	) as NucleusPlacementProfile3D
	var pillar_profile := load(
		"res://examples/placement/profiles/pillar_profile.tres"
	) as NucleusPlacementProfile3D
	_check(platform_profile != null and pillar_profile != null
		and pillar_profile.kind in platform_profile.accepts_on_top_kinds
		and platform_profile.kind in pillar_profile.supported_by_kinds,
		"Pillar/platform support is explicitly mutual")

	lab.free()
	_finish()


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		push_error("FAILED: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("Placement Lab smoke PASS (%d checks)" % _checks)
	else:
		print("Placement Lab smoke FAIL: %s" % "; ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
