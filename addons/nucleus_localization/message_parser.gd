@tool
extends EditorTranslationParserPlugin
## Extends extraction, never replaces Godot's scene or GDScript parsers.


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["tres"])


func _parse_file(path: String) -> Array[PackedStringArray]:
	var resource := ResourceLoader.load(path)
	return _entries(NucleusTranslationTemplates.collect_resource(resource))


func _customize_strings(strings: Array[PackedStringArray]) -> Array[PackedStringArray]:
	# Native scene extraction cannot see our message fields in embedded Resources.
	var paths: PackedStringArray = ProjectSettings.get_setting(
		NucleusLocalizationProjectTools.SOURCES, PackedStringArray())
	for path: String in paths:
		if path.get_extension() == "tscn":
			strings.append_array(_entries(NucleusTranslationTemplates.collect_resource(
				ResourceLoader.load(path))))
	return strings


func _entries(messages: Array[NucleusLocalizedMessage]) -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	for message: NucleusLocalizedMessage in messages:
		if not message.source.is_empty():
			result.append(PackedStringArray([message.source, String(message.context),
				message.plural, message.translator_comment]))
	return result
