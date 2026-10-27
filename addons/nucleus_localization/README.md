# Nucleus Localization

Optional Godot editor addon, disabled by default. Enable it under Project Settings
> Plugins, then open the **Localization** bottom panel.

- Register native PO/MO catalogs and source folders.
- Create a locale and update PO files using GNU gettext, with backups.
- Inspect translated/pending/fuzzy counts and file-specific validation diagnostics.
- Detect missing sources and conflicting Resource message definitions.
- Extend Godot's native POT generator with `NucleusLocalizedMessage` Resources.

Python 3 + GNU gettext are needed only for catalog management, not for the game.
Full POT generation remains in Godot's native Localization dialog.

Start with the [step-by-step game workflow](../../docs/guides/localization_workflow.md).
For API details, see [the contract](../../docs/components/localization_pipeline.md).
