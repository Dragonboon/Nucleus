# Localization authoring and runtime pipeline

Introduced in `0.35.0-dev.1`. Godot's TranslationServer, gettext loader, plural
rules and editor extraction remain authoritative. No new Autoload or translated
string database is introduced. Runtime adapters work without the editor addon
or GNU gettext installed.

## Editor panel quickstart

Since `0.38.0-dev.1`, the optional addon has a **Localization** bottom panel for
registered catalogs, gettext creation/update/validation and source diagnostics.
Start with the [end-to-end ability translation example](../guides/localization_workflow.md).
Godot still owns full POT generation; the panel explains the native step instead
of using private editor UI APIs. Python/gettext jobs are asynchronous, cancellable
and use the existing conservative PO writer. No new runtime dependency is added.

## Ownership

| Need | Godot owner | Nucleus adapter | Game owns |
| --- | --- | --- | --- |
| Translate and select plural form | TranslationServer | LocalizedMessage Resource | Source IDs, contexts, translated content |
| Display changing text | Control and translation notification | LocalizedTextBinding | Formatting arguments, widget and property |
| Choose and persist language | TranslationServer + Settings | Existing Localization/LocaleOptionBinding | Available languages and fonts |
| Load PO/MO | Native ResourceLoader and project translation list | Optional LocalizationProjectTools | Files to ship and translation quality |
| Extract scenes/GDScript | Native editor template generator | Optional message Resource parser | Source folders and dynamic message inventory |
| Export a live scene's authored messages | FileAccess + gettext format | Optional TranslationTemplates | Capture time, output and completeness |
| Maintain translated PO files | GNU gettext | Small CLI wrapper | Translator review and fuzzy resolution |

Two independent consumers are supported: ordinary UI with variable values and
content-driven games whose messages live in Resources. Source messages are
content, not a replacement translation service.

## Built-in translations

`core/localization/translations/en.po` and `es.po` provide 12 common UI strings,
including Automatic, Language, controller connection notices, OK and Cancel.
`defaults/common_messages.tres` is their source inventory for dynamically read
framework defaults. Catalog coverage and placeholder syntax are tested.

The template registers these two PO files and an English fallback. Remove or
replace those entries under Project Settings > Localization when a game's
language policy differs. Do not register conflicting translations of the same
source/context in several files; native lookup precedence is not an override API.
The locale metadata catalog lists many language names; it does **not** mean that
translations for all those languages ship. Game content, all settings metadata,
logs, docs and optional modules are not automatically translated by this pack.

## Reusable messages

Create a `NucleusLocalizedMessage` Resource, either embedded in a scene or saved
as `.tres`:

```gdscript
var message := NucleusLocalizedMessage.new()
message.source = "{count} item"
message.plural = "{count} items"
message.context = &"inventory"
message.translator_comment = "Number of items in the selected stack."
var text := message.resolve(3) # Native plural lookup, then named formatting.
```

`source` is the singular gettext msgid; `plural` is optional. `context` maps to
msgctxt. `resolve(count = 1, arguments = {})` uses the active TranslationServer
locale and its fallback. It injects `{count}` unless the caller supplies that
argument. It never mutates the arguments dictionary or the Resource.

Use readable source text, or stable IDs with a complete source-language PO.
Missing translations fall back through Godot to source text. Empty source returns
empty text. Prefer named placeholders so translators can reorder a sentence.
Pass nonnegative counts. Formatting is native String.format, not expression
execution; RichTextLabel content still needs game-owned BBCode escaping.

A `NucleusMessageCatalog` holds source message Resources for data-driven content
that static code extraction cannot discover. It stores no translations.

## Bind a Control without writing a translation callback

Add `NucleusLocalizedTextBinding` beneath a Label, Button, RichTextLabel or other
Control with the desired string property, and assign `message`. The parent is
used when `target` is unset. Choose `text`, `placeholder_text` or `tooltip_text`.
For an editable LineEdit, normally bind the placeholder rather than user input.

- `set_values(count, arguments = {}) -> Error` updates dynamic data and refreshes.
- `refresh() -> Error` applies Inspector/runtime field edits explicitly.
- Native translation notifications refresh automatically on language changes.
- The binding temporarily disables auto-translation on its target to avoid
  translating already resolved text twice, and restores the previous mode on exit.
- Give one binding ownership of one target Control. Do not combine it with
  another writer to that property or another binding that owns its auto mode.
  Use leaf Controls: disabling auto mode also affects inheriting descendants.
- Invalid/missing references or unsupported properties return an Error before
  writing. Exit/re-entry restores/rebinds native state.

The existing locale selector now reconnects on re-entry and exposes `refresh()`
for callers that add/remove translations at runtime. An explicit regional request
such as es_MX displays its resolved available locale instead of falsely selecting
Automatic. Unknown metadata uses Godot's locale name instead of inheriting English.

## Import and extract using the editor

1. Enable **Nucleus Localization** in Project Settings > Plugins. The addon is
   shipped disabled and adds no runtime dependency.
