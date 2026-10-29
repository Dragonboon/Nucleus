class_name NucleusLocaleDefinition
extends Resource
## Presentation metadata for one locale.
##
## TranslationServer remains the authority for locale matching and translation.
## This Resource only enriches language selectors with stable human labels.

@export var locale: String = "en"
@export var native_name: String = "English"
@export var english_name: String = "English"


func get_standardized_locale() -> String:
	return TranslationServer.standardize_locale(locale)


func get_display_name(use_native_name: bool = true) -> String:
	var preferred_name: String = (
		native_name
		if use_native_name
		else english_name
	)

	if not preferred_name.is_empty():
		return preferred_name

	return TranslationServer.get_locale_name(
		get_standardized_locale()
	)
