# Nucleus — agent operating contract

> **Scope:** Nucleus is an installable, agnostic Godot addon for existing or new
> projects. It is **not** a game, a project template, a complete genre framework
> or a substitute for Godot.
> An agent's job is to reuse, compose, and validate existing mechanisms—not to
> maximize the amount of new code.

Copy-ready prompts for agents using this contract are in the
[agent prompt playbook](../../docs/guides/agent_prompt_playbook.md) and its
[worked examples](../../docs/guides/agent_prompt_examples.md).

## 0. Mandatory start: CRISP + reuse gate

**CRISP = Context · Role · Inspection · Standards · Proof.** The steps in this
section apply before planning, generating code, changing scenes, or offering a
solution. They also apply to experiments and throwaway prototypes.

| Step | Required behavior |
| --- | --- |
| **Context** | Identify whether this checkout is the Nucleus addon development repository or a consuming game; inspect the real HEAD, local changes, Godot engine pin, and requested scope. |
| **Role** | Act as a principal Godot/gameplay systems engineer: correctness, composability, stable APIs, security, accessibility, performance, and evidence matter more than speed of code generation. |
| **Inspection** | Locate the native Godot facility, existing Nucleus owner, its signature, docs, callers and tests **before** proposing a new implementation. |
| **Standards** | Exactly one owner for writable state; native Godot is authoritative; prefer scene-owned Nodes, Resources, signals, and explicit bindings. Nucleus remains game-agnostic. |
| **Proof** | Verify the *actual composition* and its behavior, not only parsing, file formatting, or test-suite success. Report what was and was not tested. |

### REQUIRED: ownership and reuse decision before implementation

For every new behavior, integration, refactor, or prototype, produce a brief
**ownership map**, in your plan or work notes, before editing:

| Requirement | Godot native owner | Existing Nucleus contract | Game-owned policy / missing capability |
| --- | --- | --- | --- |
| Example: camera orbit and zoom | `Camera3D`, `SpringArm3D` | `NucleusThirdPersonCameraRig3D`, `NucleusLookRig3D` | Isometric angle, rotation limits, input choices |
| Example: character motion | `CharacterBody3D`, `move_and_slide()` | `NucleusCharacterMotor3D`, `NucleusMotionInput` | Sprint conditions, movement balancing |

The examples are **routing examples, not mandatory gameplay implementations**.
For a different genre or control scheme, inspect the relevant contracts instead.

Follow this decision sequence:

1. **Does native Godot already own the primitive?** Keep it as the authority;
   avoid competing implementations of rendering, physics, navigation, skeleton,
   scene management, animation, input hardware, or multiplayer transport.
2. **Does Nucleus already provide the reusable mechanism or adapter?** Inspect
   and compose it. "Godot native first" does **not** mean reimplement an existing
   Nucleus adapter using raw Godot calls.
3. **Is the remaining behavior specific to one game?** Put that policy in the
   consuming game's `game/` code or scenes, not in Nucleus Core or modules.
4. **Is a mechanism genuinely missing?** Document the gap and why native APIs
   and existing Nucleus contracts cannot compose it. Prefer a small adapter,
   profile, focused correction or diagnostic over a new framework/service.
5. **Would the shared addition help two independent consumers?** Only then
   consider a game-agnostic Nucleus public API, with tests and documentation.

**STOP AND RECONSIDER** when a planned script duplicates camera orbit/zoom,
character motion, input normalization, facing, save persistence, scene loading,
settings application, networking authority, or any other mechanism already
owned by Godot/Nucleus. A script being "temporary", "simple", or "only a
prototype" is **not** an exception. A game may replace a Nucleus mechanism when
its documented capability does not meet requirements, but must record the
reason and own the replacement explicitly—never run competing state writers.

Before claiming implementation success, show: **owner selected → code/scene
actually wired to that owner → relevant test → limitations**. Never claim
"Nucleus-first" merely because the repository contains Nucleus files.

### Nucleus versus consuming games

- **Within Nucleus:** publish reusable mechanisms, adapters, diagnostics,
  optional modules and public contracts. Preserve agnosticism across genre,
  camera mode, controller type, art, gameplay, UI design, world and platform.
- **Within a consuming game:** implement gameplay rules, player scenes, cameras,
  content, quest structure, tuning and UX by *composing* appropriate mechanisms.
