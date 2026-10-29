extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	var previous := TranslationServer.get_locale()
	var translation := load("res://tests/fixtures/localization/es.po") as Translation
	expect_true(translation != null, "Godot loads PO natively.")
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("es")
	var message := NucleusLocalizedMessage.new()
	message.source = "Open"
	message.context = &"verb"
	expect_equal(message.resolve(), "Abrir", "Context selects verb.")
	message.context = &"adjective"
	expect_equal(message.resolve(), "Abierto", "Context separates identical source text.")
	message.context = &""
	message.source = "{count} item"
	message.plural = "{count} items"
	expect_equal(message.resolve(0), "0 objetos", "Native Spanish zero plural.")
	expect_equal(message.resolve(1), "1 objeto", "Native Spanish singular.")
	expect_equal(message.resolve(2), "2 objetos", "Native Spanish plural.")
	var russian := load("res://tests/fixtures/localization/ru.po") as Translation
	TranslationServer.add_translation(russian)
	TranslationServer.set_locale("ru")
	expect_equal(message.resolve(1), "1 предмет", "Native Russian first plural form.")
	expect_equal(message.resolve(2), "2 предмета", "Native Russian second plural form.")
	expect_equal(message.resolve(5), "5 предметов", "Native Russian third plural form.")
	TranslationServer.remove_translation(russian)
	TranslationServer.set_locale("es")
	var args := {"count": 9}
	expect_equal(message.resolve(2, args), "9 objetos",
		"Explicit argument overrides count formatting.")
	expect_equal(args, {"count": 9}, "Formatting does not mutate arguments.")
	message.source = "Untranslated source"
	message.plural = ""
	expect_equal(message.resolve(), message.source, "Missing translation retains source text.")
	var root := Control.new()
	attach_test_node(root)
	var label := Label.new()
	root.add_child(label)
	var binding := NucleusLocalizedTextBinding.new()
	binding.message = NucleusLocalizedMessage.new()
	binding.message.source = "Hello {name}"
	binding.arguments = {"name": "Ada"}
	label.add_child(binding)
	expect_equal(label.text, "Hola Ada", "Parent Label binds without per-widget scripts.")
	expect_equal(label.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED,
		"Already translated text is not auto-translated again.")
	expect_equal(binding.set_values(1, {"name": "Lin"}), OK, "Arguments refresh explicitly.")
	expect_equal(label.text, "Hola Lin", "Updated argument appears.")
	binding.target_property = "position"
	expect_equal(binding.refresh(), ERR_INVALID_PARAMETER, "Binding cannot write transforms.")
	binding.target_property = "text"
	label.remove_child(binding)
	expect_equal(label.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_INHERIT,
		"Exit restores authored native mode.")
	label.add_child(binding)
	expect_equal(label.text, "Hola Lin", "Re-entry refreshes binding.")
	var collected := NucleusTranslationTemplates.collect_scene(root)
	expect_equal(collected.size(), 1, "Live scene collects authored messages only.")
	var template := NucleusTranslationTemplates.build_pot(collected)
	expect_equal(template.error, OK, "Template builds.")
	var path := "user://nucleus_test_messages.pot"
	DirAccess.remove_absolute(path)
	expect_equal(NucleusTranslationTemplates.write_pot(path, collected), OK, "Runtime POT writes.")
	expect_equal(NucleusTranslationTemplates.write_pot(path, collected), ERR_ALREADY_EXISTS,
		"Existing template is protected unless overwrite is explicit.")
	var conflicting := binding.message.duplicate() as NucleusLocalizedMessage
	conflicting.plural = "different plural"
	collected.append(conflicting)
	expect_equal(NucleusTranslationTemplates.write_pot(path, collected, true), ERR_INVALID_DATA,
		"Conflicting identities reject before file mutation.")
	expect_equal(FileAccess.get_file_as_string(path), template.text,
		"Invalid update leaves previous file intact.")
	DirAccess.remove_absolute(path)
	var selectable := NucleusLocalization.get_selectable_locales(null)
	for definition: NucleusLocaleDefinition in selectable:
		if definition.locale == "es":
			expect_equal(definition.native_name, TranslationServer.get_locale_name("es"),
				"Unknown catalog locale does not inherit English metadata.")
	expect_equal(NucleusLocalization.resolve_locale("es_MX"), "es",
		"Regional fallback uses loaded locale.")
	expect_equal(NucleusLocalizationProjectTools.register_translations([]), ERR_UNAVAILABLE,
		"Runtime cannot rewrite project translation settings.")
	var catalog: NucleusMessageCatalog = load(
		"res://addons/nucleus/core/localization/defaults/common_messages.tres")
	expect_equal(NucleusTranslationTemplates.collect_resource(catalog).size(), 12,
		"Resource catalog is available to tooling.")
	var en := load("res://addons/nucleus/core/localization/translations/en.po") as Translation
	var es := load("res://addons/nucleus/core/localization/translations/es.po") as Translation
	for entry: NucleusLocalizedMessage in catalog.messages:
		expect_false(en.get_message(entry.source).is_empty(), "English common message is translated.")
		expect_false(es.get_message(entry.source).is_empty(), "Spanish common message is translated.")
	free_test_node(root)
	TranslationServer.remove_translation(translation)
	TranslationServer.set_locale(previous)
	return finish()
