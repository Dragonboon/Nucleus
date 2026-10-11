extends SceneTree
## Standalone smoke: godot --headless --path . --script res://examples/hex_grid/hex_grid_smoke.gd

const TEST_SCRIPT: Script = preload("res://tests/headless/hex_grid_3d_test.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var suite: RefCounted = TEST_SCRIPT.new()
	var result: Dictionary = suite.run()
	var failures: PackedStringArray = result.get("failures", PackedStringArray())
	if failures.is_empty():
		print("[HexGrid3D] PASS: %d checks" % int(result.get("checks", 0)))
		quit(0)
		return
	for message: String in failures:
		push_error("[HexGrid3D] " + message)
	push_error("[HexGrid3D] FAIL: %d errors" % failures.size())
	quit(1)
