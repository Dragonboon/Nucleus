extends SceneTree
## Run with: godot --headless --path . --script res://examples/placement/placement_lab_smoke.gd
## Checks composition and lifetime, not render appearance or every physics contact.

const LAB_PATH := "res://examples/placement/placement_lab.tscn"
const WORLD_DOCUMENT = preload("res://examples/placement/placement_world_document.gd")
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
	_check(session != null and session.max_group_count == WORLD_DOCUMENT.MAX_PIECES,
		"Select-all can enter one group edit beyond the previous 32-piece cap")
	_check(session != null and session.max_pairs_per_tick == 512,
		"Large group clearance has a per-frame bound")
	var repeat_button := lab.find_child("RepeatPlacement", true, false) as CheckButton
	_check(repeat_button != null and repeat_button.button_pressed,
		"Continuous single-asset placement is selectable and enabled by default")
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
	_check(canvas != null and canvas.find_child("WorldSlot", true, false) != null,
		"Lab exposes independent world save slots")
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

	_test_curve_mouse_input(lab, session)
	_test_authored_world_document(lab)
	_test_workflow_and_persistence(lab)
	lab.free()
	_finish()


## Exercise the lab's real mouse routing, not just Nucleus curve geometry.
## Green preview is provisional: a primary click starts the final recheck.
func _test_curve_mouse_input(
	lab: Node3D,
	session: NucleusPlacementSession3D,
) -> void:
	if session == null:
		return
	var camera := lab.get_node_or_null("LabCamera") as Camera3D
	if camera == null:
		_check(false, "Curve input test needs the lab camera")
		return
	var before: Dictionary = lab.call("_capture_document")
	var anchor_screen := camera.unproject_position(Vector3(-4.0, 0.0, 7.0))
	var bend_screen := camera.unproject_position(Vector3(0.0, 0.0, 7.0))
	var end_screen := camera.unproject_position(Vector3(4.0, 0.0, 7.0))
	_check(not (lab.call("_raycast", anchor_screen, 1) as Dictionary).is_empty(),
		"Curve anchor projects onto ground")
	_check(not (lab.call("_raycast", bend_screen, 1) as Dictionary).is_empty(),
		"Curve bend projects onto ground")
	_check(not (lab.call("_raycast", end_screen, 1) as Dictionary).is_empty(),
		"Curve endpoint projects onto ground")
	lab.call("_select_curve")
	lab.call("_world_click", anchor_screen)
	_check(session.mode == NucleusPlacementSession3D.Mode.PATH,
		"LMB chooses the initial path anchor")
	if session.mode != NucleusPlacementSession3D.Mode.PATH:
		lab.call("_cancel_operation")
		return
	var initial_controls := session.get_path_controls().size()
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = bend_screen
	lab.call("_unhandled_input", right)
	_check(session.get_path_controls().size() == initial_controls + 1,
		"RMB adds one curve bend without placing the chain")
	_check(not bool(lab.get("_orbiting")),
		"RMB during path placement does not orbit the camera")
	right.pressed = false
	lab.call("_unhandled_input", right)
	_check(session.get_path_controls().size() == initial_controls + 1,
		"RMB release does not insert another control point")
	var alt_right := InputEventMouseButton.new()
	alt_right.button_index = MOUSE_BUTTON_RIGHT
	alt_right.alt_pressed = true
	alt_right.pressed = true
	alt_right.position = bend_screen
	lab.call("_unhandled_input", alt_right)
	_check(bool(lab.get("_orbiting")),
		"Alt+RMB still orbits while editing a curve")
	alt_right.pressed = false
	lab.call("_unhandled_input", alt_right)
	_check(not bool(lab.get("_orbiting")),
		"Releasing Alt+RMB ends camera orbit")
	_check(session.get_path_controls().size() == initial_controls + 1,
		"Alt+RMB never adds a curve bend")
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	left.position = end_screen
	lab.call("_unhandled_input", left)
	_check(
		session.mode == NucleusPlacementSession3D.Mode.IDLE
		or bool(session.get("_confirm_pending")) or session.last_reason != &"",
		"LMB requests final verification instead of another curve control",
	)
	session.cancel()
	_check(lab.call("_restore_document", before) == OK,
		"Curve mouse input fixture restores the previous world")


