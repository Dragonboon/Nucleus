# Image-driven adventures and screen effects

Nucleus supports optional scene-owned image pages without changing its six
baseline Autoloads. The game owns its room graph, dialogue, art and narrative.

## Composition

Use a fullscreen NucleusImageScreen and an optional NucleusAdventureSession.
Author NucleusAdventurePage resources with unique IDs, source Texture2D,
NucleusScreenHotspot entries and optional NucleusScreenEffectPass entries.
Assign a NucleusInventory with its own catalog if item actions are needed.
NucleusAdventureSession exposes page_changed, message_requested,
action_rejected and state_changed to the game's UI and dialogue systems.

`change_page(id)` resolves **only authored page IDs**; never interpret a
player-controlled ID as a resource path. Navigation actions can use
NucleusScreenAction.next_screen, while an ordinary hotspot destination
is also interpreted as a page ID. Missing destinations fail without a page
change. Required/forbidden flags, required/consumed items, one-shot actions
and granted items are configured in NucleusScreenAction.

NucleusScreenCombination is a two-item unordered recipe, not a general
crafting system. Place combinations on the session and call
`combine_items(first, second)`. Inventory remains the authoritative holder
of amounts, definitions and persistence. To save, register Inventory as
another NucleusSaveSession participant and restore it **before** the adventure
session if the game requires restored item presentation during page signals.
NucleusAdventureSession registers its own `capture_state/restore_state`;
saves contain page IDs, visited pages, flags and completed interactions.
A missing target page, malformed flag dictionaries or incompatible version
rejects restoration. Hotspot resources are authored data and are not copied
into save files; the game should not mutate shared Resource instances as
per-player state.

## Geometry and accessibility

NucleusScreenHotspot supports normalized rectangles, optional normalized
polygons and optional per-hotspot alpha masks. Polygon vertices are in **image**
coordinates (0-1), not relative to bounds. Alpha images are mapped within the
hotspot rectangle. Use `alpha_threshold` for transparent areas. Use sparse
polygons rather than huge alpha images on low-end devices: alpha image reads
on pointer hit-tests are comparatively expensive. Mask images are cached after
first access; replacing the mask Resource invalidates the cache, but mutating
the pixels of the same Texture2D in place requires assigning a new resource.

Input commits on release within the originally pressed target, with drag
threshold and cancellation. Use `focus_next()`, `activate_focused()` or
Godot's ui direction/accept actions for keyboard/gamepad access. Focus
highlighting is drawn over the hotspot bounds; provide game-owned UI text
and translated descriptions from `description_key`. Avoid relying on
color alone for important clues. Test touch, narrow/mobile safe areas,
ultrawide letterboxing and scaled window modes.

## Multiple shaders / filters

`NucleusScreenShaderStack` provides two optional, native Godot rendering backends.
The default remains `VIEWPORT_CHAIN` for backwards compatibility. Choose the
backend explicitly; neither mode changes puzzle state, hotspot coordinates or
the game's UI policy.

- `VIEWPORT_CHAIN` applies CanvasItem materials to successive `SubViewport`
  textures and exposes the result through `output_texture()`. These shaders
  sample the incoming image with `TEXTURE`; the pipeline can render at a bounded
  resolution (`max_dimension`, default 2048).
- `BACKBUFFER` inserts ordered `BackBufferCopy` / `ColorRect` pairs under
  `backbuffer_target` (or its parent Control). Every copy captures the previously
  drawn canvas before the next screen-reading filter. This mode operates
  **in-place**: `output_texture()` still returns the original source texture.
  The shader must explicitly use a `sampler2D` with `hint_screen_texture`,
  not `TEXTURE`, to read the preceding pass.

For `BACKBUFFER`, assign the same image Control used by
`NucleusImageScreen` as the target, and keep the adapter outside overlays.
Godot draws the image before its children, so copies and filters are applied
after the image without altering its interactive geometry. Additional authored
siblings, CanvasLayers or screen-reading shaders outside this chain can affect
capture order. Keep HUD, captions, cursor and input panels outside the filtered
image Control when they must remain untouched. No implicit CanvasLayer or global
filter service is created.

`backbuffer_full_viewport = true` is the safe default for screen-reading
shaders. Rectangular copies are opt-in; pixels outside the copied region are not
guaranteed to contain the previous pass. `BackBufferCopy` does **not** expose
the processed output as a reusable texture; use `VIEWPORT_CHAIN` for thumbnails,
texture exports, viewport isolation, postprocessing at a different resolution or
visuals that must not sample neighboring canvas content.