- Do **not** add game starters, complete game shells, genre-specific player
  controllers, sample campaigns, fixed HUD flows, or prescribed game scenes to
  the public Nucleus foundation. Small **validation/example scenes** are allowed
  only to prove a reusable contract; they must not become required dependencies.
- Do not treat the existence of a `third_person_3d` tutorial as a mandate that
  every consuming game use third person. It demonstrates how to compose Nucleus.
- No new baseline Autoload for convenience. Optional modules must stay optional.
- A game-specific problem is not permission to fork or silently alter the shared
  framework. Propose a backward-compatible general fix separately if justified.
- A consuming game's `AGENTS.md` should state its own gameplay requirements, but
  should inherit this reuse/ownership policy. Repository instructions cannot
  guarantee agent compliance: tests and review gates must enforce outcomes.

### First inspection commands (repository root)

```bash
git status --short
git branch --show-current
git rev-parse HEAD
cat VERSION
cat addons/nucleus/VERSION
cat addons/nucleus/plugin.cfg
rg -n 'GODOT_VERSION' .github/workflows/nucleus-ci.yml
rg -n 'RelevantNucleusSymbol|target_method|specific_error' \
  addons/nucleus/core addons/nucleus/components addons/nucleus/modules
```

Replace the example expression with actual behavior/API names; `rg` is a
starting point, not a substitute for reading matching implementations. For a
consuming game, inspect `game/` scenes and current `AGENTS.md` too. Never assume
GitHub `main`, the local checkout, an older conversation or a downloaded overlay
all refer to the same revision. Work from the intended base revision, preserve
unrelated local edits and record the exact source revision of any consuming game.
APIs present in an unmerged feature branch are not yet available in `main` or a
published addon. Keep code, tests and agent instructions aligned to the same branch.
Proceed within the user's authorized scope; branch updates, publication and merges
must respect that scope. Never merge merely because local tests passed.

## Addon distribution boundary

The distributable boundary is **`addons/nucleus/`**. The root `project.godot`,
`AGENTS.md`, docs, examples, tests, scripts, tools and labs are development-only.
Do not require them from an addon. A consuming game can install only the addon
folder; a complete repository clone is not a runtime dependency.

| Kind of change | Location / constraint |
| --- | --- |
| Baseline runtime services and utilities | `addons/nucleus/core/`; no optional-module dependency |
| Scene-owned reusable adapters | `addons/nucleus/components/`; explicit references and signals |
| Optional subsystems | `addons/nucleus/modules/`; absent modules must not break the baseline |
| Plugin/dock/localization/package management | `addons/nucleus/plugin.gd`, `addons/nucleus/editor/`; editor lifetime only |
| Validation, fixtures and examples | Root `tests/`, `examples/`, `scripts/`; never required by installed code |
| A consuming game's content and policy | Outside the addon, normally `game/` in that repository |

The Nucleus dock owns **Manage** and **Localization**. Do not recreate a separate
`nucleus_localization` plugin or require development scripts to run the installed
editor tools. Inspect [addon management](../../docs/guides/addon_management.md) before
changing profiles, updates or rollback, and [installation](../../docs/guides/installation.md)
before changing integration behavior.

Preserve the host's main scene, InputMap, renderer, physics configuration, audio
layout, settings and other plugins. Baseline Autoload registration must detect
conflicts and remove only entries owned by this addon. Do not add global project
preferences implicitly; opt-in integration is an explicit host decision.

Full/2D/3D inventories are dependency-closed source profiles. Shared UI, core and
editor code remain available in all profiles; a 3D game still needs 2D menus.
Never infer that every `Node2D` or `Control` belongs exclusively to the 2D profile.
Inspect existing class/resource references before introducing cross-profile links.
Do not bypass modified-file checks, host-reference scans, hash/size verification,
immutable update revisions or staged rollback to make an update succeed.

## 1. Architecture invariants

1. **One writable owner.** No competing transforms, animation state, camera
   position, input device routing, inventory balance or replicated authority.
2. **Godot native first, Nucleus composition second, game policy last.** Use
   Godot's primitives without bypassing established Nucleus contracts.
3. **Scene-owned by default.** Compose explicit Node/Resource references and
   signals. Autoload only for demonstrated cross-scene service lifetime.
4. **Composition over inheritance.** Avoid deep generic base classes, global
   registries, hidden dependencies and universal managers.
