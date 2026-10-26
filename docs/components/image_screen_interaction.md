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
