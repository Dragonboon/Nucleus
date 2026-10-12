extends Control
## Pure diagnostic. Samples are labelled simulated; no settings are modified.

var _report: Label
var _choice: OptionButton


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(340, 0)
	add_child(panel)
	var layout := VBoxContainer.new()
	panel.add_child(layout)
	var header := Label.new()
	header.text = "PC HANDHELD DETECTION"
	layout.add_child(header)
	_choice = OptionButton.new()
	for title: String in [
		"Live device", "Simulated: Steam Deck OLED",
		"Simulated: ASUS ROG Ally X", "Simulated: desktop",
	]:
		_choice.add_item(title)
	_choice.item_selected.connect(_show_result)
	layout.add_child(_choice)
	_report = Label.new()
	layout.add_child(_report)
	_show_result(0)


func _show_result(index: int) -> void:
	var data: Dictionary
	match index:
		1:
			data = NucleusHandheldDetector.classify({
				"os_name": "Linux", "sys_vendor": "Valve", "product_name": "Galileo",
			})
		2:
			data = NucleusHandheldDetector.classify({
				"os_name": "Windows", "sys_vendor": "ASUSTeK",
				"product_name": "RC72LA",
			})
		3:
			data = NucleusHandheldDetector.classify({
				"os_name": "Windows", "model": "Desktop PC",
			})
		_:
			data = NucleusPlatform.get_handheld_info()
	var mode: String = "LIVE" if index == 0 else "SIMULATED"
	_report.text = "%s | %s\nFamily: %s\nModel: %s\nConfidence: %s" % [
		mode, data["os_name"], data["family"], data["model"],
		data["confidence"],
	]
	_report.text += "\nEvidence: %s\nNo graphics settings changed." % data["source"]
