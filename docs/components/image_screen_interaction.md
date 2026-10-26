# Image-screen interactions (optional)

Use `NucleusImageScreen` (Control) for point-and-click adventure images, visual
novel investigation panels, museum kiosks, room photographs and other image-driven
interfaces. It is a scene-owned adapter, not an adventure game framework.

## Ownership

- Native Godot: Control input/focus/layout, Texture2D drawing, themes and UI scaling.
- Nucleus: normalized hit testing, aspect-correct image coordinates, overlap
  priority, release confirmation and atomic screen-data replacement.
- Game: images, puzzle flags, object inventory, navigation graph, scene changes,
  interaction verbs, dialogue, cursor visuals and serialization.

## Wiring

1. Add `NucleusImageScreen` under a fullscreen anchored Control, with its
   parent respecting any desired safe-area UI. Assign an image Texture2D.
2. Add `NucleusScreenHotspot` resources to `hotspots`. Bounds are fractions
   of the **original full image** (0–1 on each axis), not window coordinates.
   Set nonempty unique IDs and optional destination IDs.
3. Connect `hotspot_activated(id, destination)` to game-owned puzzle logic.
   A destination is a semantic ID, **not** an unvalidated resource path.
   Use `NucleusSceneFlow` for actual file-backed scene transitions if needed.
4. Call `set_screen(id, texture, hotspots)` for a screen/image change.
   Invalid inputs leave the previous screen unchanged.
5. Call `activate(id)` from a gamepad/keyboard focus list, accessibility
   overlay or other game-defined navigation. Use normal Godot Buttons and
   focus neighbors for discoverable non-pointer alternatives.

The image is letterboxed to remain fully visible when `preserve_aspect` is true.
Clicks in letterbox bars never activate hotspots. Hotspots stay attached to image
features at arbitrary viewport aspect ratios and during resize; resizing does
not rewrite saved positions. When `preserve_aspect` is false the artwork may
stretch intentionally and hitboxes follow the stretched image.

Overlapping enabled hotspots choose the highest priority; stable authoring order
breaks ties. Input is admitted on press and committed only on release inside the
same hotspot, with a bounded motion threshold. Drag-out, release on another
hotspot, press outside artwork and disabled targets do nothing.

To handle modal dialogue, transitions and cutscenes, set
`interaction_enabled = false` and use a native blocking Control overlay.
For touchscreen use the first contact as a single activation pointer; external
gesture recognizers should suppress this Control when recognizing multitouch.
Do not put a transparent mouse-blocking Control over it unless intentional.

## Limits and tests

This intentionally provides rectangular hit areas, not polygon/pixel masks,
hover tooltips, inventory drag-and-drop, dialogue trees, a scene graph or
keyboard spatial hotspot navigation. Those can be composed with existing
Nucleus interaction, input, localization, Save and UI contracts. The owning
game decides disabled states, conditions, and accessibility descriptions.

Headless regressions: `tests/headless/image_screen_test.gd`.
Also manually validate portrait/ultrawide, DPI scaling, safe area, gamepad,
touch and mouse on target hardware; none can be certified headlessly alone.
