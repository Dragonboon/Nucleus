# Translate a game with the Nucleus Localization panel

## What you gain

Enable **Project Settings > Plugins > Nucleus Localization**, then open the
**Localization** bottom panel. It lists the project's registered PO/MO files,
their locale and source files. You can create language catalogs, merge new
messages into existing translations and inspect translation status without
running terminal commands.

The addon is optional editor tooling. Godot loads and resolves translations at
runtime; disabling the addon does not disable translation in your game.
For a small static UI, native `tr()` and Godot's localization settings are enough.
The addon is most useful when content lives in Resources or there are several
catalogs to maintain. It does not translate text automatically.

## Setup once

1. Install Python 3 and GNU gettext on the development machine. The required
   tools are `msginit`, `msgmerge`, `msgfmt` and `msgcmp`. Put gettext's executables
   on PATH and restart Godot after changing PATH. This is not a player dependency.
2. In the panel's **Python executable** field, use `python3` on Linux/macOS,
   `python` on Windows, or the absolute executable path. Do not add quotes or
   command-line flags to this field; paths with spaces are passed safely.
3. Click **Check tools**. A missing interpreter or gettext executable is reported
   in the panel. The Python path and chosen POT are stored in local editor project
   metadata, not in game settings or shared translation catalogs.
4. Create a folder such as `res://locale/` for your POT and PO files. Keep game
   translations separate from Nucleus's small built-in common-UI catalogs.

## Example: a translated ability description

In a game's content folder, create a `NucleusLocalizedMessage` Resource:

| Inspector field | Example |
| --- | --- |
| Source | `Deals {damage} damage` |
| Context | `ability_description` |
| Translator comment | `Damage shown in the ability tooltip; preserve {damage}.` |

Save it as `res://game/content/abilities/fire_description.tres`. Add a
`NucleusLocalizedTextBinding` child to the tooltip Label and assign that Resource.
Update its dynamic values through the binding:

```gdscript
$Tooltip/LocalizedTextBinding.set_values(1, {"damage": 25})
```

Do not translate the number or build translatable sentences by concatenating
fragments. The translator can move `{damage}` to suit the language.

### Extract the messages

Save your scenes and Resources first. Click **Add sources** and choose
`res://game/content`. Repeat for the game's UI/scripts folders if required.
Adding a folder records current files; it is not a permanent directory watcher.
Rescan after adding new files. Avoid scanning all framework/test/example content.

Open **Project > Project Settings > Localization > Template Generation > Generate**
and save `res://locale/messages.pot`. Godot extracts its supported scene text and
constant `tr()`/`tr_n()` calls. The enabled addon contributes message Resources.

The panel's **POT workflow** button explains this native step. Godot 4.7.2 exposes
no public full-template generation API, so the addon deliberately does not click
private editor controls or replace native extraction with a partial scanner.
A POT is an inventory, not a translated language file. Dynamically constructed
message IDs need an explicit `NucleusMessageCatalog` inventory.

### Create and translate a language

Click **Choose POT**, select `messages.pot`, enter `es` in **New locale**, then
**Create PO** and choose `res://locale/es.po`. Existing PO files are never replaced
by this action. GNU gettext supplies language-specific plural headers and forms.

Open the PO in Poedit, Weblate or another gettext editor and translate:

```po
#. Damage shown in the ability tooltip; preserve {damage}.
#, python-brace-format
msgctxt "ability_description"
msgid "Deals {damage} damage"
msgstr "Inflige {damage} de daño"
```

Save it. After Godot imports it, click **Register PO/MO** and select `es.po`.
Restart the game and choose Spanish using its language selector: the tooltip
should read `Inflige 25 de daño`. Inspect fonts, layout and truncation visually.
The binding updates on language changes; static native Controls need no binding
unless they need the Resource/dynamic-value workflow.

### Maintain translations as content changes

After adding or editing messages, repeat native POT generation. Select a PO row
and click **Update selected PO**. The shared gettext wrapper preserves existing
translations, adds new entries and marks uncertain matches for review. It retains
obsolete entries using gettext's normal semantics.

Before replacing the PO, it validates temporary output and copies the previous
bytes to `es.po.bak`. If that backup already exists, move/archive it first; the
operation refuses to destroy your previous recovery copy. Concurrent source PO
edits detected during the operation also abort replacement. Temporary catalogs
use hidden folders so Godot does not import partially written files.

Click **Validate / status** to inspect each registered PO:

| Column | Meaning |
| --- | --- |
| Translated | Active messages translated and not fuzzy |
| Pending | Active untranslated messages |
| Review | Fuzzy messages needing human review |
| POT drift | `Update` if the selected template contains unmatched entries; `Unknown` without a POT |
| Status | Gettext syntax/marked-format validation, not linguistic quality |

Select a row to see gettext diagnostics including the file and, when provided by
gettext, line/message details. For example, changing `{damage}` to `{dano}` or
removing it from a marked translation produces a format diagnostic.
Compiled MO files are listed as compiled output: edit and validate their source PO.

The source list highlights missing paths. **Remove missing sources** removes only
missing entries from project settings; it never deletes files. Resource audits
report empty messages and conflicting plural definitions for the same
source/context, including both source files. This audit supplements native
extraction; it does not analyze arbitrary script logic or prove complete coverage.

## Work safely and interpret limits

Catalog jobs run outside the editor process with a per-gettext-command timeout,
so the panel remains responsive. Only one job runs per panel. **Cancel job** or
addon shutdown stops the Python supervisor; already committed output is not
rolled back. A native child process may finish temporary work before its timeout;
it cannot publish a final PO without the supervisor. Interrupted jobs can leave
hidden temporary files, which can be removed after their processes exit.

Save external translator edits before updating. Version your PO/POT files in Git.
Validation does not prove a translation is correct, complete relative to unsaved
content, or visually suitable. Runtime-exported POTs only cover their explicitly
collected messages; they are not substitutes for full editor extraction.

See the [localization API contract](../components/localization_pipeline.md) for
plurals, bindings, runtime template export and command-line alternatives.
