# Localization Quickstart

Nucleus keeps localization deliberately close to Godot.

Use this guide when you need to ship more than one language, expose a language
selector, remember the player's choice, or resolve an automatic system locale.

For the complete build-along tutorial, continue with:

[`tutorials/localization.md`](tutorials/localization.md)

## Ownership model

Keep these responsibilities separate:

```text
Godot TranslationServer
    translation resources, active locale, locale comparison

NucleusLocalization
    locale resolution, automatic locale, display metadata, RTL query

NucleusSettings
    persists localization/locale

NucleusLocalizationSettingsApplier
    applies the stored setting to TranslationServer

NucleusLocaleOptionBinding
    connects an OptionButton to the locale setting
```

Nucleus does not maintain a second translation database.

## Authoring tools and reusable messages

For PO/MO registration, native POT extraction with message Resources, live-scene
POT export and safe gettext updates, use the
[localization pipeline](../components/localization_pipeline.md).
`NucleusLocalizedMessage` adds context/plurals/arguments, and
`NucleusLocalizedTextBinding` refreshes a Control automatically on locale changes.
The addon ships twelve common UI messages in English and Spanish; game
content and other languages still require their own translations.

## 1. Create translation resources

Keep game translations in a game-owned location, for example:

```text
res://assets/localization/en.po
res://assets/localization/es.po
```

Add them through Godot's localization project settings so
`TranslationServer.get_loaded_locales()` can discover them.

Use stable source keys:

```text
MAIN_MENU_TITLE
NEW_GAME
OPTIONS
QUIT
```

Do not use the translated English/Spanish display string as durable game data.

## 2. Translate display text

For game code that assigns text manually:

```gdscript
%Title.text = tr("MAIN_MENU_TITLE")
```

If you assign translated strings from code, refresh them when Godot emits
`NOTIFICATION_TRANSLATION_CHANGED`.

Godot editor-authored translatable Control properties can continue to use the
engine's normal localization behavior.

## 3. Use the built-in persisted locale setting

The baseline contains:

```text
localization/locale
```

Its default value is:

```text
automatic
```

The localization settings applier resolves that value and calls
`TranslationServer.set_locale()` through `NucleusLocalization`.

You normally do not need to call `TranslationServer.set_locale()` yourself from
an options menu.

## 4. Add a language selector

Create:

```text
Options
└── Language : OptionButton
    └── LocaleBinding : NucleusLocaleOptionBinding
```

The binding already defaults to:

```text
setting        = localization/locale
locale_catalog = default locale catalog
```

Useful properties:

```text
include_automatic    = true
loaded_locales_only  = true
use_native_names     = true
show_locale_code     = false
```

The binding populates the selector from loaded translations and persists the
selection through `NucleusSettings`.

## 5. Understand Automatic

`automatic` means:

```text
OS locale
→ best loaded locale match
→ language-only match
→ configured Godot fallback locale
→ first loaded locale as final fallback
```

This makes a normal first launch follow the operating system without game code
special-casing Windows, Linux, macOS, or console locale strings.

## 6. Locale catalogs are presentation metadata

`NucleusLocaleCatalog` is optional.

It can provide names such as:

```text
Español
English
Français
Deutsch
```

but a translation does not need to be in the catalog to work.

Loaded `Translation` resources remain authoritative.

Use the catalog when the language selector needs curated native/English names.

## 7. Region variants

Nucleus delegates locale comparison to Godot.

A request such as:

```text
es_MX
```

can resolve to the best loaded Spanish locale when an exact regional translation
is unavailable.

Use exact regional translations only when the content actually differs.

## 8. Right-to-left languages

Query:

```gdscript
var rtl: bool = NucleusLocalization.is_right_to_left()
```

This tells you about the active locale. The game still owns its actual layout,
fonts, mirroring rules, icon direction, and content testing.

## 9. Common mistakes

Avoid:

- changing `TranslationServer` directly from every settings widget;
- storing translated display strings in save files;
- assuming every locale must exist in `NucleusLocaleCatalog`;
- populating a language selector from a hard-coded list while shipping a
  different set of translations;
- forgetting to refresh strings that were assigned manually from `tr()`;
- treating locale selection and font/glyph coverage as the same problem.

## Verify the setup

A minimal verification pass is:

1. launch with at least two translations loaded;
2. confirm the language selector lists both;
3. switch language and see visible UI text update;
4. restart and confirm the explicit selection persists;
5. choose Automatic and confirm a valid loaded locale is selected;
6. temporarily remove a regional translation and verify fallback behavior.

## Related documentation

- [`tutorials/localization.md`](tutorials/localization.md)
- [`runtime_services_quickstart.md`](runtime_services_quickstart.md)
- [`../components/audio_save_scene_localization.md`](../components/audio_save_scene_localization.md)
- [`../components/ui_and_accessibility.md`](../components/ui_and_accessibility.md)
