extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	var root := Node2D.new()
	attach_test_node(root)
	var presenter := NucleusFloatingTextPresenter2D.new()
	presenter.profile = NucleusFloatingTextProfile2D.new()
	presenter.maximum_visible = 2
	root.add_child(presenter)
	presenter.position = Vector2(100, 200)
	var first := presenter.show_number(12.5, Vector2(20, 30), 1)
	expect_equal(first.text, "12.5", "Caller chooses decimal precision.")
	expect_equal(first.global_position, Vector2(20, 6), "World point ignores presenter translation.")
	presenter.show_text("Immune", Vector2.ZERO)
	presenter.show_number(-4, Vector2.ZERO)
	expect_equal(presenter.get_visible_count(), 2, "Local budget evicts oldest.")
	expect_false(first.visible, "Evicted item hides immediately before deferred free.")
	var other := NucleusFloatingTextPresenter2D.new()
	other.profile = presenter.profile
	root.add_child(other)
	var other_label := other.show_text("+XP", Vector2.ZERO)
	expect_equal(presenter.get_visible_count(), 2, "Independent presenter has independent budget.")
	other_label.free()
	expect_equal(other.get_visible_count(), 0, "External free releases capacity.")
	expect_true(presenter.show_number(NAN, Vector2.ZERO) == null, "Nonfinite number rejects.")
	expect_true(presenter.show_text("x", Vector2(INF, 0)) == null, "Nonfinite point rejects.")
	var invalid := NucleusFloatingTextProfile2D.new()
	invalid.duration = 0
	expect_true(presenter.show_text("x", Vector2.ZERO, invalid) == null, "Invalid style rejects.")
	expect_equal(presenter.get_visible_count(), 2, "Rejected request does not evict.")
	presenter.clear()
	expect_equal(presenter.get_visible_count(), 0, "Clear synchronously releases budget.")
	root.remove_child(presenter)
	expect_true(presenter.show_text("x", Vector2.ZERO) == null, "Detached presenter rejects.")
	root.add_child(presenter)
	expect_true(presenter.show_number(0, Vector2.ZERO) != null, "Generic presenter accepts zero.")
	free_test_node(root)
	return finish()
