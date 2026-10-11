extends SceneTree
## godot --headless --path . --script res://examples/hex_grid_2d/hex_grid_2d_smoke.gd

const SUITE: Script = preload("res://tests/headless/hex_grid_2d_test.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result: Dictionary = SUITE.new().run()
	var failures: PackedStringArray = result.get("failures", PackedStringArray())
	for message: String in failures:
		push_error("[HexGrid2D] " + message)
	if failures.is_empty():
		print("[HexGrid2D] PASS: %d checks" % int(result.get("checks", 0)))
	quit(0 if failures.is_empty() else 1)
