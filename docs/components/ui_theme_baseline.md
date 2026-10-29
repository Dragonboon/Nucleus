# Accessible Native UI Theme Baseline

> [!IMPORTANT]
> The project already uses `res://addons/nucleus/components/ui/theme/nucleus_base_theme.tres`
> at startup through **Project Settings > GUI > Theme > Custom**. You do not
> need to assign a Theme to every screen. Any screen may override it locally.

## Why this exists

The initial Godot game UI should be legible, keyboard/gamepad-navigable and
reasonably comfortable before a designer creates a visual identity. Nucleus
provides a neutral, editable **Godot Theme Resource**, not a replacement UI
framework, mandatory font, sprite pack, color-branding system or runtime
UI singleton. It uses built-in `StyleBoxFlat` and the engine fallback font.

| Resource | Behavior |
| --- | --- |
| `addons/nucleus/components/ui/theme/nucleus_base_theme.tres` | Enabled as the project default. |
| `addons/nucleus/components/ui/theme/nucleus_high_contrast_theme.tres` | Optional local or game-wide replacement. |
| `examples/ui/ui_polish_lab.tscn` | Unified theme, accessibility and interaction acceptance. |
| `tests/headless/ui_default_theme_test.gd` | Startup setting, state/contrast and Theme-contract regression. |

## Baseline UI decisions

- **18 px** default fallback font size. No bundled third-party fonts.
- Native Button, OptionButton, MenuButton, CheckBox, CheckButton, LineEdit,
  TextEdit, Panel/PanelContainer, PopupMenu, lists, tabs and ProgressBar styles.
- Comfortable button and input padding; **do not rely on the Theme alone** for
  minimum target sizes in compact, icon-only, touch or custom widgets.
- Clear hover, press, disabled and keyboard/gamepad **focus ring** states.
- Text-on-control contrast targets WCAG AA normal text (at least **4.5:1**)
  on the explicitly styled baseline surfaces; see the headless color checks.
- Neutral layered surfaces with a restrained focus/selection highlight.
- Scrollbars and separators use native, shared dark/high-contrast tokens.
- ProgressBar fill contrasts with its track at **3:1 or greater**, checked in
  the headless theme suite alongside normal text contrast.
- Remaining, unstyled Godot Theme items fall back to native defaults, including
  stock icons. This is intentional for forward compatibility.

> [!WARNING]
> A Theme is not an accessibility certification. Target size depends on actual
> layout, screen DPI, responsive sizing, icon dimensions, touch input and
> device settings. Validate with keyboard, controller, touch and readable
> language strings at supported resolutions. Disabled text and decorative
> surfaces are not claimed to meet the same contrast threshold.

## Use cases

| Need | Recommended composition |
| --- | --- |
| A newly generated settings menu | Native `Control`/`Container` widgets; the project Theme is automatic. |
| A HUD with a game's own visual identity | Duplicate the base Theme or use a Theme on the HUD root. |
| A simple pause menu | Native Button, PanelContainer and FocusScope; no style scripts needed. |
| A settings screen with larger text | `NucleusUIAccessibilityBinding` + scene-owned spacing/layout logic. |
| A game with high-contrast preference | Select the alternate native Theme on a UI root. |
| An editor/plugin interface | Follow editor/native Theme conventions; do **not** force the game Theme into the Godot editor. |

## Editing the Theme

1. Open `addons/nucleus/components/ui/theme/nucleus_base_theme.tres` in the Godot Inspector or
   Theme Editor. Adjust StyleBoxes, fonts, colors and control-specific constants.
2. Keep the project theme path in **Project Settings > GUI > Theme > Custom**.
3. For a game's identity, **Duplicate** the resource before editing, save it in
   a game-owned path and point the project setting to the replacement.
4. Preserve clearly differentiated normal, hover, pressed, disabled and focus
   states. Do not encode essential information through color alone.
5. Run `examples/ui/ui_polish_lab.tscn`, inspect keyboard/gamepad focus and resize
   the viewport. Validate in both light/dark backdrops where the game uses them.

The resource is not modified by `NucleusSettings`; engine project startup owns
its baseline. A local `Control.theme` overrides the global theme for a subtree.
Setting `Control.theme = null` restores the project fallback. Engine-native
Theme inheritance and type variations remain authoritative.

## Existing accessibility preferences

`NucleusUIAccessibilityBinding` emits `ui_scale_changed` and
`high_contrast_changed`. They communicate the player's **intent**; the game
retains responsibility for choosing a palette and a responsive scaling policy.
The high-contrast resource shipped by Nucleus is a neutral starting option.

For one game's screen, an opt-in local hookup looks like this:

```gdscript
const BASE: Theme = preload("res://addons/nucleus/components/ui/theme/nucleus_base_theme.tres")
const HIGH: Theme = preload("res://addons/nucleus/components/ui/theme/nucleus_high_contrast_theme.tres")

@onready var screen: Control = $Screen
var ui_scale: float = 1.0
var high_contrast: bool = false

func on_ui_scale_changed(value: float) -> void:
    ui_scale = value
    apply_preferences()

func on_high_contrast_changed(enabled: bool) -> void:
    high_contrast = enabled
    apply_preferences()

func apply_preferences() -> void:
    var source: Theme = HIGH if high_contrast else BASE
    var local_theme := source.duplicate(true) as Theme
    local_theme.default_font_size = roundi(18.0 * ui_scale)
    screen.theme = local_theme
    # Also adjust the screen's responsive spacing and target sizes explicitly.
```

Connect `on_ui_scale_changed` and `on_high_contrast_changed` to the corresponding
`NucleusUIAccessibilityBinding` signals in the screen scene. Do not mutate the
shared preloaded Resources: that would affect unrelated screens. The snippet
scales the fallback font, **not all layout dimensions**. A real screen must
adapt its spacing, icons, safe areas and touch targets separately.

Do not attach one of these scripts globally just to make the base Theme work.
The global visual default is already selected in `project.godot`.

## Test boundaries

`tests/headless/ui_default_theme_test.gd` checks registration, Theme items,
focus outlines and selected normal-text contrast pairs. It does not evaluate
font glyph coverage, DPI, input focus sequences, renderer differences or the
visual quality of exported builds. Run the lab on target devices.

Manual review sequence:

1. Run `res://examples/ui/ui_polish_lab.tscn` with F6.
2. Tab/Shift+Tab through the controls; inspect focus at normal and high contrast.
3. Test mouse hover, click, disabled state, popup and text selection.
4. In the **Theme & Controls** page, toggle high contrast locally, then return
   to the project default.
5. Resize to narrow and wide layouts; confirm nothing important is clipped.
6. Test at the game's supported language and text-size configurations.