5. **Six baseline Autoloads only:** `NucleusApp`, `NucleusSettings`,
   `NucleusInput`, `NucleusAudio`, `NucleusSave`, `NucleusSceneFlow`.
6. **Optional stays optional.** Core must not acquire implicit dependencies on
   optional `addons/nucleus/modules/` from a demo, game or convenience fix.
7. **Stable identity and explicit failure.** Async, networking, save/load,
   scene lifetime and editor generation must support cancellation/retry/cleanup.
8. **Intentional APIs.** Public framework `class_name` identifiers start with
   `Nucleus`; project-owned `game/` classes should use the consuming game's
   naming policy. Do not rename them to `Nucleus*` to satisfy an inherited audit.
9. **Measure, do not assert.** Performance, memory, visual quality, multiplayer
   reliability and exports require relevant evidence, not a green parser.
10. **Smallest coherent slice.** Prefer a focused fix, small adapter, removal,
    diagnostic or improved existing component over speculative expansion.

### Find the owner before adding code

| Need | Inspect first | Read alongside source |
| --- | --- | --- |
| Movement, facing, camera | `addons/nucleus/components/gameplay/movement/`, `addons/nucleus/components/gameplay/control/`, `addons/nucleus/components/gameplay/camera/` | `docs/components/gameplay_movement_camera.md`; `docs/guides/tutorials/third_person_3d.md` |
| Animation, humanoids, ragdoll | `addons/nucleus/components/gameplay/animation/` | `docs/components/animation_integration.md`; `docs/components/ragdoll_authoring_3d.md` |
| Input, preferences, UI | `addons/nucleus/core/input/`, `addons/nucleus/core/settings/`, `addons/nucleus/components/ui/` | `docs/guides/settings_input_quickstart.md`; `docs/guides/ui_quickstart.md` |
| Interactions and actions | `addons/nucleus/components/gameplay/interaction/`, `addons/nucleus/components/gameplay/actions/` | `docs/components/gameplay_foundation.md`; `docs/components/gameplay_actions_attributes_status.md` |
| Image-based interaction and navigation | `addons/nucleus/components/ui/interaction/`, `addons/nucleus/components/ui/effects/` | `docs/components/image_screen_interaction.md`; `tests/smoke/point_click_smoke.tscn` |
| Addon/editor/distribution | `addons/nucleus/plugin.gd`, `addons/nucleus/editor/`, `scripts/package_release.py` | `docs/guides/addon_management.md`; `docs/guides/installation.md` |
| Audio, save, scenes | `addons/nucleus/core/audio/`, `addons/nucleus/core/save/`, `addons/nucleus/core/scene_flow/` | `docs/components/audio_save_scene_localization.md`; `docs/components/save_system.md` |
| AI, navigation | `addons/nucleus/modules/ai/` | `docs/modules/ai_navigation.md` |
| Terrain, streaming, oceans | `addons/nucleus/modules/terrain/`, `addons/nucleus/components/world/` | `docs/components/world_surfaces.md`; `docs/components/world_buoyancy.md` |
| Networking, authority | `addons/nucleus/modules/networking/` | `docs/modules/networking.md`; `docs/modules/online_replication.md` |
| Rendering and profiling | `addons/nucleus/components/world/rendering/`, `addons/nucleus/modules/performance/` | `docs/components/rendering_quality.md`; `docs/components/runtime_optimization.md` |
| New shared subsystem | `docs/architecture/component_selection.md` | `docs/documentation_coverage.json`; `docs/guides/use_case_catalog.md` |

These paths are **discovery pointers, not proofs of an API**. Read actual
signatures, node requirements, serialization exports and tests. If there is a
conflict between docs, source and current engine behavior, investigate and
report the mismatch; do not invent an interface.

## 2. Godot 4.7 correctness and lifecycle

Reference: the Godot release pinned in `.github/workflows/nucleus-ci.yml` and
`docs/policies/godot_compatibility.md` (currently `4.7.2-stable`). The current
development project uses Forward Plus and Jolt Physics; those are not settings to
impose on a consuming project. Re-read the pin rather than treating this paragraph
as an engine upgrade instruction. Do not substitute 4.6, Godot 3, engine `master`,
or incompatible GDExtension assumptions. Verify unfamiliar methods, enums and
properties against the pinned engine/API and an actual engine run.

