class_name NucleusLocaleCatalog
extends Resource
## Optional presentation catalog for commonly shipped locales.
##
## A locale does not need to exist here to work. Loaded Translation resources
## are discovered dynamically through TranslationServer.

@export var locales: Array[NucleusLocaleDefinition] = []


func find_exact(locale: String) -> NucleusLocaleDefinition:
	var standardized: String = TranslationServer.standardize_locale(locale)

	for definition: NucleusLocaleDefinition in locales:
		if definition == null:
			continue

		if definition.get_standardized_locale() == standardized:
			return definition

	return null


func find_best(locale: String) -> NucleusLocaleDefinition:
	var exact: NucleusLocaleDefinition = find_exact(locale)

	if exact:
		return exact

	var standardized: String = TranslationServer.standardize_locale(locale)
	var best: NucleusLocaleDefinition
	var best_score: int = 0

	for definition: NucleusLocaleDefinition in locales:
		if definition == null:
			continue

		var score: int = TranslationServer.compare_locales(
			standardized,
			definition.get_standardized_locale(),
		)

		if score > best_score:
			best_score = score
			best = definition

	return best


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary[String, bool] = {}

	for index: int in range(locales.size()):
		var definition: NucleusLocaleDefinition = locales[index]

		if definition == null:
			errors.append("locales[%d] is null" % index)
			continue

		var standardized: String = definition.get_standardized_locale()

		if standardized.is_empty():
			errors.append(
				"locales[%d] has an invalid locale" % index
			)
			continue

		if seen.has(standardized):
			errors.append(
				"duplicate locale '%s'" % standardized
			)
			continue

		seen[standardized] = true

	return errors
