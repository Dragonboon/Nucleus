class_name NucleusPerformanceDiagnostic
extends RefCounted
## Human-readable interpretation of one performance condition.

enum Severity {
	INFO,
	WARNING,
	CRITICAL,
}

var severity: int = Severity.INFO
var code: StringName
var title: String
var summary: String
var evidence := PackedStringArray()
var suggestions := PackedStringArray()


static func build(
	p_severity: int,
	p_code: StringName,
	p_title: String,
	p_summary: String,
	p_evidence: PackedStringArray = PackedStringArray(),
	p_suggestions: PackedStringArray = PackedStringArray(),
) -> NucleusPerformanceDiagnostic:
	var diagnostic := NucleusPerformanceDiagnostic.new()
	diagnostic.severity = p_severity
	diagnostic.code = p_code
	diagnostic.title = p_title
	diagnostic.summary = p_summary
	diagnostic.evidence = p_evidence
	diagnostic.suggestions = p_suggestions
	return diagnostic


func severity_name() -> String:
	match severity:
		Severity.WARNING:
			return "WARNING"
		Severity.CRITICAL:
			return "CRITICAL"
		_:
			return "INFO"


func to_dictionary() -> Dictionary:
	return {
		"severity": severity_name(),
		"code": str(code),
		"title": title,
		"summary": summary,
		"evidence": Array(evidence),
		"suggestions": Array(suggestions),
	}