- Use explicit GDScript types for uncertain `Variant`/`Error` returns, dynamic
  indexing and `Object.get()`; do not conceal parser warnings with suppressions.
  Do not shadow native properties such as `name`, `owner`, `position`, `basis`,
  `transform`, `rotation`, `scale`, or `visible`.
- Repo style: UTF-8, LF, final newline, tabs in `.gd`, maximum **100 columns**
  in `.gd`; follow `.editorconfig` and `scripts/ci/static_checks.py`.
- `_init()` cannot assume SceneTree, viewport, physics space, imported assets
  or Autoload readiness. Children initialize before their parent's `_ready()`;
  wire dependencies accordingly. Disconnect stale signals and check potentially
  freed references before use. `_ready()` does not automatically run again when
  an existing Node re-enters the tree: pair teardown with an explicit rebind or a
  deliberate `request_ready()` policy. Test remove/re-add and pending callbacks.
- Do not mutate shared `Resource` objects as if each actor had a private copy.
  Duplicate runtime profiles/materials when independent state is required. Validate
  external IDs, targets and prerequisites before irreversible effects; guard signal
  reentry while committing. Do not describe a multi-owner operation as atomic unless
  failure/rollback tests establish that contract.
- Editor `@tool` generation must preserve authored content, avoid duplicate
  children, use correct saved `owner`, and integrate with native UndoRedo when
  appropriate. Do not fabricate `.uid` values or lose scene references.
- Author assets under `res://`; put mutable saves/config/logs under `user://`.
  Persist stable IDs and bounded schema-aware data, not Nodes, RIDs or Callables.
- Async and threaded jobs require ownership, bounded work, cancellation and
  stale-result protection. `call_deferred()` does not make heavy work cheap;
  do Node/render/physics operations on the appropriate engine phase/thread.
- Keep Godot `AnimationTree`, `Skeleton3D`, `BoneMap`, `NavigationAgent`, physics
  and rendering as owners. Separate animation presentation from authoritative
  character motion; test asset retargeting visually, not only headlessly.
- Separate world-clock authority, scene lights, procedural fields, presentation
  budgets, and render quality policy. Avoid multiple components writing the
  same settings. Prefer measured `MINIMAL/REDUCED/FULL` visual-quality modes.

### Image interaction, multiple resolutions and devices

For image-driven views, reuse `NucleusImageScreen`, `NucleusScreenHotspot`,
`NucleusAdventurePage` and `NucleusAdventureSession`. Read their source, docs and
callers first. These are optional adapters, not a mandatory game shell.

- `NucleusImageScreen` owns image rectangles, hit tests and gesture/focus lifetime.
  Use normalized coordinates relative to the authored image. `_gui_input` already
  supplies local coordinates; use `normalized_viewport_point` for viewport input
  and `image_local_point` for local overlay placement. Do not apply the inverse
  transform twice or maintain independent formulas for hover and activation.
- Keep interactive art, world-item visuals and hotspots under one transform when
  zooming/breathing. Compose `NucleusUISafeArea` for HUD/cutout layout. Keep HUD and
  hardware cursors outside world shader passes. Pixel-displacing shaders still
  require an explicit hit-alignment decision by the game.
- Pages can declare explicit `back_page`, `left_page`, `right_page` links and
  optional navigation bands. Bands default off. Return policy, target sizes,
  priorities, arrows and shortcuts belong to the consumer. Never infer a return
  target from history when the authored contract requires a deterministic link.
- Use `validate_configuration()` before playtesting; opt into return-path checks
  only when the game requires them. Structural reachability does not establish
  conditional puzzle solvability or the correctness of game-resolved aliases.
- Use `auto_activate_hotspots = false` and `hotspot_requested` when game policy
  must intercept an action. Do not run a second activation handler alongside
  automatic activation. Check known consumer subclasses before adding a public
  method, export or signal: even an additive name can collide with a subclass.
- Modal presentation must disable world interaction, block native GUI propagation
  and transfer focus deliberately. Test held-press cancellation across modal,
  page, resize, hide/show, focus-loss and teardown transitions. A second finger or
  an emulated mouse event must not produce an extra action.
- Rebuild the active hotspot list for conditional content instead of merely
  hiding a marker. Pointer, keyboard and joypad must agree about availability.
  Do not mutate shared page/Resource data as per-player state.
- Exercise actual `Viewport.push_input` dispatch with transformed/nested Controls,
  letterboxing, portrait, widescreen, ultrawide, mouse, touch and joypad events.
  Calling a navigation method or a private hit-test helper alone is insufficient.
  Synthetic events prove routing, not physical-device usability or visual polish.

