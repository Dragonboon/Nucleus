# Worked agent prompts: three incremental game paths

Use these examples with the [agent prompt playbook](agent_prompt_playbook.md).
Start a new task with its [preamble](agent_prompt_playbook.md#task-preamble),
then copy **one numbered prompt at a time**. The stages deliberately keep
native Godot, Nucleus contracts and game-owned rules separate.

These are prompts, **not promises that a generated scene already exists**.
Agents must inspect actual APIs and validate on the game's pinned engine.

## Example A: top-down 2D arena with enemy AI

**Goal:** reach a small playable loop: move, avoid an enemy, attack, finish a
wave, receive feedback. The game owns enemy tactics, sprites, damage values,
collision layers and victory text.

**Relevant contracts:**
[2D foundation](../components/2d_foundation.md),
[2D AI character](tutorials/ai_character_2d.md),
[actions/attributes/status](../components/gameplay_actions_attributes_status.md),
[encounters](../components/rpg_composition.md).

### A1. Generate a game-specific use-case backlog

~~~text
For a keyboard/controller top-down 2D arena built from Nucleus, propose a
minimal playable loop with 6–8 cases: movement, enemy detection, chase,
player attack, damage feedback, wave completion and retry. Rank dependencies.
Route every case through the actual Godot/Nucleus owner and say what remains
game-owned. Split the playable loop into three vertical slices. No code yet.
~~~

### A2. Implement one actor and one observable enemy

~~~text
Implement only movement, 2D navigation and target acquisition in the game's
arena scene. Inspect CharacterMotor2D, AICharacterSetup2D, NavigationAgent2D,
TargetingAgent, UtilityBrain and StateMachine before wiring. Use native
NavigationServer2D, not a new pathfinding manager. Define a simple game-owned
patrol/chase rule. Acceptance: enemy sees and follows a target, loses it
cleanly and releases references on scene exit. Add negative tests and
test with the actual navigation map. Do not add damage or a wave system yet.
~~~

### A3. Add attacks using shared contracts

~~~text
Preserve the existing chase scene. Add one game-owned attack with
GameplayAction, a target/range requirement, cooldown and ApplyDamageEffect
through DamageResolver. Use ValuePool for health/shields only where needed.
An invalid/out-of-range attack must not pay costs or play success feedback.
Test hit, immunity, death, repeat hit and target removal. Keep animation
and sound separate from authoritative damage. Do not implement new AI,
ActionSet or combat managers.
~~~

### A4. Add waves, reward and accessibility

~~~text
Connect EncounterDirector.wave_requested to the existing Spawner2D or an
explicit game-owned spawn adapter. Give every spawned enemy a stable
encounter instance ID and report defeat exactly once through the documented
EncounterCombatant/Director API. Connect victory-only rewards and make a
readable restart/focus flow. Validate spawn failure, double defeat, last-wave
completion, scene reload and controller/keyboard navigation. Report which
tests ran; leave level generation and inventories for later.
~~~

**Stop:** the arena is playable and restartable, with the previous movement and
attack checks still passing. Do not equate this with validated enemy tactics
or verified frame time for hundreds of NPCs.

## Example B: turn-based tactical board (not an RPG)

**Goal:** two seats alternate legal moves on a board, can skip and end a round,
and a win condition is recorded. No damage, mana or encounter manager is
required.

**Relevant contracts:**
[turn sessions](../components/turn_sessions.md),
[turn quickstart](turns_composition_quickstart.md),
[square grid](../components/square_grid.md),
[actions](../components/gameplay_actions_attributes_status.md).

### B1. Identify the minimal board loop

~~~text
Outline a two-seat tactical board game using Nucleus. Specify a single
legal move, active-seat ownership, invalid move feedback, turn transition
and victory condition. Route board coordinates to the documented grid
contract and turn ownership to NucleusTurnSession, but keep move legality
and scoring in game-owned rules. Propose two tiny acceptance slices.
Do not add RPG combat systems.
~~~

### B2. Build legal moves and turn enforcement

~~~text
Compose two TurnParticipant nodes with a TurnSession in SERIAL mode. Use
TurnRequirement to gate the game-owned Move action. FinishTurnEffect goes
last only after a legal committed move. Check occupancy and bounds using
the actual grid API; do not guess method names. Acceptance: out-of-turn
and occupied-cell requests are rejected without advancing the turn.
Test skip/timeout and simultaneous callbacks for regressions.
~~~

### B3. Expand only after the loop passes

~~~text
Add one explicit win condition and an accessible turn indicator. Preserve
legal move, rejection and turn-order checks. Optionally test INITIATIVE or
SIMULTANEOUS in isolation, but do not silently change the original
ruleset. Test pause, restart, reentry, save of stable board IDs and a
restored playable scene. Record limits of current mid-turn persistence.
~~~

**Stop:** two seats can finish a game, reject invalid actions and restart.
Do not add level trees, combat statistics or a generic game manager.

## Example C: 3D exploration with persistent interactions

**Goal:** navigate a room, open one door, persist the result, resume the
newest save, and show responsive feedback.

**Relevant contracts:**
[movement/camera](../components/gameplay_movement_camera.md),
[interaction/actions](../components/gameplay_foundation.md),
[save system](../components/save_system.md),
[UI accessibility](../components/ui_and_accessibility.md).

### C1. Define the first room, not an entire open world

~~~text
Plan the smallest playable 3D exploration room in a Nucleus-derived game.
Use native CharacterBody3D, camera and collision, then route interaction
and persistence through existing Nucleus contracts. Produce a one-scene
ownership map, observable acceptance cases, failure cases and a deferred
backlog for streaming, quests and world generation. No code yet.
~~~

### C2. Implement one persistent door

~~~text
Add a player-visible door interaction using the existing Nucleus interaction
and GameplayAction contracts. Validate proximity, lock state, repeated
activation and rejected interaction feedback. Keep the door's open/closed
rule in game/. Persist a versioned stable door ID and restore through the
documented Nucleus Save boundary; do not save transient Node IDs. Prove
open → save → reload → still open in the actual scene. Do not add quests.
~~~

### C3. Add quality and device checks

~~~text
Polish only the accepted room and door: readable focus and interaction
prompts, controller/keyboard input, sound, scene transitions and retry
feedback. Honor UI scale, reduced motion and contrast preferences where
applicable. Measure the actual room on the target hardware before making
performance claims. Report executed evidence and the next small slice.
~~~

**Stop:** one room works with real input and persists correctly. Expanding the
world is a separate decision, not part of proving this mechanic.

## Example D: a gradual improvement loop

Use this after any accepted slice, regardless of genre.

~~~text
Current accepted behavior: [one sentence].
Current HEAD / last known-good commit: [id].
Next player-visible improvement: [one sentence].
Do not redesign earlier owners. Inspect only the changed dependencies,
show the integration points, preserve the previous acceptance tests and
implement the smallest change. Run the relevant local validation and
a composed scene check. Return: behavior, changed files, actual results,
remaining risk and one next candidate. Do not run CI workflows or push
unless expressly authorized.
~~~

For a bug, use [repair a regression](agent_prompt_playbook.md#5-repair-a-regression).
For performance, use [measure and polish](agent_prompt_playbook.md#7-measure-and-polish).
For truly reusable additions to Nucleus, use
[shared extraction](agent_prompt_playbook.md#8-propose-shared-extraction).

## For debugging, scene authoring and existing addons

Use the dedicated [debugging/testing prompt library](agent_debug_testing_prompts.md)
for parse failures, signal races, AI navigation, save/reload, acceptance and
cross-system validation. Use the [scene, asset and addon prompts](agent_scenes_assets_addons_prompts.md)
for safe reuse of imported content, level variants and existing plugins.
These workflows apply after any worked example and require real asset paths.

## When to expand the use-case catalog

The [generated catalog](use_case_catalog.md) derives from
[use_case_registry.json](../use_case_registry.json). It describes **real,
already supported routes**, not hypothetical future game features. If a new
cross-game behavior deserves a discovery entry, ask the agent:

~~~text
Check whether [new generic capability] is already covered by a catalog route.
If a real reusable contract exists but discovery is missing, add one specific
record to docs/use_case_registry.json under the correct existing domain,
linking the actual canonical technical guide. Regenerate the Markdown catalog
with scripts/ci/build_use_case_catalog.py and run its --check mode plus
use_case_audit.py. Do not add a route for an unimplemented API or manually
edit the generated use_case_catalog.md.
~~~

Use the [documentation model](../architecture/documentation_model.md) to keep
guides discoverable without multiplying duplicated sources of truth.
