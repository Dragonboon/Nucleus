@tool
extends Node
## User-initiated GitHub main updates pinned to a successful native CI run.

signal status_changed(message: String)
signal checked(result: Dictionary)
signal prepared(result: Dictionary)
signal finished

const Inventory = preload("res://addons/nucleus/editor/management/addon_inventory.gd")
const Archive = preload("res://addons/nucleus/editor/management/addon_archive.gd")
const Manager = preload("res://addons/nucleus/editor/management/addon_manager.gd")
const API: String = "https://api.github.com/repos/Dragonboon/Nucleus"
const RAW: String = "https://raw.githubusercontent.com/Dragonboon/Nucleus/"

var target_commit: String = ""
var target_manifest: Dictionary = {}
var busy: bool = false
var _manifest_bytes: PackedByteArray = []
var _head: String = ""
var _request: HTTPRequest
var _generation: int = 0
var _archive_path: String = ""


func check_main() -> void:
	if busy:
		return
	cancel()
	target_commit = ""
	target_manifest = {}
	_manifest_bytes = []
	busy = true
	_fetch(API + "/git/ref/heads/main", "head")


func download() -> void:
	if busy or target_commit.is_empty() or target_manifest.is_empty():
		return
	busy = true
	_archive_path = Manager.WORK + "downloads/" + target_commit + ".zip"
	if DirAccess.make_dir_recursive_absolute(Manager.global(_archive_path.get_base_dir())) != OK:
		_fail("Cannot create download cache.")
		return
	_fetch("https://codeload.github.com/Dragonboon/Nucleus/zip/" + target_commit, "archive")


func cancel() -> void:
	_generation += 1
	if is_instance_valid(_request):
		_request.cancel_request()
		_request.queue_free()
	_request = null
	busy = false
	finished.emit()


func _exit_tree() -> void:
	cancel()


func _fetch(url: String, kind: String) -> void:
	_request = HTTPRequest.new()
	_request.timeout = 30.0
	_request.max_redirects = 3
	_request.body_size_limit = Inventory.MAX_TOTAL_BYTES if kind == "archive" else 2 * 1024 * 1024
	if kind == "archive":
		_request.download_file = _archive_path
	add_child(_request)
	_request.request_completed.connect(_completed.bind(kind, _generation), CONNECT_ONE_SHOT)
	status_changed.emit("Downloading verified main source..." if kind == "archive" else (
		"Checking stable main: " + kind + "..."))
	var error: Error = _request.request(url, PackedStringArray([
		"User-Agent: Nucleus-Godot-Editor", "Accept: application/vnd.github+json",
	]))
	if error != OK:
		_fail("Cannot start request: " + error_string(error))


func _completed(
	result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray,
	kind: String, generation: int
) -> void:
	if generation != _generation:
		return
	if is_instance_valid(_request):
		_request.queue_free()
	_request = null
	if kind == "inventory" and code == 404:
		_fail("Stable main does not yet contain the managed addon. Update main and wait for its CI.")
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("GitHub request failed (%s / HTTP %s). Retry or cancel; installed files are unchanged."
			% [result, code])
		return
	if kind == "archive":
		var staging: Dictionary = Archive.prepare(_archive_path, _manifest_bytes, target_commit)
		busy = false
		prepared.emit(staging)
		finished.emit()
		return
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("Invalid GitHub response.")
		return
	_process_response(kind, parsed, bytes)


func _process_response(kind: String, parsed: Dictionary, bytes: PackedByteArray) -> void:
	match kind:
		"head":
			_head = str(parsed.get("object", {}).get("sha", ""))
			if not Archive.valid_commit(_head):
				_fail("Invalid main commit identity.")
				return
			_fetch(API + "/actions/workflows/nucleus-ci.yml/runs?branch=main"
				+ "&event=push&status=success&per_page=20", "ci")
		"ci":
			var runs: Variant = parsed.get("workflow_runs")
			if not runs is Array:
				_fail("No successful Nucleus CI history on main.")
				return
			for run: Variant in runs:
				if (run is Dictionary and run.get("head_branch") == "main"
						and run.get("conclusion") == "success" and run.get("event") == "push"):
					target_commit = str(run.get("head_sha", ""))
					break
			if not Archive.valid_commit(target_commit):
				_fail("No successful main commit is available.")
				return
			_fetch(API + "/compare/" + target_commit + "..." + _head, "ancestry")
		"ancestry":
			if parsed.get("status") not in ["ahead", "identical"]:
				_fail("The successful CI commit is no longer in main history.")
				return
			_fetch(RAW + target_commit + "/addons/nucleus/" + Inventory.MANIFEST, "inventory")
		"inventory":
			var error: String = Inventory.validate(parsed)
			if not error.is_empty():
				_fail(error + " Main must contain the managed-addon version before updating.")
				return
			if str(Engine.get_version_info().major) + "." + str(
					Engine.get_version_info().minor) != parsed.godot:
				_fail("This update requires Godot " + str(parsed.godot))
				return
			target_manifest = parsed
			_manifest_bytes = bytes
			busy = false
			checked.emit({"commit": target_commit, "manifest": parsed})
			finished.emit()


func _fail(message: String) -> void:
	_generation += 1
	if is_instance_valid(_request):
		_request.cancel_request()
		_request.queue_free()
	_request = null
	busy = false
	status_changed.emit(message)
	checked.emit({"error": message})
	finished.emit()
