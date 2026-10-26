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
A missing target page or incompatible version rejects restoration.

## Geometry and accessibility

NucleusScreenHotspot supports normalized rectangles, optional normalized
polygons and optional per-hotspot alpha masks. Polygon vertices are in **image**
coordinates (0-1), not relative to bounds. Alpha images are mapped within the
hotspot rectangle. Use `alpha_threshold` for transparent areas. Use sparse
polygons rather than huge alpha images on low-end devices: alpha image reads
on pointer hit-tests are comparatively expensive.

Input commits on release within the originally pressed target, with drag
threshold and cancellation. Use `focus_next()`, `activate_focused()` or
Godot's ui direction/accept actions for keyboard/gamepad access. Focus
highlighting is drawn over the hotspot bounds; provide game-owned UI text
and translated descriptions from `description_key`. Avoid relying on
color alone for important clues. Test touch, narrow/mobile safe areas,
ultrawide letterboxing and scaled window modes.

## Multiple shaders / filters

A CanvasItem has a single active material. To apply **multiple shaders
sequentially**, use an optional NucleusScreenShaderStack: each enabled
NucleusScreenEffectPass renders the previous pass's texture through a
native SubViewport and a duplicated authored ShaderMaterial. Pass order is
the order of the exported resources. Bind the stack on the session; page
changes select per-page passes and display the resulting texture.

Passes expose semantic stable IDs. `set_uniform(pass_id, parameter, value)`
updates the local material. `get_pass_canvas(pass_id)` returns the pass
TextureRect, so a child NucleusUIShaderEffect can animate the material
parameters with NucleusUIMotion; prefer INSTANCE_UNIFORM or SHARED_MATERIAL
only when intentional. Source shader resources are not mutated by default.

The stack caps concurrent stages (`max_passes`, default 6) and each
intermediate texture dimension (`max_dimension`, default 2048). Each enabled
pass creates a render target and updates continuously; memory and fill rate
scale with pass count and pixels. Use fewer passes, lower dimensions and
static textures on low-end hardware. Do not use a SCREEN_TEXTURE shader in
a pass expecting the prior pass automatically: sample TEXTURE, since
each TextureRect receives the previous pass's output.

Render targets update asynchronously in Godot's render loop. Transition
effects and first-frame presentation must be reviewed visually. Keep logical
hit tests in the source image coordinate space; effect passes must not
geometrically displace interactive objects unless the game explicitly
provides a corresponding input-space transform.

## Checks

- `tests/headless/image_screen_test.gd`
- `tests/headless/adventure_session_test.gd`
- `tests/headless/screen_shader_stack_test.gd`

Also test an actual composed adventure scene on mouse, touch and gamepad
at portrait, 16:9 and ultrawide resolutions. Headless tests do not prove
visual filter order, clipping, first-frame readiness or GPU memory budgets.
