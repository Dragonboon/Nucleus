extends "res://tests/headless/test_case.gd"

const Inventory = preload("res://addons/nucleus/editor/management/addon_inventory.gd")

class FakeUpdater extends "res://addons/nucleus/editor/management/addon_updater.gd":
	var requests: Array[Dictionary] = []

	func _fetch(url: String, kind: String) -> void:
		requests.append({"url": url, "kind": kind})


func run() -> Dictionary:
	var updater := FakeUpdater.new()
	updater.check_main()
	expect_equal(updater.requests.back().kind, "head", "Resolve main before checking CI.")
	var commit: String = "1".repeat(40)
	updater._process_response("head", {"object": {"sha": commit}}, [])
	expect_equal(updater.requests.back().kind, "ci", "Require successful main CI.")
	updater._process_response("ci", {"workflow_runs": [{"head_branch": "main",
		"head_sha": commit, "conclusion": "success", "event": "push"}]}, [])
	expect_equal(updater.requests.back().kind, "ancestry", "Verify successful commit remains in main.")
	updater._process_response("ancestry", {"status": "identical"}, [])
	expect_true(updater.requests.back().url.contains(commit),
		"Inventory URL pins an immutable commit.")
	var manifest: Dictionary = Inventory.read_manifest()
	updater._process_response("inventory", manifest, JSON.stringify(manifest).to_utf8_buffer())
	expect_equal(updater.target_commit, commit, "Verified target recorded.")
	expect_false(updater.busy, "Completed check releases request ownership.")
	updater.download()
	expect_true(updater.requests.back().url.ends_with(commit),
		"Source ZIP uses the same pinned commit.")
	var generation: int = updater._generation
	updater.cancel()
	expect_false(updater.busy, "Cancellation releases busy state.")
	var previous: String = updater.target_commit
	updater._completed(HTTPRequest.RESULT_SUCCESS, 200, [], "{}".to_utf8_buffer(),
		"head", generation)
	expect_equal(updater.target_commit, previous, "Cancelled request cannot mutate target state.")
	updater.check_main()
	updater._process_response("ci", {"workflow_runs": []}, [])
	expect_false(updater.busy, "Missing successful CI fails cleanly.")
	expect_true(updater.target_commit.is_empty(), "No unverified target survives failure.")
	updater.free()
	return finish()
