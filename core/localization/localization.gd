class_name NucleusLocalization
extends RefCounted
## Stateless facade over Godot's TranslationServer locale facilities.
##
## TranslationServer owns the active locale. Nucleus adds automatic locale
## resolution, selector metadata, and a stable integration point for Settings.

const AUTOMATIC_LOCALE: String = "automatic"
const FALLBACK_SETTING: StringName = &"internationalization/locale/fallback"


static func apply_locale(requested_locale: String) -> String:
	var resolved: String = resolve_locale(requested_locale)

	if resolved.is_empty():
		return ""

	TranslationServer.set_locale(resolved)

	return TranslationServer.get_locale()


static func resolve_locale(requested_locale: String) -> String:
	var requested: String = requested_locale.strip_edges()

	if (
		requested.is_empty()
		or requested.nocasecmp_to(AUTOMATIC_LOCALE) == 0
	):
		return resolve_automatic_locale()

	var standardized: String = TranslationServer.standardize_locale(requested)
	var loaded: PackedStringArray = get_loaded_locales()

	if loaded.is_empty():
		return standardized

	var matched: String = find_best_loaded_locale(
		standardized,
		loaded,
	)

	if not matched.is_empty():
		return matched

	return _resolve_fallback_locale(loaded)


static func resolve_automatic_locale() -> String:
	var system_locale: String = TranslationServer.standardize_locale(
		OS.get_locale()
	)
	var loaded: PackedStringArray = get_loaded_locales()

	if loaded.is_empty():
		return system_locale

	var matched: String = find_best_loaded_locale(
		system_locale,
		loaded,
	)

	if not matched.is_empty():
		return matched

	var language_only: String = OS.get_locale_language()
	matched = find_best_loaded_locale(
		language_only,
		loaded,
	)

	if not matched.is_empty():
		return matched

	return _resolve_fallback_locale(loaded)


static func get_loaded_locales() -> PackedStringArray:
	var result := PackedStringArray()

	for locale: String in TranslationServer.get_loaded_locales():
		var standardized: String = TranslationServer.standardize_locale(locale)

		if (
			not standardized.is_empty()
			and standardized not in result
		):
			result.append(standardized)

	result.sort()

	return result


static func find_best_loaded_locale(
	requested_locale: String,
	loaded_locales: PackedStringArray = PackedStringArray(),
) -> String:
	var candidates: PackedStringArray = loaded_locales

	if candidates.is_empty():
		candidates = get_loaded_locales()

	var standardized: String = TranslationServer.standardize_locale(
		requested_locale
	)
	var best_locale: String = ""
	var best_score: int = 0

	for locale: String in candidates:
		var score: int = TranslationServer.compare_locales(
			standardized,
			locale,
		)

		if score > best_score:
			best_score = score
			best_locale = locale

	return best_locale


static func get_selectable_locales(
	catalog: NucleusLocaleCatalog = null,
	loaded_only: bool = true,
) -> Array[NucleusLocaleDefinition]:
	if not loaded_only:
		return _catalog_locales(catalog)

	var loaded: PackedStringArray = get_loaded_locales()

	if loaded.is_empty():
		loaded.append(get_fallback_locale())

	var result: Array[NucleusLocaleDefinition] = []

	for locale: String in loaded:
		if locale.is_empty():
			continue

		result.append(
			_create_runtime_definition(
				locale,
				catalog,
			)
		)

	result.sort_custom(
		func(
			left: NucleusLocaleDefinition,
			right: NucleusLocaleDefinition,
		) -> bool:
			return (
				left.get_display_name(true).nocasecmp_to(
					right.get_display_name(true)
				)
				< 0
			)
	)

	return result


static func get_fallback_locale() -> String:
	var configured: String = str(
		ProjectSettings.get_setting(
			FALLBACK_SETTING,
			"en",
		)
	)

	if configured.is_empty():
		configured = "en"

	return TranslationServer.standardize_locale(configured)


static func get_display_name(
	locale: String,
	catalog: NucleusLocaleCatalog = null,
	use_native_name: bool = true,
) -> String:
	if catalog:
		var definition: NucleusLocaleDefinition = catalog.find_best(locale)

		if definition:
			return definition.get_display_name(use_native_name)

	return TranslationServer.get_locale_name(
		TranslationServer.standardize_locale(locale)
	)


static func is_right_to_left(locale: String = "") -> bool:
	var resolved: String = locale

	if resolved.is_empty():
		resolved = TranslationServer.get_locale()

	var text_server: TextServer = TextServerManager.get_primary_interface()

	if text_server == null:
		return false

	return text_server.is_locale_right_to_left(resolved)


static func _resolve_fallback_locale(
	loaded: PackedStringArray,
) -> String:
	var fallback: String = get_fallback_locale()
	var matched: String = find_best_loaded_locale(
		fallback,
		loaded,
	)

	if not matched.is_empty():
		return matched

	return loaded[0] if not loaded.is_empty() else fallback


static func _catalog_locales(
	catalog: NucleusLocaleCatalog,
) -> Array[NucleusLocaleDefinition]:
	var result: Array[NucleusLocaleDefinition] = []

	if catalog == null:
		return result

	for definition: NucleusLocaleDefinition in catalog.locales:
		if definition:
			result.append(definition)

	return result


static func _create_runtime_definition(
	locale: String,
	catalog: NucleusLocaleCatalog,
) -> NucleusLocaleDefinition:
	var definition := NucleusLocaleDefinition.new()
	definition.locale = locale
	definition.native_name = ""
	definition.english_name = ""

	if catalog:
		var catalog_definition: NucleusLocaleDefinition = (
			catalog.find_best(locale)
		)

		if catalog_definition:
			definition.native_name = catalog_definition.native_name
			definition.english_name = catalog_definition.english_name

	if definition.native_name.is_empty():
		definition.native_name = TranslationServer.get_locale_name(locale)

	if definition.english_name.is_empty():
		definition.english_name = TranslationServer.get_locale_name(locale)

	return definition