## 3. Security, trust and Nucleus-owned APIs

- Server authority validates sender, actor identity, sequence/rate, ranges,
  cooldowns, resource costs, payload bounds and permission *before* mutating
  gameplay state. A connected peer, valid RPC or matching NodePath is not proof
  of authorization. Transport and gameplay admission are different concerns.
- Replicate compact stable semantic state where possible, not every rendered
  transform, generated vertex or client-authoritative decision. Test packet
  disorder, reconnection and stale messages for networked games.
- Community resources are untrusted. Do not mount PCK/ZIP content without
  verification; use the official Content Packs boundary. Never expose keys,
  tokens, certificates, account credentials or sensitive player data in logs.
- `NucleusSave` owns storage, integrity, codecs, migrations and autosave policy;
  the game owns its capture/restore schema and cloud integration.

Calls controlled by `scripts/ci/static_checks.py` must go through their owner:

| Do not bypass | Existing authority |
| --- | --- |
| `Input.mouse_mode =` | `NucleusCursor` |
| `DisplayServer.window_set_mode`, `window_set_vsync_mode` | `NucleusSettings` display appliers |
| `Engine.max_fps =` | `NucleusSettings` display applier |
| `Input.vibrate_handheld` | `NucleusHaptics` |
| `DisplayServer.screen_set_orientation` | `NucleusMobileOrientationPolicy` |
| `OS.request_permission(s)` | `NucleusMobilePermissions` |
| `ProjectSettings.load_resource_pack` | Verified `NucleusContentPackLoader` |

**Derivative-project class names:** `static_checks.py` requires the `Nucleus`
prefix in framework-owned `addons/nucleus/core/`, `addons/nucleus/components/` and `addons/nucleus/modules/` scripts. A
consuming game's `game/` classes retain its own naming policy. The protected
engine-operation checks still apply; a game-specific prefix does not exempt
code from existing input, settings or content-loading ownership rules.

## 4. Required change procedure and proof

1. Confirm scope, repository, branch, current revision, user authorization,
   acceptance criteria and smallest relevant test. Do not silently rewrite
   unrelated code or switch repository/branch.
2. Present or record the **ownership map** from section 0, including native
   Godot, reused Nucleus contracts, game-specific policy and actual gaps.
3. Inspect source, caller, scene wiring, current docs and tests. Before changing
   public APIs, check `docs/policies/api_stability.md`, `versioning.md` and
   `deprecation.md`.
4. Implement one cohesive change; preserve existing node ownership, serializable
   properties, authored defaults, compatibility and scene/module boundaries.
5. Add regression checks for behavior **and** failure boundaries (null/missing
   references, re-entry, teardown, invalid data, retry/cancel, permissions,
   persistence and authority where relevant).
6. Add new `tests/headless/*_test.gd` to `tests/headless/test_manifest.gd`;
   extend `tests/headless/test_case.gd`, implement `run() -> Dictionary` and
   `return finish()` using repository `expect_*` helpers.
7. Update contracts, quickstarts, the use-case registry/catalog or
   `docs/documentation_coverage.json` when the affected public interface or
   subsystem changes. New public behavior needs usage and failure/migration notes.
   Follow the version policy; if changing the addon version, keep `VERSION`,
   `addons/nucleus/VERSION` and `addons/nucleus/plugin.cfg` consistent.
   Documentation-only changes do not need a version bump.
8. After runtime/editor/resource/UID/version changes under the addon, run
   `python3 scripts/ci/build_addon_manifest.py`, then its `--check` gate. Do not
   hand-edit generated hashes, inventories or dependency lists. Regenerate the
   use-case catalog with its existing builder when its registry changes.
9. Run checks appropriate to the changed owners, then report **executed** evidence,
   observed results and what remained unavailable. A subprocess exit code of zero
   alone does not prove that Godot scripts compiled. Never invent engine, visual,
   device, export or remote-CI success.

### Validation selection (repository root)

Scale verification to the change; do not rebuild every platform for a wording fix.