Both paths validate `max_passes` (default 6), duplicate materials per session,
retain authoring order and offer `set_uniform(id, name, value)`.
`get_pass_material(id)` returns the local material. In viewport mode,
`get_pass_canvas(id)` returns the corresponding TextureRect; in backbuffer
mode use `get_pass_overlay(id)` or `get_pass_canvas_item(id)` for the ColorRect.
A `NucleusUIShaderEffect` can animate that CanvasItem without duplicating the
render pipeline, provided material ownership is configured accordingly.

Backbuffer copies, just like render targets, consume GPU memory and bandwidth.
Never assume they outperform SubViewport passes without benchmarking the actual
shader, device and resolution. Shader displacement can visually relocate objects
while the original normalized hotspots remain in place. The game must either
avoid such transformations on interactive art or explicitly account for them.

Example screen shader for `BACKBUFFER`:

```glsl
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
void fragment() {
    COLOR = texture(screen_texture, SCREEN_UV);
}
```

## Visual and lifecycle verification

Run the headless suite for validation and failure boundaries, then test a real
composed scene at portrait, 16:9 and ultrawide with one and several passes.
Check the exact filter order, UI isolation, material independence, resize,
first-frame readiness, touch hit alignment and reduced-motion settings.
A passing parser/headless suite alone cannot certify GPU performance or
the screen texture contents.

## Maintenance boundaries

NucleusImageScreen owns pointer-to-image coordinate conversion and focus;
NucleusAdventureSession owns logical page/flag progress and delegates item
balances to NucleusInventory and storage to NucleusSaveSession. No additional
Autoload or generic dialogue/quest framework is required. Existing Godot
Controls, NucleusUIFocusScope and NucleusUIShaderEffect remain the right
owners for UI layout, accessibility prompts and individual shader parameter
animation. Do not replace those components with competing implementations.

The architecture stays opt-in. Tests must cover lifecycle, save validation,
missing resources, viewport changes and shader pass budgets before a release.

## Checks

- `tests/headless/image_screen_test.gd`
- `tests/headless/adventure_session_test.gd`
- `tests/headless/screen_shader_stack_test.gd`

Also test an actual composed adventure scene on mouse, touch and gamepad
at portrait, 16:9 and ultrawide resolutions. Headless tests do not prove
visual filter order, clipping, first-frame readiness or GPU memory budgets.

## Reliable navigation authoring (0.40)

The Internet-Cabin development branch exposed failures shared by image adventures:
small return targets, stale presses after modal/page changes, transformed images,
touch cancellation and keyboard-only focus routing. The shared fixes live in the
existing owners; no game content, two-slot inventory policy, cursor artwork,
mandatory HUD, breathing animation or VHS preset is installed by Nucleus.

| Responsibility | Owner |
| --- | --- |
| GUI dispatch, canvas transforms, input mapping | Godot `Control`, `Viewport`, `InputMap` |
| Image mapping, target selection, gesture lifetime and focus | `NucleusImageScreen` |
| Authored links and optional edge regions | `NucleusAdventurePage` |
| Page/flag progress and action execution | `NucleusAdventureSession` |
| Modal order, item selection, conditional hotspot lists, hints, art and cursors | Consuming game |
| Display cutouts and safe layout | Compose `NucleusUISafeArea`; do not invent a second mapper |

### Explicit return paths and optional edges

A page can declare `back_page`, `left_page` and `right_page`. These contain real
page IDs, not paths or aliases. `session.go_back()` follows the current page's
explicit `back_page`; it never guesses from visitation history. The same view
therefore has a stable return target when revisited or loaded from a save.

Edges are **off by default**, preserving existing authored layouts. Set
`navigation_edge_fraction = Vector2(0.07, 0.065)` to opt into side bands of 7% of
the image width and a bottom return band of 6.5% of its height. Only nonempty
links generate regions. Side regions exclude the bottom band when back is present.
These values are examples; tune usable touch targets for your artwork and devices.
An image that becomes very small in portrait may require a larger band or native
UI Buttons inside a safe-area container. Do not stretch art to make it fit.

```gdscript
var detail := NucleusAdventurePage.new()
detail.id = &"detail"
detail.image = detail_texture
detail.back_page = &"room"
detail.navigation_edge_fraction = Vector2(0.07, 0.065)
session.pages = [room_page, detail] # Bind before entering the SceneTree.
```

`page.screen_hotspots()` returns a fresh array including generated regions without
modifying the shared authored array. Defaults: `side_navigation_priority = -100`
lets ordinary object hotspots win over side navigation;
`back_navigation_priority = 100` makes a reserved return strip easy to reach.
Higher-priority authored regions can still override it, so reserve the strip or
choose priorities deliberately. IDs beginning `nucleus:nav:` are reserved when
edge generation is enabled. Generated entries use the same hit test and activation
path as authored hotspots. They remain active when game-owned arrows are hidden.
No arrows, key bindings for Backspace/TAB or history policy are added implicitly.

### Validate the graph before playtesting

