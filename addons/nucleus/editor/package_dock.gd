@tool
extends VBoxContainer
## Read-only GitHub catalog + safe first-install foundation.
## No automatic overwrites or module removal in this prototype.

const Manifest = preload("res://addons/nucleus/editor/package_manifest.gd")
const Installer = preload("res://addons/nucleus/editor/package_installer.gd")
const CATALOG_URL := "https://raw.githubusercontent.com/Dragonboon/Nucleus/feat/modular-addon-package-manager/package_catalog.json"
const API_RELEASE_URL := "https://api.github.com/repos/Dragonboon/Nucleus/releases/latest"

var _http: HTTPRequest
var _message: Label
var _list: VBoxContainer
var _catalog: Array = []
var _request_kind := ""
var _selected: Dictionary = {}
var _latest_release := ""

func _ready() -> void:
	custom_minimum_size = Vector2(640, 230)
	var heading := HBoxContainer.new()
	add_child(heading)
	var title := Label.new()
	title.text = "Nucleus Packages  |  Experimental"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var refresh := Button.new()
	refresh.text = "Refresh catalog"
	refresh.pressed.connect(refresh_catalog)
	heading.add_child(refresh)
	var updates := Button.new()
	updates.text = "Check core updates"
	updates.pressed.connect(check_core_updates)
	heading.add_child(updates)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	refresh_catalog()

func _request(url: String, kind: String) -> void:
	if _request_kind != "":
		_message.text = "A request is already running."
		return
	_request_kind = kind
	var error := _http.request(url, ["User-Agent: Nucleus-Godot-Editor", "Accept: application/vnd.github+json"])
	if error != OK:
		_request_kind = ""
		_message.text = "Request failed to start: %s" % error_string(error)
	else:
		_message.text = "Fetching %s..." % kind

func refresh_catalog() -> void:
	_request(CATALOG_URL, "catalog")

func check_core_updates() -> void:
	_request(API_RELEASE_URL, "updates")

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, data: PackedByteArray) -> void:
	var kind := _request_kind
	_request_kind = ""
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		_message.text = "HTTP error (%s, %s). Existing modules were not changed." % [result, code]
		return
	if kind == "package":
		var destination: String = _selected.get("path", "")
		var error := Installer.install_zip(data, destination)
		_message.text = "Installed %s. Refresh project files if needed." % _selected.get("id", "") if error.is_empty() else error
		if error.is_empty():
			EditorInterface.get_resource_filesystem().scan()
		return
	var parsed: Variant = JSON.parse_string(data.get_string_from_utf8())
	if not parsed is Dictionary:
		_message.text = "Invalid JSON response."
		return
	if kind == "updates":
		_latest_release = str(parsed.get("tag_name", ""))
		_message.text = "Latest GitHub release: %s. Core self-update not enabled in this prototype." % _latest_release
		return
	if not parsed.get("packages", null) is Array:
		_message.text = "Catalog has no packages array."
		return
	_catalog = parsed["packages"]
	_render_catalog()

func _render_catalog() -> void:
	for child in _list.get_children():
		child.queue_free()
	var valid := 0
	for value in _catalog:
		if not value is Dictionary:
			continue
		var entry: Dictionary = value
		if not Manifest.validate(entry).is_empty():
			continue
		valid += 1
		var line := HBoxContainer.new()
		_list.add_child(line)
		var label := Label.new()
		label.text = "%s  [%s]  v%s — %s" % [entry["id"], entry.get("category", "shared"), entry["version"], entry["description"]]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.tooltip_text = "Dependencies: %s\n%s" % [str(entry["dependencies"]), entry.get("documentation", "")]
		line.add_child(label)
		var docs := Button.new()
		docs.text = "Docs"
		docs.disabled = not str(entry.get("documentation", "")).begins_with("https://")
		docs.pressed.connect(OS.shell_open.bind(str(entry.get("documentation", ""))))
		line.add_child(docs)
		var install := Button.new()
		install.text = "Install"
		# Dependency-resolution and verified package releases are prerequisites for installation.
		install.disabled = true
		install.tooltip_text = "Pending release ZIP, hash verification and dependency resolver."
		line.add_child(install)
	_message.text = "%d available packages. Downloads require verified release archives." % valid
