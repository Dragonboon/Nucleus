extends "res://tests/headless/test_case.gd"

func run() -> Dictionary:
	_test_sequence_grouping()
	return finish()


func _test_sequence_grouping() -> void:
	# The grouping is exercised by the real-directory editor acceptance test.
	# A missing source must be harmless and must not generate fabricated actors.
	expect_equal(
		NucleusSpriteSequenceImporter2D.scan_directory("res://missing_sprite_studio"),
		[], "Missing input folder produces an empty plan.",
	)
