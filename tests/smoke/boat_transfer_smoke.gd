extends Node
## Runs the actual lab through native physics frames, with a bounded exit.
func _ready() -> void:
	var lab: Node3D = preload(
		"res://examples/validation/boat_transfer/boat_transfer_lab.tscn"
	).instantiate()
	add_child(lab)
	lab.completed.connect(func(ok: bool) -> void:
		if ok:
			print("BOAT_TRANSFER_SMOKE: PASS")
		else:
			push_error("BOAT_TRANSFER_SMOKE: FAIL")
		get_tree().quit(0 if ok else 1)
	)
