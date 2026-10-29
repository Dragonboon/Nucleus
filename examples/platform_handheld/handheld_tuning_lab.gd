extends Control
## Visual preview first; simulated hardware never authorizes writes implicitly.

const PROFILES: Array[Resource] = [
	preload("res://addons/nucleus/modules/performance/profiles/handheld_battery.tres"),
	preload("res://addons/nucleus/modules/performance/profiles/handheld_balanced.tres"),
	preload("res://addons/nucleus/modules/performance/profiles/handheld_quality.tres"),
]

var _detection_choice: OptionButton
var _detection_report: Label
var _settings: NucleusSettingsService
var _profile_choice: OptionButton
var _preview: Label
var _apply_button: Button
var _undo_button: Button
var _snapshot: Dictionary = {}
var _undo: Dictionary = {}


func _ready() -> void:
	_settings = get_node_or_null("/root/NucleusSettings") as NucleusSettingsService
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(410, 0)
	add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	var header := Label.new()
	header.text = "HANDHELD PERFORMANCE · OPTIONAL"
	col.add_child(header)
	var info := Label.new()
	var device: Dictionary = NucleusPlatform.get_handheld_info()
	info.text = "Detected: %s (%s)" % [
		device["model"] if str(device["model"]) != "" else "Unknown device",
		device["confidence"],
	]
	col.add_child(info)
	_detection_choice = OptionButton.new()
	for title: String in [
		"Live device", "Simulated: Steam Deck OLED",
		"Simulated: ASUS ROG Ally X", "Simulated: desktop",
	]:
		_detection_choice.add_item(title)
	_detection_choice.item_selected.connect(_show_detection)
	col.add_child(_detection_choice)
	_detection_report = Label.new()
	_detection_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detection_report)
	_show_detection(0)
	_profile_choice = OptionButton.new()
	for profile: NucleusHandheldTuningProfile in PROFILES:
		_profile_choice.add_item(profile.display_name)
	_profile_choice.selected = 1
	_profile_choice.item_selected.connect(func(_index: int) -> void: _refresh())
	col.add_child(_profile_choice)
	_preview = Label.new()
	col.add_child(_preview)
	_apply_button = Button.new()
	_apply_button.text = "Apply selected profile"
	_apply_button.pressed.connect(_apply)
	col.add_child(_apply_button)
	_undo_button = Button.new()
	_undo_button.text = "Undo last application"
	_undo_button.pressed.connect(_undo_last)
	col.add_child(_undo_button)
	_refresh()


func _selected_profile() -> NucleusHandheldTuningProfile:
	return PROFILES[_profile_choice.selected] as NucleusHandheldTuningProfile


func _refresh() -> void:
	_snapshot.clear()
	_apply_button.disabled = true
	_undo_button.disabled = _undo.is_empty()
	if _settings == null or not _settings.is_initialized():
		_preview.text = "NucleusSettings is unavailable. Preview only: no changes."
		return
	var proposal: Dictionary = NucleusHandheldSettingsAdvisor.preview(
		_selected_profile(), _settings
	)
	if proposal["error"] != OK:
		_preview.text = "Profile unavailable: " + error_string(proposal["error"])
		return
	var text_lines := PackedStringArray()
	for change: Dictionary in proposal["changes"]:
		text_lines.append("%s: %s → %s" % [
			change["id"], change["current"], change["suggested"],
		])
		_snapshot[change["id"]] = change["current"]
	_preview.text = "\n".join(text_lines)
	_apply_button.disabled = false


func _apply() -> void:
	var result: Dictionary = NucleusHandheldSettingsAdvisor.apply_profile(
		_selected_profile(), _settings, true, _snapshot
	)
	if result["error"] == OK:
		_undo = result
	_refresh()


func _undo_last() -> void:
	var status: Error = NucleusHandheldSettingsAdvisor.revert_if_unchanged(
		_settings, _undo.get("previous_values", {}),
		_undo.get("applied_values", {}), true
	)
	if status == OK:
		_undo.clear()
	_refresh()


func _show_detection(index: int) -> void:
	var data: Dictionary
	match index:
		1:
			data = NucleusHandheldDetector.classify({
				"os_name": "Linux",
				"sys_vendor": "Valve",
				"product_name": "Galileo",
			})
		2:
			data = NucleusHandheldDetector.classify({
				"os_name": "Windows",
				"sys_vendor": "ASUSTeK",
				"product_name": "RC72LA",
			})
		3:
			data = NucleusHandheldDetector.classify({
				"os_name": "Windows", "model": "Desktop PC",
			})
		_:
			data = NucleusPlatform.get_handheld_info()
	var mode: String = "LIVE" if index == 0 else "SIMULATED"
	_detection_report.text = (
		"%s | %s\nFamily: %s\nModel: %s\nConfidence: %s\nSource: %s"
		% [
			mode, data["os_name"], data["family"], data["model"],
			data["confidence"], data["source"],
		]
	)
