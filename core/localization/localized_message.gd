@tool
class_name NucleusLocalizedMessage
extends Resource
## Authored source identity; TranslationServer remains the only translation database.

@export_multiline var source: String = ""
@export_multiline var plural: String = ""
@export var context: StringName = &""
@export_multiline var translator_comment: String = ""


func resolve(count: int = 1, arguments: Dictionary = {}) -> String:
	if source.is_empty():
		return ""
	var translated: String
	if plural.is_empty():
		translated = str(TranslationServer.translate(source, context))
	else:
		translated = str(TranslationServer.translate_plural(source, plural, count, context))
	# format substitutes only named placeholders; no evaluation or second translation.
	var values := arguments.duplicate()
	if not values.has("count"):
		values["count"] = count
	return translated.format(values)
