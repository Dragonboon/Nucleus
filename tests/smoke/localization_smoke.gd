extends Control

@export var fixture_message: NucleusLocalizedMessage
var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous := TranslationServer.get_locale()
	var translation := load("res://tests/fixtures/localization/es.po") as Translation
	TranslationServer.add_translation(translation)
	var label := Label.new()
	add_child(label)
	var binding := NucleusLocalizedTextBinding.new()
	binding.message = fixture_message
	binding.arguments = {"name": "Ada"}
	label.add_child(binding)
	var options := OptionButton.new()
	add_child(options)
	var selector := NucleusLocaleOptionBinding.new()
	options.add_child(selector)
	TranslationServer.set_locale("es")
	await get_tree().process_frame
	_check(label.text == "Hola Ada", "Locale notification refreshes bound text.")
	_check(options.get_item_text(0) == "Automático", "Selector's own caption is translated.")
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	_check(label.text == "Hello Ada", "Source fallback survives switching back.")
	_check(options.get_item_text(0) == "Automatic", "Selector refreshes on next change.")
	options.remove_child(selector)
	TranslationServer.set_locale("es")
	await get_tree().process_frame
	options.add_child(selector)
	_check(options.get_item_text(0) == "Automático", "Selector re-entry reconnects safely.")
	var packed := load("res://tests/smoke/localization_smoke.tscn") as PackedScene
	var messages := NucleusTranslationTemplates.collect_resource(packed)
	_check(messages.size() == 1, "Extraction sees embedded Resources without scene instantiation.")
	TranslationServer.remove_translation(translation)
	TranslationServer.set_locale(previous)
	if _failures.is_empty():
		print("Nucleus localization composition: PASS")
	else:
		for failure: String in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
