# Nucleus: agent entry point

Nucleus is an installable, game-agnostic Godot addon. Preserve that boundary.
This file is the compact mandatory entry point; retrieve detailed context only
for the owners affected by the task.

## Start every feature with evidence

1. Inspect `git status --short`, branch, HEAD, `VERSION`, the addon version and
   `.github/workflows/nucleus-ci.yml`. Never treat an unmerged API as available
   on main. Preserve unrelated work and stay within user authorization.
2. Find the owner before coding:

   ```bash
   python3 tools/development/nucleus_dev.py context NucleusAdventureSession
   ```

   Replace the query with the actual class, path or English capability keywords.
   This uses existing coverage/routes, source declarations and dependency inventory.
   References locate evidence; they do not prove behavior. Read the returned owner,
   signatures, relevant guide, callers and tests. Native Godot is authoritative.
3. Record a small feature contract: problem/acceptance, state owner, reused
   components, genuinely missing mechanism, compatibility, and proof scene/test.
   Use [the feature template](docs/guides/agent_workflow.md#feature-contract).
4. Implement the smallest coherent slice. Reproduce a defect before changing its
   owner. Do not replace a working mechanism merely because a new one is easier
   to generate. New shared capabilities need two independent consumer scenarios.

## Non-negotiable architecture

- One writable owner per state/transform/animation/input/inventory authority.
  Godot primitive first, existing Nucleus adapter next, game-specific policy last.
- Runtime lives in `addons/nucleus/core`, `components` and optional `modules`.
  Editor/dock/localization code lives in `addons/nucleus/editor` and `plugin.gd`.
  Root docs/examples/labs/tests/tools are development-only. The installed addon
  must work in an existing host project without a repository clone.
- Keep scene-owned Nodes, Resources, explicit references and signals. No new
  baseline Autoload: only NucleusApp, NucleusSettings, NucleusInput, NucleusAudio,
  NucleusSave and NucleusSceneFlow. No universal managers, parallel save/render/
  physics/input implementations, mandatory game shells or genre defaults.
- Preserve host main scene, InputMap, settings, audio layout, renderer and physics.
  Keep optional modules optional and shared UI available in 2D/3D profiles.
- Never mutate shared Resources as per-player state. Validate before effects;
  guard reentry, cancellation, freed references, teardown and tree reentry.
- Stable IDs, explicit errors and compatible serialization are public contracts.
  Inspect known subclasses/consumers: additive API names can also collide.
- Framework public classes use `Nucleus`; game-owned classes keep game naming.
  Existing protected native operations must use their Nucleus owner. See the
  [ownership/security rules](docs/guides/agent_development_contract.md#3-security-trust-and-nucleus-owned-apis).
- Use the pinned Godot version, explicit uncertain Variant/Error types, tabs and
  at most 100 columns in GDScript. Do not suppress warnings to hide defects or
  fabricate UIDs. Native imports generate UIDs.
- No invented claims about FPS, memory, visual quality, device support or AI
  productivity. Parser/headless success is not physical-device or export proof.

## Retrieve domain context

Use generated context instead of reading unrelated subsystems in bulk.

| Change | Read |
| --- | --- |
| Owner/reuse, lifecycle, native-operation rules | [Detailed contract](docs/guides/agent_development_contract.md) |
| Feature tooling, API review, test selection, measurements | [Agent workflow](docs/guides/agent_workflow.md) |
| Composition and actual wiring | [Composition verification](docs/guides/composition_verification.md) |
| Image interaction, input, navigation, modals, devices | [Image-screen contracts](docs/components/image_screen_interaction.md) |
| Editor, dimensional profiles, updates, rollback | [Addon management](docs/guides/addon_management.md) |
| Public compatibility and version decisions | [API stability](docs/policies/api_stability.md), [versioning](docs/policies/versioning.md), [deprecation](docs/policies/deprecation.md) |

The detailed contract's applicable constraints remain binding; the context tool
is an aid to discovery, not permission to ignore them or invent an API.

## Verify and deliver

```bash
python3 tools/development/nucleus_dev.py plan --base HEAD
# Review the plan before executing with the pinned executable:
python3 tools/development/nucleus_dev.py plan --base HEAD --run --engine godot
```

Use the PR base to cover committed changes, not only the last local edit.
For a direct-main task, record the starting commit SHA and use it as the base;
`HEAD` alone after committing can miss the change you intended to validate. Selection
is local feedback, not a replacement for full CI. If behavior affects the actual
composition, test the real scene and signal/binding lifetime; use native viewport
input for UI. Do not count class-name references as composition proof.

After addon code/resource/UID/version changes, regenerate the existing addon
manifest. After public declarations change, regenerate the API inventory and
review the source comparison:

```bash
python3 scripts/ci/build_addon_manifest.py
python3 tools/development/nucleus_dev.py api
python3 tools/development/nucleus_dev.py api-diff --base origin/main
```

Do not edit generated inventories by hand. The API inventory is a declaration
index, not proof of semantic compatibility: also review defaults, signal order,
Resource/save formats and actual consumers. Compatibility decisions for changed/
removed declarations must cover version, migration and consumer evidence. New
subsystems/routes update the existing coverage/use-case registries and builders.
Docs-only changes need links/audits, not runtime retests. Release/editor changes
need the applicable full CI, packaged-addon/editor/host and export checks.
`--allow-dirty` packages are local tests, not reviewed releases.

Report owner selected → actual wiring → changed contract → executed checks →
limitations → next action. Compare any claimed improvement against the same
baseline task and conditions; never turn an aspirational productivity target
into a reported measurement. State skipped tests and partial failures plainly.
Do not commit/publish/merge beyond user authorization; never merge merely because
local tests passed. [Detailed commands and release boundaries](docs/guides/agent_development_contract.md#4-required-change-procedure-and-proof).
