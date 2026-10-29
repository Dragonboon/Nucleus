extends PanelContainer
## Visual presentation for one Nucleus performance diagnostic.

const _COLOR_INFO: Color = Color(0.45, 0.70, 0.95)
const _COLOR_WARNING: Color = Color(0.96, 0.68, 0.24)
const _COLOR_CRITICAL: Color = Color(0.95, 0.33, 0.36)

@onready var _severity_label: Label = %Severity
@onready var _title_label: Label = %Title
@onready var _summary_label: Label = %Summary
@onready var _evidence_label: Label = %Evidence
@onready var _suggestion_label: Label = %Suggestion

var _panel_styles: Dictionary = {}


func _ready() -> void:
	_panel_styles = {
		NucleusPerformanceDiagnostic.Severity.INFO: _build_panel_style(_COLOR_INFO),
		NucleusPerformanceDiagnostic.Severity.WARNING: _build_panel_style(_COLOR_WARNING),
		NucleusPerformanceDiagnostic.Severity.CRITICAL: _build_panel_style(_COLOR_CRITICAL),
	}


func set_diagnostic(diagnostic: NucleusPerformanceDiagnostic) -> void:
	if diagnostic == null:
		hide()
		return

	show()
	_severity_label.text = diagnostic.severity_name()
	_title_label.text = diagnostic.title
	_summary_label.text = diagnostic.summary

	var evidence := _first_entries(diagnostic.evidence, 2)
	_evidence_label.visible = not evidence.is_empty()
	_evidence_label.text = "Evidence: %s" % evidence

	var suggestion := ""
	if not diagnostic.suggestions.is_empty():
		suggestion = diagnostic.suggestions[0]
	_suggestion_label.visible = not suggestion.is_empty()
	_suggestion_label.text = "Next: %s" % suggestion

	var color := _COLOR_INFO
	match diagnostic.severity:
		NucleusPerformanceDiagnostic.Severity.CRITICAL:
			color = _COLOR_CRITICAL
		NucleusPerformanceDiagnostic.Severity.WARNING:
			color = _COLOR_WARNING

	_severity_label.add_theme_color_override("font_color", color)
	_title_label.add_theme_color_override("font_color", color)
	add_theme_stylebox_override("panel", _panel_styles[diagnostic.severity])


func _first_entries(values: PackedStringArray, limit: int) -> String:
	var visible := PackedStringArray()
	var count := mini(values.size(), limit)

	for index: int in range(count):
		visible.append(values[index])

	return " · ".join(visible)


func _build_panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.085, 0.105, 0.98)
	style.border_width_left = 3
	style.border_color = accent
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style
