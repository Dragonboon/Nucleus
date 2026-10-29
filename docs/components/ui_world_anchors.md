# World-Space UI Anchors — Nucleus UI Contract

Target: Godot 4.7.2, GDScript. Scene-owned, renderer-neutral UI behavior.

> [!TIP]
> **Use for:** names, health bars, and HUD labels attached to positions in 3D.
> The game decides permissions, occlusion rules, and label styling.

## Scope and ownership

The components in `addons/nucleus/components/ui/presentation/` project world-space positions
into native `Control` widgets, then optionally separate overlapping widgets.

| Class | Responsibility |
| --- | --- |
| `NucleusUIWorldAnchor3D` | World-to-viewport projection, clipping and the visual's final position/visibility |
| `NucleusUIWorldAnchorLayout` | Optional update/admission budgets and coordination of multiple anchors |
| `NucleusUIWorldAnchorLayoutSolver` | Pure, deterministic priority-ordered rectangle placement |

No new Autoload, registry, network protocol, inventory system or global UI manager.
The game owns the 3D entity, the data displayed, the `Control` design, the
camera, and which labels should have priority. Nucleus never assumes that a
visible network entity is authorized to be displayed to a particular user.

## Single label / independent mode

Prepare this composition in the scene (the UI overlay is a plain `Control`, not
a `Container` that overwrites child positions):

```text
GameSession
├── World
│   ├── Camera3D
│   └── Npc (Node3D)
├── CanvasLayer
│   └── Overlay (Control, full viewport rect)
│       └── NpcName (Label, fixed/nonzero size)
└── NpcWorldAnchor (NucleusUIWorldAnchor3D)
```

Assign from the Inspector:

```text
NpcWorldAnchor.world_target = Npc
NpcWorldAnchor.camera = Camera3D
NpcWorldAnchor.overlay = Overlay
NpcWorldAnchor.visual = NpcName
NpcWorldAnchor.update_automatically = true
```

The default `alignment = Vector2(0.5, 1.0)` centers the label horizontally
and places its bottom edge at the projected world position. Add a `world_offset`
for a character's head, plus `pixel_offset` for final art-directed placement.
Set `maximum_distance` to a positive value for range-based visibility; `0`
disables that check.

The anchor automatically hides its `visual` when any required binding is absent,
the world point is behind the camera, outside the current Viewport (if clipping
is enabled), beyond maximum distance, or the coordinate transform is invalid.
It does not perform occlusion tests against level geometry. Add that policy in
the consuming game, e.g. a deliberately budgeted raycast or gameplay visibility
check.

## Multiple labels / layout mode

Add one `NucleusUIWorldAnchorLayout` to the scene. Assign its `overlay` and
an ordered list of `anchors`, highest priority first. Each anchor must reference
the same overlay. On managed anchors set `update_automatically = false` so that
only the layout schedules projection passes. This avoids duplicate per-frame
projection work.

The layout runs `refresh_layout()` automatically every frame by default, or at
an authored `update_interval`; call it directly for event-driven updates. Limits:

- `maximum_projection_checks`: at most this many unique anchors are projected
  per pass. The rest are explicitly hidden, not left in stale positions.
- `maximum_visible_labels`: upper bound on candidate visuals considered for
  layout (the solver may hide more if they cannot fit).
- `padding`: requested separation between rectangles in overlay pixels.
- `maximum_lift`, `lift_step`: permitted upward displacement / resolution.

The solver clamps rectangles to the overlay bounds; later entries are moved up
in deterministic steps where possible, then hidden if no free space exists.
It never expands a budget, silently moves labels off the overlay or alters the
priority order. This is intentionally a lightweight screen-space solution,
not a global optimal label-placement system.

## Coordinate and transform rules

`Camera3D.unproject_position()` returns points in the camera Viewport's
coordinate space. The anchor then transforms those points to overlay-local
coordinates using `Control.get_global_transform_with_canvas().affine_inverse()`.
This supports typical CanvasLayer HUD transforms and viewport-aware resizing.

**Required:** camera and overlay belong to the *same Viewport*, and `visual`
is a **direct child** of `overlay`. Split-screen cross-Viewport rendering or
ViewportTexture compositing requires a game-owned mapping adapter; this baseline
intentionally hides invalid combinations rather than guessing coordinates.

Keep the overlay stretched to the usable HUD region and its children outside
Godot layout Containers that continuously rewrite `position`. Use an inner
visual child for tweens, hover feedback, health bars and theme styling:

```text
Overlay
└── NameplatePosition (Control)    # NucleusUIWorldAnchor3D writes position
    └── NameplatePresentation      # presenter/feedback animations own transforms
        └── HealthBar / Label      # game-owned Theme/content
```

The `visual` must have a nonzero measured size for collision avoidance.
For dynamic text, refresh after its size has settled; layout calculation and
`Control` measurement are both on the main thread. If size changes, the next
refresh recomputes placement.

## Runtime and accessibility

- Prefer moderate update cadences and tight budgets for crowds; measure with the
  Nucleus sampler before raising them.
- The layout uses O(N) admission/hiding and a simple occupied-rectangle scan;
  collision checks can become quadratic in the admitted visible count.
- Do not display secret/hidden actors based on client-only interest heuristics;
  network admission and entity visibility remain authoritative game policy.
- The component does **not** take keyboard focus or modify `mouse_filter`;
  keep accessible labels, contrast, scaling and input semantics in native UI.
- Do not animate the same `position` on the directly anchored Control. Animate
  a descendant, or use an inner presentation root.
- Enabling layout while anchors remain `update_automatically = true` is valid,
  but it causes redundant projection work and may increase update cost.

## Test coverage

`examples/ui/world_anchor_lab.tscn` is a standalone moving-entities visual
fixture requiring no imported game art.

`tests/headless/ui_world_anchor_test.gd` checks projection (including behind-
camera, off-screen and range cutoff), alignment and layout reset, deterministic
collision placement, bounds/candidate caps and stale-label hiding. Run:

```bash
python3 scripts/ci/static_checks.py
godot --headless --path . --import
godot --headless --path . res://tests/headless/test_runner.tscn
```

The headless suite checks state contracts. Actual CanvasLayer scaling,
viewports, crowds, DPI, split-screen and frame-time budgets require a real
rendered build and representative device testing.

## Use cases

| Scenario | Use the anchor | Game responsibility |
| --- | --- | --- |
| Character names and health bars over actors | Project world points and manage label overlaps | Team/name/health visibility permissions |
| Mark interactable items near the camera | Hide behind-camera and offscreen targets | Which item is interactable and its prompt |
| Show multiple quest objectives in 3D | Bound update rates and screen overlap | Quest state, prioritization and HUD styling |

The anchor is a presentation bridge; it does not replicate gameplay state,
enforce network visibility or do a ray-occlusion pass automatically.