| Change | Required local evidence where tools are available |
| --- | --- |
| Documentation/agent instructions only | Relevant audits, local links/paths/commands, `git diff --check`; no runtime tests solely for prose |
| Runtime/resource/public API | Static/docs/manifest checks, headless suite and the affected real composition smoke |
| Image interaction/navigation | Above plus `tests/smoke/point_click_smoke.tscn`; isolated known-consumer composition when relevant |
| Editor/install/update/profile behavior | Native editor lifecycle and packaged-addon installation; relevant management/localization checks from CI |
| Release/engine compatibility | Full `.github/workflows/nucleus-ci.yml`, clean package and required target exports; report device/GPU gaps |

Static and documentation gates:

```bash
python3 scripts/ci/static_checks.py
python3 scripts/ci/build_addon_manifest.py --check
python3 scripts/ci/documentation_audit.py
python3 scripts/ci/productization_audit.py
python3 scripts/ci/use_case_audit.py
python3 scripts/ci/build_use_case_catalog.py --check
git diff --check
```

For runtime changes, select the pinned executable already installed or follow
`scripts/ci/install_godot.sh`. Example with `godot` on PATH:

```bash
python3 scripts/ci/run_godot_checked.py godot --headless --path . --import
python3 scripts/ci/run_godot_checked.py godot --headless --path . \
  res://tests/headless/test_runner.tscn
python3 scripts/ci/run_godot_checked.py godot --headless --path . \
  res://tests/smoke/smoke_main.tscn
python3 scripts/ci/run_godot_checked.py godot --headless --path . \
  res://tests/smoke/resource_loading_smoke.tscn
# Include when image interaction/navigation is affected:
python3 scripts/ci/run_godot_checked.py godot --headless --path . \
  res://tests/smoke/point_click_smoke.tscn
```

Use the *project scene* test runner so Autoloads exist, not standalone
`godot --script tests/headless/test_runner.gd`. For scene composition, run a
smoke test that instantiates the real consuming scene and asserts the expected
Nucleus components are present, connected and uniquely own their responsibilities.
A static search for `Nucleus` strings alone is not sufficient. When deriving a fix
from a consuming game, pin its actual branch/revision and test in an isolated copy;
do not silently edit that game's vendor files. Report whether the evidence used
a source overlay, a packaged addon or an unchanged released dependency.

For gameplay, camera, animation, physics, networking, accessibility and visual
work, also run the relevant **real scene/manual/device** tests; a successful
headless parser cannot certify player feel, gamepad, skeleton retargeting,
render quality, frame-time or remote authority. For release-facing changes,
follow `.github/workflows/nucleus-ci.yml` and smoke-export appropriate targets;
source-template export validation is not a release-grade game distribution test.
If the engine, assets, hardware or export templates are unavailable, explicitly
report those checks as **not run**.

### Packaging and integration proof

`python3 scripts/package_release.py` produces a Git-tracked, addon-only ZIP and
SHA-256 sidecar. Stage intended new files before making a local test package so
Git-based packaging does not omit them. `--allow-dirty` is for local tests, not a
reviewed release; a release must identify the exact clean revision tested.

Run installation checks against the **actual archive**, not the development tree:

```bash
python3 scripts/ci/check_addon_installation.py godot \
  "dist/releases/Nucleus-$(cat VERSION).zip"
```

Use the pinned executable and the archive actually generated for this checkout.
Keep root development files out of the installable ZIP. Do not publish a catalog
listing, release, tag or claim release readiness just because packaging succeeded.

### Completion / delivery

Deliver only what the user authorizes. If requested to prepare files without
editing Git: **do not commit, push, open PRs or modify the remote**. For a ZIP
replacement, use root-relative paths, no outer wrapper, `.godot/` cache, import
cache or invented UIDs; check archive contents before delivery.

Final answer contract: **decision / ownership → changed files → executed
proof → limitations → compatibility and next action**. Prefer exact evidence
and narrow diffs, not generic roadmaps, speculative expansions or "AAA-ready"
claims without measured proof.

## 5. Stop signs

Do **not** introduce a custom renderer, physics engine, navigation engine,
AnimationTree replacement, global World/LightManager, universal UI EventBus,
shared DRM key, unverified plugin loader, untrusted client authority, or
unrequested genre-specific mechanics. Do not turn a single consuming game's
needs into a mandatory global service, disable safeguards to pass tests, or
invent performance, export or multiplayer evidence.

**Core acceptance test for every agent contribution:** Can the user point to
the existing owner, see that the final scene/code actually uses it, understand
what belongs to the consuming game, and reproduce the reported validation? If
not, the work is not complete—even if the game runs.
