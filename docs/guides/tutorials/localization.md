# Tutorial: ship English and Spanish with a persistent language selector

This tutorial builds a tiny localized menu using Godot translation resources and
the Nucleus locale setting/binding.

At the end:

- English and Spanish are loaded by Godot;
- visible menu text changes at runtime;
- an `OptionButton` is populated automatically;
- the player's explicit language choice persists;
- `Automatic` follows Nucleus locale resolution/fallback rules.

## Optional authoring shortcut

The [localization pipeline](../../components/localization_pipeline.md) supplies
an editor addon for registering PO files and collecting source folders, plus
message Resources and bindings for dynamic text. The manual native workflow below
remains supported. The framework's common EN/ES files are already registered;
these example menu strings belong to the consuming game.

## 1. Create translation files

Create a game-owned directory:

```text
res://assets/localization/
```

Create `en.po`:

```po
msgid ""
msgstr ""
"Language: en\n"
"Content-Type: text/plain; charset=UTF-8\n"

msgid "MAIN_MENU_TITLE"
msgstr "Main Menu"

msgid "NEW_GAME"
msgstr "New Game"

msgid "OPTIONS"
msgstr "Options"

msgid "LANGUAGE"
msgstr "Language"

msgid "Automatic"
msgstr "Automatic"
```

Create `es.po`:

```po
msgid ""
msgstr ""
"Language: es\n"
"Content-Type: text/plain; charset=UTF-8\n"

msgid "MAIN_MENU_TITLE"
msgstr "Menú principal"

msgid "NEW_GAME"
msgstr "Nueva partida"

msgid "OPTIONS"
msgstr "Opciones"

msgid "LANGUAGE"
msgstr "Idioma"

msgid "Automatic"
msgstr "Automático"
```

## 2. Register them with Godot

In Project Settings, add both imported translation resources to Godot's
localization translations list.

This step matters because Nucleus discovers available languages through
`TranslationServer.get_loaded_locales()`.

Do not maintain a second "enabled language list" in game code unless the game has
an intentional product restriction.

## 3. Build a small scene

```text
LocalizationDemo : Control
└── VBoxContainer
    ├── Title : Label
    ├── NewGame : Button
    ├── Options : Button
    └── LanguageRow : HBoxContainer
        ├── LanguageLabel : Label
        └── Language : OptionButton
            └── LocaleBinding : NucleusLocaleOptionBinding
```

Leave the binding's default setting/catalog in place.

Useful starting values:

```text
include_automatic = true
loaded_locales_only = true
use_native_names = true
show_locale_code = true   # useful while validating
```

## 4. Refresh manually assigned strings

Attach this script to `LocalizationDemo`:

```gdscript
extends Control


func _ready() -> void:
    _refresh_text()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _refresh_text()


func _refresh_text() -> void:
    %Title.text = tr("MAIN_MENU_TITLE")
    %NewGame.text = tr("NEW_GAME")
    %Options.text = tr("OPTIONS")
    %LanguageLabel.text = tr("LANGUAGE")
```

This is normal Godot behavior: values you assign manually with `tr()` need to be
assigned again when the active translation changes.

The locale selector itself listens for translation changes and repopulates its
presentation automatically.

## 5. Run and change language

When you select Spanish, this path occurs:

```text
OptionButton
→ NucleusLocaleOptionBinding
→ NucleusSettings.set_value("localization/locale", "es")
→ NucleusLocalizationSettingsApplier
→ NucleusLocalization.apply_locale("es")
→ TranslationServer.set_locale(...)
→ NOTIFICATION_TRANSLATION_CHANGED
→ visible UI refresh
```

You should not need a custom language-manager singleton.

## 6. Restart and verify persistence

Select Spanish, close the game and launch again.

The stored settings value should be applied on startup and the menu should render
using Spanish.

Select `Automatic` and restart again. The setting now stores:

```text
automatic
```

while `NucleusLocalization` resolves the actual runtime locale.

## 7. Inspect the resolved locale

For diagnostics:

```gdscript
print("Setting: ", NucleusSettings.get_value(&"localization/locale"))
print("Applied: ", TranslationServer.get_locale())
print("Loaded: ", NucleusLocalization.get_loaded_locales())
```

The setting and the applied locale are intentionally not always identical:
`automatic` is a policy request, while `TranslationServer.get_locale()` is the
resolved runtime locale.

## 8. Curate language names only when necessary

The default `NucleusLocaleCatalog` supplies presentation metadata for common
locales.

You can provide your own catalog to the binding when a product needs curated
names or a restricted list.

Remember:

```text
translation loaded by Godot
    = actual language availability

locale catalog
    = optional presentation metadata
```

## 9. Region fallback exercise

If you later ship `es_ES` but the OS reports another Spanish variant, inspect:

```gdscript
NucleusLocalization.resolve_locale("es_MX")
```

Nucleus asks Godot's locale comparison to find the best loaded match before
falling back.

This is preferable to hand-written `if locale.begins_with("es")` logic scattered
through the game.

## 10. RTL exercise

Print:

```gdscript
print(NucleusLocalization.is_right_to_left())
```

When adding Arabic/Hebrew later, use this as one input to game-owned UI layout
policy. It does not automatically solve fonts, icon direction, or layout
mirroring.

## Common mistakes

- changing `TranslationServer` directly from the `OptionButton`;
- putting language names in a second hard-coded array;
- storing "Nueva partida" in a save instead of a stable ID/key;
- assuming setting `automatic` is itself a real locale code;
- forgetting manual text refresh on locale change.

## Next steps

- [`../localization_quickstart.md`](../localization_quickstart.md)
- [`bindings.md`](bindings.md)
- [`../../components/audio_save_scene_localization.md`](../../components/audio_save_scene_localization.md)
