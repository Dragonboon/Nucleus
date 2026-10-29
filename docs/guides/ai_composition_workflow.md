# Building game mechanics with Nucleus: AI and human workflow

Nucleus is **not** a text-to-game generator. It is a Godot 4.7.2-stable project
foundation that makes generated and manually authored game code easier to compose,
reason about, test, and maintain. This document tells a coding agent *how to use
it*, rather than encouraging the agent to invent new framework APIs.

> [!IMPORTANT]
> **Required starting point:** Define the player-visible behavior, locate the
> existing owner, and verify the real API before adding new scripts or Autoloads.

**Want copy-ready prompts?** Start with the
[agent prompt playbook](agent_prompt_playbook.md), then choose a
[worked sequence](agent_prompt_examples.md). For failure diagnosis, use the
[debug/testing prompts](agent_debug_testing_prompts.md); for content reuse,
use the [scene/asset/addon prompts](agent_scenes_assets_addons_prompts.md). Each stage inherits the
mandatory [AGENTS.md](../../AGENTS.md) contract and is independently testable.

**Quick route:** [Find a capability](use_case_catalog.md) →
[Choose an owner](../architecture/component_selection.md) →
[See composed examples](composition_recipes.md) → **Implement and validate.**

## 0. Start with the user-visible behavior

Write one sentence in the form **"When [input/event], the player sees [result]"**.
Then define: the owning Node/Resource, inputs/events, game rules, data that must
persist, authority for multiplayer, feedback, failure states, and an observable
acceptance test. Distinguish a mechanics requirement from art direction.

Example: "When the player presses Interact near a closed door, the door opens
once, saves its state, and stays open on reload." This is not a request for a
`DoorManager` singleton.

## 1. Find the nearest existing owner

1. Search the [use-case catalog](use_case_catalog.md) **by gameplay problem**.
2. Read the linked technical contract, then inspect the actual script and nearest
   caller/test. Do **not** implement against a guessed class or method name.
3. Ask whether native Godot (`CharacterBody`, `AnimationTree`, `Area`,
   `NavigationAgent`, `MultiplayerSpawner`, `UndoRedo`) already owns the operation.
4. Prefer one of the existing six Autoloads only for its documented cross-scene
   concern. Optional modules stay scene-owned.
5. If no owner fits, build the smallest game-owned component first. Do not add a
   new Nucleus API just because a single game's feature is missing.

### Ownership decision table

| Question | Correct owner |
| --- | --- |
| Who simulates collision, animation, pathfinding and draw calls? | Godot native nodes/servers |
| Who provides reusable state and lifecycle contracts? | Nucleus addons/nucleus/components/modules |
| Who decides damage, hunger, quest progression, AI tactics or appearance? | The consuming game |
| Who accepts multiplayer gameplay truth and visibility? | The authoritative game/server |
| Who validates editor scene modifications? | The addon/editor operation, using native UndoRedo |
| Who measures, not guesses, bottlenecks? | Nucleus diagnostics + Godot specialist profilers |

## 2. Compose a thin game-owned vertical slice

Example scene for a small action/survival player:

```text
Game/Player (game-owned CharacterBody3D)
├── CameraRig (native and/or Nucleus camera component)
├── InteractionArea (native Area3D + Nucleus interaction component)
├── HealthPool (Nucleus value pool)
├── StaminaPool (Nucleus value pool)
├── StateMachine (Nucleus FSM)
├── AnimationTree (native)
└── PlayerRules.gd (game-only inputs, stamina costs, attacks, swim rules)
```

This is an architectural sketch, **not** a drop-in scene: verify actual exported
properties, required children and script paths before wiring. A game may need
fewer components. Keep one authority for movement per physics tick and never
write the same transform from competing nodes.

## 3. Implement as an explicit dependency graph

Use direct node references and signals within one scene. For truly separate
subsystems, consider the optional EventBus only if neither direct references nor
scene-local signals express the relationship. Avoid hidden service discovery,
implicit Autoload promotion and global writes.

For each new behavior, document the hand-off:

```text
semantic player intent
→ native input/collision observation
→ game-owned validation and rules
→ Nucleus reusable mutation/effects contract (if needed)
→ native presentation / game HUD, audio, animation
→ persistence or replication only when required
```

A generated feature is incomplete if a signal has no consumer, if two owners
mutate the same state, or if a rejected action still plays success feedback.

> [!CAUTION]
> **Trust and persistence boundaries are not optional.** A valid RPC, loaded
> scene, or accepted editor action is not proof of authorization or safety.

## 4. Persistence, determinism and security

- Store **stable game IDs and versioned data**, not Node instance IDs or raw
  transient object references. Use documented Save/World State boundaries.
- Distinguish seeded/replayable generation from *cross-platform* deterministic
  simulation; test replays using identical inputs.
- A validated RPC shape is not gameplay authorization. Authenticate the peer,
  validate authority and ranges, and decide replicable state on the server.
- For mods and PackedScenes, distinguish data-only trust checks from loading or
  running code. PackedScene preflight does not make untrusted scenes safe.
- For UI/editor undo, commit state changes only after validation. Keep runtime
  snapshot history separate from the editor's native `EditorUndoRedoManager`.

## 5. Validate the smallest observable contract

Always state what was run, what passed, and what remains unverified. Suggested
sequence from the repository root:

```bash
python3 scripts/ci/static_checks.py
python3 scripts/ci/documentation_audit.py
python3 scripts/ci/use_case_audit.py
python3 scripts/ci/build_use_case_catalog.py --check
python3 scripts/ci/productization_audit.py
godot --headless --path . --import
godot --headless --path . res://tests/headless/test_runner.tscn
godot --headless --path . res://tests/smoke/smoke_main.tscn
```

Then run the relevant gameplay/editor/visual scene with real input and hardware.
Headless passing does **not** establish gameplay feel, stable GPU performance,
network reliability under loss, or editor GUI ergonomics. On failing validation,
fix the owning component and add a regression; do not silence parser or import
errors by dropping tests.

## 6. Output expected from an AI coding task

Provide:

1. **Behavior:** what a player/designer can now do and how to reproduce it.
2. **Owner map:** which Godot/Nucleus/game scripts were reused, and why.
3. **Files/API changes:** what was added or modified, including save/RPC contract.
4. **Evidence:** executed commands, test/scene outcomes, build and target platform.
5. **Remaining risks:** untested visuals, latency, migrations, exports or hardware.
6. **Rollback:** clear changed-file set; no unnecessary changes to shared owners.

Avoid fabricated timings, success claims from static inspection, and big rewrites
when a local bridge will do. Follow `AGENTS.md` as the repository's primary
operating contract; this guide only adds a behavior-first discovery workflow.

## 7. Prompts people can reuse

**Create a behavior**

> In this Nucleus-based Godot 4.7.2 project, implement [visible mechanic].
> First identify the native Godot owner, existing Nucleus contract and nearest
> tests. Keep balance/art/quest policy in the game. Build a minimal vertical
> slice, validate negative cases and report any test not run. Do not add an
> Autoload or a new generic framework unless independent reuse is proven.

**Improve an existing system**

> Inspect the current scene and its one state writer before changing it.
> Reproduce [bug], describe expected and observed behavior, fix the smallest
> owning component, add a regression and preserve existing save/scene contracts.

**Extract a reusable mechanism**

> Compare the game-specific feature with existing Nucleus APIs, isolate the
> mechanics-neutral contract, identify a second use case, estimate coupling
> and maintenance cost, and prototype without silently changing the game.

For worked ownership flows, open [composition recipes](composition_recipes.md).
