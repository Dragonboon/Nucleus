# Default Accessible UI Theme — Quickstart

> [!TIP]
> New Nucleus projects are already configured to use a native Godot Theme.
> Add a `Control` screen and its Buttons, Labels and inputs immediately inherit
> the base styles — even when the scene is run in isolation.

## Start in Godot

1. Open **Project Settings > GUI > Theme > Custom**.
2. Confirm the default is `res://components/ui/theme/nucleus_base_theme.tres`.
3. Open `res://examples/ui/ui_polish_lab.tscn` and run the current scene (F6).
4. Test a Button with Tab/Enter/Space and mouse hover/press.
5. Open the **Theme & Controls** page and toggle **High-contrast preview**.
6. Check buttons, text input, scrollbars, progress, focus and narrow resizing.

The default theme uses the engine font, larger baseline text, comfortable
control padding and explicit focus/hover/disabled styles. It does not install a
third-party font, require a UI manager or alter gameplay input semantics.

## Use cases

| Building... | Start with |
| --- | --- |
| Pause/settings/options menus | `PanelContainer`, `VBoxContainer`, `Button`, `Label`; styles are inherited. |
| Accessible option toggles | Native `CheckBox`/`CheckButton` with descriptive labels. |
| Text entry and search | Native `LineEdit`; test placeholder and focus legibility. |
| HUD progress bars | Native `ProgressBar` + optional `NucleusUIProgressFeedback`. |
| Controller-friendly navigation | Native focus plus `NucleusUIFocusScope` when needed. |
| Custom game UI | Duplicate the `.tres` and make a game-owned replacement. |

## Customize without affecting other projects

Duplicate the Theme to `res://game/ui/game_theme.tres` and set **GUI > Theme >
Custom** to your copy. If only one screen needs a different design, assign a
Theme to that screen's root `Control` instead of changing the project setting.

> [!IMPORTANT]
> `accessibility/ui_scale` and `accessibility/high_contrast` are preferences,
> not automatic project-wide Theme mutations. Connect
> `NucleusUIAccessibilityBinding` to a screen's Theme/layout policy if your game
> exposes those options. A configurable base theme is always present regardless.

Full contract: [Accessible Native UI Theme Baseline](../components/ui_theme_baseline.md).
Existing UI composition guide: [UI Quickstart](ui_quickstart.md).
