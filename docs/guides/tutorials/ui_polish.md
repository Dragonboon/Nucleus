# Tutorial: UI Polish with Accessible Defaults

This tutorial builds a small menu/HUD using native Godot layout/Theme plus Nucleus
presentation helpers.

The single `examples/ui/ui_polish_lab.tscn` now includes a Theme & Controls
page for native control states and high-contrast preview, in addition to its
interaction, motion, input, accessibility and overlay pages.

## 1. Separate layout from animated transforms

```text
Container
└── LayoutSlot
    └── PresentationRoot
        └── FeedbackRoot
            └── Content
```

The Container owns `LayoutSlot`. Presenter motion owns `PresentationRoot`.
Interaction feedback owns `FeedbackRoot`.

## 2. Add show/hide presentation

Use `NucleusUIPresenter` with a `NucleusUITransitionProfile` such as `fade_only`,
`pop` or `slide`. Keep complex authored sequences in `AnimationPlayer`.

## 3. Add interaction states

`NucleusUIInteractionFeedback` + `NucleusUIFeedbackProfile` can provide hover,
focus, pressed and selected motion/opacity cues while Theme remains the owner of
fonts, colors, icons and StyleBoxes.

## 4. Add progress feedback

Compose primary/trailing `Range` controls with `NucleusUIProgressFeedback`. Use
`NucleusUIValuePoolProgressBinding` when the source is a `NucleusValuePool` so
the HUD remains signal-driven.

## 5. Add input glyphs with fallback text

Use a game-owned `NucleusInputGlyphProfile`, then bind a `TextureRect` and optional
Label with `NucleusInputGlyphBinding`. Verify keyboard/gamepad hot-swap and at
least one missing-glyph case so text fallback remains usable.

## 6. Respect reduced motion and flash preferences

Every Nucleus motion profile can reduce or eliminate nonessential displacement.
Full-screen flash effects should respect the screen-flash intensity preference.
Test the scene with Reduced Motion enabled rather than treating accessibility as
an options-menu-only feature.

## 7. Apply UI scale and high contrast through game presentation

Compose `NucleusUIAccessibilityBinding` at the UI root. Use emitted values to
select/tune a game-owned Theme and responsive spacing policy.

Do not solve UI scaling with one root `Control.scale`; Containers, anchors and
safe-area logic should continue to own layout.

## 8. Coalesce expensive refresh bursts

When multiple source signals invalidate the same panel, route them to
`NucleusUIRefreshCoalescer.request_refresh()` and perform one update from
`refresh_due`.

Do not coalesce focus, confirmation or modal ownership.

## 9. Validate

Run `examples/ui/ui_polish_lab.tscn` with mouse, keyboard and controller. Check:

```text
focus visibility
hot-swap prompts/glyphs
reduced motion
minimum/maximum UI scale
high-contrast theme variant
text fallback
no transform contention
```

Technical contracts: [`../../components/ui_and_accessibility.md`](../../components/ui_and_accessibility.md)
and [`../../components/accessibility_preferences.md`](../../components/accessibility_preferences.md).