```gdscript
var issues := session.validate_configuration(true)
for issue in issues:
    push_error(issue)
```

This method works before `_ready()`, using the authored `pages` array. It reports
invalid/duplicate pages, a missing initial page, unknown destinations and pages
unreachable from the entry. Passing `true` additionally requires every page to
have a structural path back to the entry; leave it false for valid one-way
sequences or terminal pages. Hotspot actions use `next_screen`; plain hotspots use
`destination`. Declared side/back links are also included, even with edge generation
off, because the game can expose them as Buttons.

These are structural diagnostics, not a solver: flags, item requirements,
one-shot actions, conditional visibility and game-resolved aliases need gameplay
acceptance. They are not an automatic startup rejection or a guarantee that a
puzzle is solvable. A callback cannot re-enter `change_page` or `restore_state`
while another page change/action is committing (`ERR_BUSY`). Invalid target-page
content is rejected before flags/items for that navigation action are modified.
Inventory adapters must still honor their own mutation contract; this does not
introduce a transaction spanning arbitrary external adapters.

### Route through game policy without subclassing

Leave `auto_activate_hotspots = true` for direct session activation. If a game
needs selected-item checks, dynamic links, conditional interactions or an inspection
panel, set it to false and connect `hotspot_requested(id, destination)`:

```gdscript
func _on_hotspot_requested(id: StringName, _destination: StringName) -> void:
    if can_use_selected_tool(id): # Game-owned policy, with localized hints on denial.
        var result := session.activate_hotspot(id)
        if result != OK:
            show_action_error(result)
```

No action runs automatically in this mode. Call the existing `activate_hotspot`
only after policy accepts, or `change_page` with a resolved real page ID. Do not
connect both an independent activation handler and automatic session activation.
Existing `_on_hotspot` subclasses continue to work, but new games do not need to
subclass merely to intercept a request.

### Coordinates, touch, modals and conditional content

- `_gui_input` positions are already local to the image Control. Feed viewport
  positions from a separate game/tool handler through
  `screen.normalized_viewport_point(position)`, which uses Godot's inverse canvas
  transform and rejects a singular transform. `image_local_point(normalized)` is
  the inverse mapping for local overlays. Reuse these for hover/cursors and item
  rendering instead of maintaining independent pixel formulas.
- Keep art, world items and hotspots under the same transform when zooming or
  breathing. Keep HUD, prompts and native hardware cursors outside the shader
  chain. Pixel-displacing shaders still require game-owned hit-alignment policy.
- The first pointer to start owns the gesture, regardless of touch index. Another
  finger cannot release it. OS-canceled touch and emulated duplicate events do not
  activate. Moving beyond tap slop cancels even if the pointer comes back.
- Disable `screen.interaction_enabled` before opening a modal, enable it on close,
  and give the modal a native GUI barrier (`MOUSE_FILTER_STOP`) and appropriate
  focus. Disabling, hiding, resizing, leaving the tree or losing application/focus
  cancels pending presses; reopening cannot resurrect them. Disabling interaction
  remains the game-owned gate, not a competing pause service.
- Assign a new `screen.hotspots` array when conditional visibility changes. This
  cancels stale presses and clears focus. Hidden objects must be removed or
  disabled for both pointer and keyboard/gamepad paths. Do not merely hide a marker
  or mutate a shared Resource as per-player state.
- Direction/accept actions work for keyboard and joypad through the focused
  Control. A real input event is handled by one owner; UI modals keep their own
  focus. Use `description_key` for a game-owned accessible label. Minimum target
  sizes, contrast, text scaling and focus visibility still require device testing.

### Compatibility and reproducible acceptance

Existing links, normalized rectangles/polygons, `preserve_aspect`, signals, action
rules and version-1 adventure saves retain their meaning. New edge links/regions
and manual interaction routing are optional. The only stricter data validation
rejects nonfinite/out-of-image polygon values and invalid alpha thresholds.
Regenerate malformed authored data instead of relying on undefined hit tests.

Run `res://tests/smoke/point_click_smoke.tscn` through the checked-engine runner.
Its real scene wires one screen and one session, then sends viewport mouse, touch
and joypad events at 640×480, 1280×720, 2560×1080, 720×1280, 480×320 and 3840×2160.
It checks return bands, letterboxing, zoom/translation alignment, cancellation,
secondary fingers, emulated duplicates and a modal barrier. Headless suites also
exercise graph diagnostics, manual routing, invalid destination content and reentry.
These checks are input/layout evidence, not physical mobile/gamepad, GPU/shader,
4K performance or release-export certification. Run a real-device playthrough and
check all authored object masks and return routes before shipping.

Source case study: Internet-Cabin `feat/visual-continuity-cabin-frames`, reviewed at
`ec9676f4949982db5c1e2ec075e693706c9e71d8`; its content and UI choices stay game-owned.