2. Place translator-supplied `.po`/`.mo` files under `res://` (Godot's normal file
   import). Use **Project > Tools > Nucleus: Register PO/MO translations** to
   register several files at once. Godot parses them; their Language header is
   authoritative. Existing entries remain, duplicate paths are ignored, and a
   failed batch does not partially change project settings. Start a new game run
   to load the updated project translation list.
3. Use **Nucleus: Add translation source folder** on the game's content folder.
   `.gd`, `.tscn` and `.tres` files are added to Godot's template source list.
   Existing selections remain. Hidden folders, addons, tests, build and linked
   directories are skipped. Rescan after adding files; remove deleted entries in
   the native localization settings. Avoid scanning the whole framework blindly.
4. Open **Project Settings > Localization > Template Generation > Generate**.
   Godot extracts its supported scene properties and constant tr()/tr_n() calls.
   The plugin adds message Resources, including embedded and inherited scene
   Resources, without instantiating the gameplay scene. Source/context/plural and
   translator comments are preserved.
5. Translate the resulting POT using Poedit, Weblate or GNU gettext. Import the
   resulting PO files with step 2.

The addon does not replace the native GDScript/scene parsers or synthesize
translations. Runtime-generated IDs and branches never visited by tooling need
an explicit source catalog. Resource traversal is cycle-aware and depth-limited
to 64; unusually deep content must be split into catalogs. Registered source
Resources are trusted project content, not arbitrary untrusted executable assets.

Programmatic editor operations are available through
`NucleusLocalizationProjectTools.register_translations(paths, persist = true)`
and `add_source_folder(folder, persist = true)`. They reject runtime use, preserve
existing settings and roll back an unsuccessful ProjectSettings save. Pass false
for in-memory editor staging; no global language preference is changed.

## Generate from the running game

For a development tool or a content editor inside a game:

```gdscript
var messages := NucleusTranslationTemplates.collect_scene($Interface)
var error := NucleusTranslationTemplates.write_pot("user://interface.pot", messages)
```

`collect_scene` collects LocalizedTextBinding messages from the live subtree.
It does not reverse-engineer already translated Labels, intercept tr(), or claim
coverage of screens not loaded. Combine it with
`collect_resource(catalog_or_packed_scene)` for authored content outside that tree.
For complete code/scene extraction, use Godot's editor workflow above.

`build_pot(messages)` returns `{error, text}`. Output is deterministic and deduped
by source/context; conflicting plural definitions reject. `write_pot` accepts
`user://` at runtime and also `res://` in the editor. The parent folder must exist.
Existing files reject unless `overwrite = true`; invalid input is checked before
writing, and successful writes use a temporary file and rename. Only POT files
are emitted. No existing translated PO file is rewritten by this API.

## Create, update and check PO files

Install GNU gettext for these optional development commands:

```bash
python3 scripts/localization/catalogs.py init locale/messages.pot locale/es.po --locale es
python3 scripts/localization/catalogs.py update locale/messages.pot locale/es.po
python3 scripts/localization/catalogs.py check locale/en.po locale/es.po
```

The wrapper invokes msginit/msgmerge/msgfmt, not a homemade PO parser. Creation
refuses an existing file. Update validates temporary output, preserves translated
entries using gettext, retains fuzzy/obsolete metadata and creates a `.po.bak`
backup before replacement. A previous backup must be moved first. Fuzzy entries
require translator review; Godot does not use them as final translations. Checks
validate syntax and marked formatting placeholders and print translation counts;
they do not establish linguistic quality or require 100% coverage.

The POT writer marks named-brace messages as python-brace-format for gettext's
placeholder checks. Keep matching names in translations. Plural templates have
empty entries; msginit creates the language-specific plural header/forms. Never
assume two plural forms for every language.

## Compatibility and proof

Existing tr()/tr_n(), Settings locale IDs, locale catalogs and serialized selector
fields remain compatible. Dialog fallback text now uses native translation too;
explicit keyed dialog text keeps its previous fallback behavior. Applications
that require literal untranslated text should use native Controls directly.
The two supplied locales change Automatic resolution compared with an empty
translation list; adjust the project's registration list when adopting this pack.

`localization_test` covers native PO lookup, contexts, plurals, formatting,
source fallback, binding ownership, template safety and catalog coverage.
`localization_smoke.tscn` checks actual locale notifications and embedded scene
extraction. `check_localization_pipeline.py` runs the enabled addon in an isolated
editor project and exercises persisted registration, parser output and real
gettext creation/update/backup validation. It never rewrites the working project.
CI also retains the complete existing suite and platform smoke exports.

Verify fonts, glyphs, truncation, RTL layouts and language quality in the consuming
game. Metadata and headless assertions cannot certify those visual properties.

Native references: [gettext workflow](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_gettext.html)
and [translation parser plugin](https://docs.godotengine.org/en/stable/classes/class_editortranslationparserplugin.html).

## Editor source maintenance

`NucleusLocalizationProjectTools.audit_sources()` returns source-path diagnostics
for missing files, empty Resource messages and conflicting plural definitions.
It does not parse arbitrary code. `remove_missing_sources(persist=true)` explicitly
prunes missing source registrations, preserves existing files and rolls back a
failed settings save. Neither operation removes translated catalogs.
