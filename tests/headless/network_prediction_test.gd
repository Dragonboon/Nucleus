extends "res://tests/headless/test_case.gd"

func run() -> Dictionary:
	_test_buffer()
	_test_reconcile_2d()
	_test_reconcile_3d()
	return finish()

func _test_buffer() -> void:
	var buffer := NucleusNetworkInputBuffer.new()
	buffer.capacity = 2
	expect_true(buffer.push(1, {"dx": 1}, {"position": Vector2.ONE}), "First input admitted.")
	expect_true(buffer.push(2, {"dx": 1}, {"position": Vector2(2, 1)}), "Second input admitted.")
	expect_false(buffer.push(3, {}, {"position": Vector2.ZERO}), "Capacity enforced.")
	expect_false(buffer.push(2, {}, {"position": Vector2.ZERO}), "Duplicate input rejected.")
	var predicted := buffer.predicted_at(1)
	predicted["position"] = Vector2(100, 100)
	expect_equal(buffer.predicted_at(1)["position"], Vector2.ONE, "History copy isolated.")
	var replay: Array[Dictionary] = [{"position": Vector2(4, 1)}]
	expect_true(buffer.commit(1, replay), "Acknowledgment commits replay.")
	expect_equal(buffer.size(), 1, "Acknowledged command removed.")
	expect_false(buffer.commit(1, replay), "Stale acknowledgment rejected.")
	expect_equal(buffer.predicted_at(2)["position"], Vector2(4, 1), "Replay updates prediction.")
	buffer.reset()
	expect_equal(buffer.size(), 0, "Session reset clears history.")
	expect_true(buffer.push(1, {}, {"position": Vector2.ZERO}), "New session restarts numbering.")

func _test_reconcile_2d() -> void:
	var client := NucleusNetworkReconciler2D.new()
	expect_true(client.record(1, {"step": 1}, {"position": Vector2(1, 0)}), "2D record 1.")
	expect_true(client.record(2, {"step": 1}, {"position": Vector2(2, 0)}), "2D record 2.")
	var result := client.reconcile(
		1, {"position": Vector2(1.5, 0)}, _advance_2d
	)
	expect_equal(result["replayed"], 1, "One 2D command replays.")
	expect_equal(result["state"]["position"], Vector2(2.5, 0), "2D server correction applied.")
	expect_true(client.reconcile(1, {"position": Vector2.ZERO}, _advance_2d).is_empty(),
		"2D stale ACK rejected.")
	expect_false(client.record(3, {}, {"position": Vector2.INF}), "2D invalid position rejected.")

func _test_reconcile_3d() -> void:
	var client := NucleusNetworkReconciler3D.new()
	expect_true(client.record(1, {}, {"position": Vector3(1, 0, 0)}), "3D record 1.")
	expect_true(client.record(2, {}, {"position": Vector3(2, 0, 0)}), "3D record 2.")
	var result := client.reconcile(1, {"position": Vector3(1, 1, 0)}, _advance_3d)
	expect_equal(result["state"]["position"], Vector3(2, 1, 0), "3D authoritative replay.")
	expect_true(client.reconcile(1, {"position": Vector3.ZERO}, _advance_3d).is_empty(),
		"3D stale ACK rejected.")
	expect_false(client.record(3, {}, {"position": Vector3.INF}), "3D invalid position rejected.")

func _advance_2d(state: Dictionary, _command: Dictionary, _delta: float) -> Dictionary:
	return {"position": (state["position"] as Vector2) + Vector2.RIGHT}

func _advance_3d(state: Dictionary, _command: Dictionary, _delta: float) -> Dictionary:
	return {"position": (state["position"] as Vector3) + Vector3.RIGHT}