func _test_authored_world_document(lab: Node3D) -> void:
	var catalog := {
		"house": load(ASSET_PATHS[0]),
		"fence": load(ASSET_PATHS[1]),
		"pillar": load(ASSET_PATHS[2]),
		"platform": load(ASSET_PATHS[3]),
		"crate": load(ASSET_PATHS[4]),
	}
	var original: Dictionary = lab.call("_capture_document")
	var transform := Transform3D(Basis.IDENTITY, Vector3(2.0, 0.03, 8.0))
	var piece := {
		"id": "p_17", "kind": "crate",
		"transform": WORLD_DOCUMENT.encode_transform(transform),
	}
	var document := {"schema_version": 1, "objects": [piece]}
	_check(WORLD_DOCUMENT.validate(document, catalog)["error"] == OK,
		"Versioned world document accepts a whitelisted placeable")
	var from_json: Variant = JSON.parse_string(JSON.stringify(document))
	_check(WORLD_DOCUMENT.validate(from_json, catalog)["error"] == OK,
		"JSON round-trip accepts the saved schema version and transforms")
	_check(lab.call("_restore_document", document) == OK,
		"A valid world restores its complete scene from a staged catalog")
	var after: Dictionary = lab.call("_capture_document")
	_check(after["objects"].size() == 1,
		"Restoration creates exactly one authored placeable")
	_check(after["objects"][0]["id"] == "p_17",
		"Restoration preserves the stable ID")
	_check(after["objects"][0]["transform"] == piece["transform"],
		"Restoration preserves every authored transform component")
	var malicious := document.duplicate(true)
	malicious["objects"][0]["kind"] = "res://scripts/evil.gd"
	_check(WORLD_DOCUMENT.validate(malicious, catalog)["error"] != OK,
		"Save documents cannot request arbitrary resource paths")
	_check(lab.call("_restore_document", malicious) != OK,
		"Invalid world restores fail before mutating live pieces")
	_check(lab.call("_capture_document") == after,
		"Rejected world cannot partially erase the previous scene")
	var repeated := {"schema_version": 1, "objects": [piece, piece.duplicate(true)]}
	_check(WORLD_DOCUMENT.validate(repeated, catalog)["error"] != OK,
		"World documents reject duplicate stable IDs")
	var oversized := document.duplicate(true)
	oversized["objects"][0]["transform"][0] = 20.0
	_check(WORLD_DOCUMENT.validate(oversized, catalog)["error"] != OK,
		"World documents reject arbitrary scale and non-rotation matrices")
	var bad_coordinate := document.duplicate(true)
	bad_coordinate["objects"][0]["transform"][9] = 40000.0
	_check(WORLD_DOCUMENT.validate(bad_coordinate, catalog)["error"] != OK,
		"Out-of-bounds objects are rejected")
	var bad_type := document.duplicate(true)
	bad_type["objects"][0]["transform"][0] = "1.0"
	_check(WORLD_DOCUMENT.validate(bad_type, catalog)["error"] != OK,
		"Numeric strings are not silently converted to float")
	_check(lab.call("_restore_document", original) == OK,
		"The previous world can be restored before a history test")
	var before := lab.call("_capture_document") as Dictionary
	_check(lab.call("_restore_document", document) == OK,
		"World can be recreated for reversible action testing")
	lab.call("_record_action", before, &"create_test_world")
	var history := lab.get("_history") as NucleusValidatedActionHistory
	_check(history.can_undo(), "World changes register one bounded history action")
	lab.call("_undo")
	_check(lab.call("_capture_document") == before,
		"Undo reconstructs the exact previous world")
	lab.call("_redo")
	_check(lab.call("_capture_document") == after,
		"Redo reconstructs the exact later world")
	_check(lab.call("_restore_document", original) == OK,
		"The smoke test clears the authored world before exiting")


func _test_workflow_and_persistence(lab: Node3D) -> void:
	var session := lab.get_node("RuntimePlacementSession") as NucleusPlacementSession3D
	lab.call("_select_asset", 4)
	_check(session.mode == NucleusPlacementSession3D.Mode.SINGLE,
		"Choosing a brush begins continuous placement")
	var chosen: PackedScene = lab.get("_brush_scene")
	session.cancel()
	lab.call("_resume_brush", chosen)
	_check(session.mode == NucleusPlacementSession3D.Mode.SINGLE,
		"Continuous brush creates the next preview without menu input")
	lab.call("_select_all")
	_check(session.mode == NucleusPlacementSession3D.Mode.IDLE,
		"Select All switches out of the continuous brush")

	var saved_before: Dictionary = lab.call("_capture_document")
	var piece: Dictionary = {
		"id": "p_501", "kind": "crate",
		"transform": WORLD_DOCUMENT.encode_transform(
			Transform3D(Basis.IDENTITY, Vector3(2, 0.03, 2)),
		),
	}
	_check(lab.call("_restore_document", {"schema_version": 1, "objects": [piece]}) == OK,
		"Duplication fixture creates a known approved piece")
	# Root path is not a save contract; use authored placed-list instead.
	var placed_list: Array = lab.get("_placed")
	if not placed_list.is_empty():
		var component := NucleusPlaceable3D.find_in(placed_list[0])
		lab.call("_set_selected", component)
		lab.call("_duplicate_selection")
		_check(session.mode == NucleusPlacementSession3D.Mode.DUPLICATE,
			"Ctrl+D opens a movable duplicate preview before committing a piece")
		_check((lab.call("_capture_document") as Dictionary)["objects"].size() == 1,
			"A duplicate preview is not recorded in persisted world data")
		lab.call("_cancel_operation")
		_check((lab.call("_capture_document") as Dictionary)["objects"].size() == 1,
			"Cancel leaves no duplicated world object behind")
	_check(lab.call("_restore_document", saved_before) == OK,
		"Workflow fixture restores the original world")

	if NucleusSave.is_initialized():
		var slot := "placement_lab_smoke_%d" % Time.get_ticks_usec()
		var world_data: Dictionary = lab.call("_capture_document")
		var stored := NucleusSave.save_manual(slot, {"world": world_data})
		_check(stored.succeeded(), "NucleusSave accepts the authored world payload")
		if stored.succeeded():
			var loaded := NucleusSave.load_manual(slot)
			_check(loaded.succeeded(), "NucleusSave returns an integrity-checked world")
			if loaded.succeeded():
				_check(loaded.document.payload.get("world") == world_data,
					"Persistence returns identical stable IDs and transforms")
		NucleusSave.delete_slot(slot)
	else:
		_check(false, "Placement Lab project must initialize NucleusSave")


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
