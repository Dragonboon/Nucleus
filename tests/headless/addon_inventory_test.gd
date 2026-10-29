extends "res://tests/headless/test_case.gd"

const Inventory = preload("res://addons/nucleus/editor/management/addon_inventory.gd")
const Archive = preload("res://addons/nucleus/editor/management/addon_archive.gd")


func run() -> Dictionary:
	var manifest: Dictionary = Inventory.read_manifest()
	expect_equal(Inventory.validate(manifest), "", "Shipped inventory is valid.")
	for profile: String in ["2d", "3d"]:
		expect_true(manifest.profiles[profile].size() < manifest.profiles.full.size(),
			"Dimensional profiles physically remove optional files.")
		for path: String in manifest.profiles[profile]:
			for dependency: String in manifest.files[path].dependencies:
				expect_true(dependency in manifest.profiles[profile], "Dependencies stay present.")
	for unsafe: String in ["../escape.gd", "/absolute", "a/../b", "a\\b", "a:b", "a//b"]:
		expect_false(Inventory.safe_path(unsafe), "Unsafe path rejected.")
	var broken: Dictionary = manifest.duplicate(true)
	broken.profiles["2d"].erase("plugin.gd")
	expect_false(Inventory.validate(broken).is_empty(), "Profiles cannot remove editor entry.")
	expect_false(Archive.valid_commit("main"), "Mutable refs cannot identify updates.")
	expect_false(Archive.central_directory(PackedByteArray([1, 2, 3])).is_empty(),
		"Invalid archives return an error.")
	return finish()
