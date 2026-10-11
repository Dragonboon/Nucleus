# Nucleus — agent operating contract

> **Scope:** Nucleus is an agnostic, reusable Godot foundation. It is **not** a
> game, a genre framework, a ready-made starter, or a substitute for Godot.
> An agent's job is to reuse, compose, and validate existing mechanisms—not to
> maximize the amount of new code.

## 0. Mandatory start: CRISP + reuse gate

**CRISP = Context · Role · Inspection · Standards · Proof.** The steps in this
section apply before planning, generating code, changing scenes, or offering a
solution. They also apply to experiments and throwaway prototypes.

| Step | Required behavior |
| --- | --- |
| **Context** | Identify whether this checkout is Nucleus itself or a game derived from it; inspect the real HEAD, local changes, Godot engine pin, and requested scope. |
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
- A derivative's `AGENTS.md` should state its own gameplay requirements, but
  should inherit this reuse/ownership policy. Repository instructions cannot
  guarantee agent compliance: tests and review gates must enforce outcomes.

### First inspection commands (repository root)

```bash
git status --short
git branch --show-current
git rev-parse HEAD
cat VERSION
rg -n 'RelevantNucleusSymbol|target_method|specific_error' core components modules
```

Replace the example expression with actual behavior/API names; `rg` is a
starting point, not a substitute for reading matching implementations. For a
consuming game, inspect `game/` scenes and current `AGENTS.md` too. Never assume
GitHub `main`, the local checkout, an older conversation or a downloaded overlay
all refer to the same revision. Check authorization before changing branches,
files, remotes or publishing commits.

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
   optional `modules/` from a demo, game or convenience fix.
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
| Movement, facing, camera | `components/gameplay/movement/`, `control/`, `camera/` | `docs/components/gameplay_movement_camera.md`; `docs/guides/tutorials/third_person_3d.md` |
| Animation, humanoids, ragdoll | `components/gameplay/animation/` | `docs/components/animation_integration.md`; `docs/components/ragdoll_authoring_3d.md` |
| Input, preferences, UI | `core/input/`, `core/settings/`, `components/ui/` | `docs/guides/settings_input_quickstart.md`; `docs/guides/ui_quickstart.md` |
| Interactions and actions | `components/gameplay/interaction/`, `actions/` | `docs/components/gameplay_foundation.md`; `docs/components/gameplay_actions_attributes_status.md` |
| Audio, save, scenes | `core/audio/`, `core/save/`, `core/scene_flow/` | `docs/components/audio_save_scene_localization.md`; `docs/components/save_system.md` |
| AI, navigation | `modules/ai/` | `docs/modules/ai_navigation.md` |
| Terrain, streaming, oceans | `modules/terrain/`, `components/world/` | `docs/components/world_surfaces.md`; `docs/components/world_buoyancy.md` |
| Networking, authority | `modules/networking/` | `docs/modules/networking.md`; `docs/modules/online_replication.md` |
| Rendering and profiling | `components/world/rendering/`, `modules/performance/` | `docs/components/rendering_quality.md`; `docs/components/runtime_optimization.md` |
| New shared subsystem | `docs/architecture/component_selection.md` | `docs/documentation_coverage.json`; `docs/guides/use_case_catalog.md` |

These paths are **discovery pointers, not proofs of an API**. Read actual
signatures, node requirements, serialization exports and tests. If there is a
conflict between docs, source and current engine behavior, investigate and
report the mismatch; do not invent an interface.

## 2. Godot 4.7 correctness and lifecycle

Reference: the Godot release pinned in `.github/workflows/nucleus-ci.yml` and
`docs/policies/godot_compatibility.md` (currently `4.7.2-stable`). The current
project uses Forward Plus and Jolt Physics. Do not substitute 4.6, Godot 3,
engine `master`, or incompatible GDExtension assumptions. Verify unfamiliar
methods, enums and properties against the pinned engine/API.

- Use explicit GDScript types for uncertain `Variant`/`Error` returns, dynamic
  indexing and `Object.get()`; do not conceal parser warnings with suppressions.
  Do not shadow native properties such as `name`, `owner`, `position`, `basis`,
  `transform`, `rotation`, `scale`, or `visible`.
- Repo style: UTF-8, LF, final newline, tabs in `.gd`, maximum **100 columns**
  in `.gd`; follow `.editorconfig` and `scripts/ci/static_checks.py`.
- `_init()` cannot assume SceneTree, viewport, physics space, imported assets
  or Autoload readiness. Children initialize before their parent's `_ready()`;
  wire dependencies accordingly. Disconnect stale signals and check potentially
  freed references before use.
- Do not mutate shared `Resource` objects as if each actor had a private copy.
  Duplicate runtime profiles/materials when independent state is required.
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
prefix in framework-owned `core/`, `components/` and `modules/` scripts. A
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
7. Update contracts, quickstarts, the use-case catalog or
   `docs/documentation_coverage.json` when the affected public interface or
   subsystem changes. Documentation-only changes do not need a version bump.
8. Run relevant tests, then report **executed** evidence, observed results and
   what remained unavailable. Never invent engine, visual or CI success.

### Baseline checks (run from the repository root)

```bash
python3 scripts/ci/static_checks.py
python3 scripts/ci/documentation_audit.py
python3 scripts/ci/productization_audit.py
python3 scripts/ci/use_case_audit.py
godot --headless --path . --import
godot --headless --path . res://tests/headless/test_runner.tscn
godot --headless --path . res://tests/smoke/smoke_main.tscn
godot --headless --path . res://tests/smoke/resource_loading_smoke.tscn
```

Use the *project scene* test runner so Autoloads exist, not standalone
`godot --script tests/headless/test_runner.gd`. For scene composition, run a
smoke test that instantiates the real consuming scene and asserts the expected
Nucleus components are present, connected and uniquely own their responsibilities.
A static search for `Nucleus` strings alone is not sufficient.

For gameplay, camera, animation, physics, networking, accessibility and visual
work, also run the relevant **real scene/manual/device** tests; a successful
headless parser cannot certify player feel, gamepad, skeleton retargeting,
render quality, frame-time or remote authority. For release-facing changes,
follow `.github/workflows/nucleus-ci.yml` and smoke-export appropriate targets;
source-template export validation is not a release-grade game distribution test.
If the engine, assets, hardware or export templates are unavailable, explicitly
report those checks as **not run**.

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
