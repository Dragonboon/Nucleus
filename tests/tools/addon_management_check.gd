extends SceneTree
## Runs only inside a disposable host copied by check_addon_management.py.

const Inventory = preload("res://addons/nucleus/editor/management/addon_inventory.gd")
const Manager = preload("res://addons/nucleus/editor/management/addon_manager.gd")
const Archive = preload("res://addons/nucleus/editor/management/addon_archive.gd")

var _failures: PackedStringArray = []
var _manager: RefCounted = Manager.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var phase: String = OS.get_cmdline_user_args()[0]
	if phase == "profiles":
		_profiles()
	elif phase == "full":
		_check(_manager.apply_profile("full").error.is_empty(), "Restore full profile.")
	elif phase == "updates":
		_updates()
	for failure: String in _failures:
		push_error(failure)
	print("Nucleus addon management %s: %s" % [phase,
		"PASS" if _failures.is_empty() else "FAIL"])
	quit(0 if _failures.is_empty() else 1)


func _profiles() -> void:
	var full: Dictionary = Inventory.read_manifest()
	var plan: Dictionary = _manager.preview("2d")
	_check(plan.error.is_empty() and plan.remove.size() > 100, "Real 2D pruning preview.")
	var dependency: String = "components/gameplay/movement/character_motor_" + "3d.gd"
	var consumer := FileAccess.open("res://consumer.gd", FileAccess.WRITE)
	consumer.store_string("extends Node\nconst Motor = preload(\"" + Inventory.ROOT
		+ dependency + "\")\n")
	consumer.close()
	_check(not _manager.preview("2d").error.is_empty(), "Host path blocks removal.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://consumer.gd"))
	consumer = FileAccess.open("res://consumer.gd", FileAccess.WRITE)
	consumer.store_string("extends Node\nvar motor: " + "NucleusCharacterMotor" + "3D\n")
	consumer.close()
	_check(not _manager.preview("2d").error.is_empty(), "Host class reference blocks removal.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://consumer.gd"))
	var binary := Resource.new()
	binary.set_meta("component_script", load(Inventory.ROOT + dependency))
	ResourceSaver.save(binary, "res://consumer.res")
	_check(not _manager.preview("2d").error.is_empty(),
		"Native binary-resource dependency blocks removal.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://consumer.res"))
	var outcome: Dictionary = _manager.apply_profile("2d")
	_check(outcome.error.is_empty(), "Apply 2D: " + outcome.error)
	_check(not FileAccess.file_exists(Inventory.ROOT + dependency), "3D source physically removed.")
	_check(Inventory.verify(Inventory.ROOT, full, "2d").is_empty(), "Retained 2D graph verifies.")
	DirAccess.rename_absolute(Manager.global(Manager.STATE), Manager.global(Manager.STATE + ".saved"))
	_check(_manager.state().profile == "2d", "Trimmed addon carries its profile to another checkout.")
	_check(_manager.preview("2d").error.is_empty(),
		"Portable profile needs no local cache to preview.")
	DirAccess.rename_absolute(Manager.global(Manager.STATE + ".saved"), Manager.global(Manager.STATE))
	_check(FileAccess.file_exists(outcome.get("backup", "") + dependency), "Backup preserves source.")
	outcome = _manager.apply_profile("3d")
	_check(outcome.error.is_empty(), "Switch 2D to 3D from full cache: " + outcome.error)
	_check(FileAccess.file_exists(Inventory.ROOT + dependency), "3D source restored.")
	_check(Inventory.verify(Inventory.ROOT, full, "3d").is_empty(), "Retained 3D graph verifies.")
	outcome = _manager.restore_backup()
	_check(outcome.error.is_empty() and _manager.state().profile == "2d",
		"Restore previous 2D profile.")
	outcome = _manager.apply_profile("full")
	_check(outcome.error.is_empty(), "Restore full profile.")
	_check(Inventory.verify(Inventory.ROOT, full).is_empty(), "Full inventory restored byte-for-byte.")
	var edited := FileAccess.open(Inventory.ROOT + dependency, FileAccess.READ_WRITE)
	edited.seek_end()
	edited.store_string("\n# local edit\n")
	edited.close()
	_check(not _manager.preview("2d").error.is_empty(),
		"Local modifications block destructive change.")
	var source: String = _manager.state().source
	DirAccess.copy_absolute(Manager.global(source + dependency),
		Manager.global(Inventory.ROOT + dependency))


func _updates() -> void:
	var manifest_bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://incoming_manifest.json")
	var commit: String = "1".repeat(40)
	var rejected_first: Dictionary = Archive.prepare("res://corrupt.zip", manifest_bytes, commit)
	_check(not rejected_first.error.is_empty(), "Corrupt preparation leaves no published cache.")
	var staged: Dictionary = Archive.prepare("res://incoming.zip", manifest_bytes, commit)
	_check(staged.error.is_empty(), "Incoming pinned inventory verifies: " + staged.error)
	if not staged.error.is_empty():
		return
	var before_version: String = FileAccess.get_file_as_string(Inventory.ROOT + "VERSION")
	DirAccess.make_dir_absolute(Manager.global(Manager.STATE + ".tmp"))
	var failed: Dictionary = _manager.install(staged.source, "2d", commit)
	_check(not failed.error.is_empty(), "Forced state-write failure rejects the transaction.")
	_check(FileAccess.get_file_as_string(Inventory.ROOT + "VERSION") == before_version,
		"Failed transaction restores the original active folder.")
	_check(_manager.state().profile == "full", "Failed transaction preserves previous state.")
	DirAccess.remove_absolute(Manager.global(Manager.STATE + ".tmp"))
	var outcome: Dictionary = _manager.install(staged.source, "2d", commit)
	_check(outcome.error.is_empty(), "Verified staged update applies: " + outcome.error)
	_check(_manager.state().profile == "2d", "Update preserves selected dimensional profile.")
	_check(FileAccess.get_file_as_string(Inventory.ROOT + "VERSION").strip_edges() == "0.39.1-test.1",
		"New version installed.")
	outcome = _manager.restore_backup()
	_check(outcome.error.is_empty(), "Update rollback restores previous version.")
	for invalid: String in ["traversal", "corrupt", "oversized", "missing", "symlink", "duplicate"]:
		var rejected: Dictionary = Archive.prepare("res://" + invalid + ".zip", manifest_bytes,
			invalid.sha256_text().substr(0, 40))
		_check(not rejected.error.is_empty(), "Invalid update rejected: " + invalid)
	_check(FileAccess.get_file_as_string("res://host_owned.txt") == "keep me",
		"Host content survives updates and rollbacks.")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
