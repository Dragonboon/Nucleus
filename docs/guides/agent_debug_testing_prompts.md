# Agent prompts: debugging and gameplay validation

Apply the [task preamble](agent_prompt_playbook.md#task-preamble) and [AGENTS.md](../../AGENTS.md). Work on **one reproducible defect or validation objective** at a time. The agent must distinguish inspected evidence, executed tests and hypotheses.

## Debug prompts

### D1. Godot parser and missing scene resources

~~~text
Diagnose [exact error] in [scene]. Inspect HEAD, pinned Godot version,
class_name registrations, res:// paths, .tscn/.tres dependencies, imported
assets and tracked .uid files. Find the first causal failure, not secondary
errors. Reproduce with the project import if possible, fix the smallest
owner, preserve references and test scene reopening. Do not bulk-delete
.godot/ or invent regenerated UIDs. Report PASS/FAIL/NOT RUN.
~~~

### D2. Reentrant signals, input and lifecycle

~~~text
Reproduce [duplicate event / stuck action / stale callback] in [scene].
Trace signals, _enter_tree/_ready/_exit_tree, deferred callbacks and the
single writable owner. Add a regression for repeated inputs, cancellation,
scene disposal and reload. Fix the minimal source of the duplicate event;
avoid extra global event managers or arbitrary delays. Execute focused
tests and the real scene, or mark the latter NOT RUN.
~~~

### D3. Damage, shields, actions and turns

~~~text
Reproduce [damage/cost/turn/status bug] with concrete preconditions.
Inspect the actual GameplayAction, requirements, DamageResolver, pools,
TurnSession and status clock only when involved. Record the exact
validation → commitment → effect order, including failure semantics.
Test immunity, insufficient resources, interruption, repeated trigger,
out-of-turn rejection and save/reload as applicable. Add a regression,
keep all prior acceptance tests and report unexecuted checks.
~~~

### D4. Enemy AI in 2D or 3D

~~~text
For [enemy scene], diagnose [target not detected/chase stuck/attack fails].
Inspect sensors, TargetingAgent, UtilityBrain, state bridge,
NavigationAgent2D/3D, NavigationFollower and shared motor, plus real map
readiness and collision layers. Use AICharacterSetup2D/3D diagnostics.
Correct the broken connection, not by creating another movement owner.
Test target acquisition, obstacle, lost target, death and scene disposal.
~~~

### D5. Save, pooling and scene reload

~~~text
Reproduce [lost state/duplicate reward/reused actor bug]. Inspect stable
identifiers, save schema, pool acquire/release and encounter accounting.
Prove create → interact → save → load → repeat, including invalid snapshots
and a fresh scene. Do not serialize live Nodes or change NucleusSave for a
game-owned data mapping defect. Report actual evidence and rollback.
~~~

### D6. Profiling without speculative optimization

~~~text
Profile [scene] under fixed workload, device and graphics settings.
Use native Godot profilers and Nucleus performance diagnostics. Identify
measured CPU/physics/GPU/allocations/import issues. Change only the proven
bottleneck, rerun identical workload and compare numbers. If no profiler
can run, report NOT MEASURED and avoid performance claims.
~~~

## Test prompts

### T1. Derive a mechanic's acceptance matrix

~~~text
For [player-visible mechanic], produce a matrix: precondition, trigger,
expected outcome, rejection, feedback, cleanup and persistence. Choose the
minimum evidence level for each: unit/headless, composed scene, editor,
controller/device or export. Include one old mechanic as a regression gate.
Do not write tests for APIs that have not been inspected.
~~~

### T2. Deterministic headless regression

~~~text
Add a deterministic test for [specific behavior] using this checkout's
test_case.gd and test_manifest.gd when working in Nucleus, or the game's
own harness otherwise. Use real SceneTree attachment, seeded randomness,
controlled clocks and explicit assertions for success and failure.
Run through the normal project test scene. An authored but unexecuted test
must be described as NOT RUN, never PASS.
~~~

### T3. Composed scene validation

~~~text
Create or extend a minimal real-scene smoke for [mechanic]. Verify actual
node references, signal connections, input/effect/feedback, rejection,
repeat interaction, cleanup and reload. Do not make test fixtures the
game's default scene. Run the smoke with the pinned Godot project and
check parser logs and exit code; preserve previous smoke behavior.
~~~

### T4. Accessibility and player-facing feedback

~~~text
Test [game UI/interaction] with keyboard and controller in the actual
editor/game. Verify focus order, prompts, text scale, contrast,
reduced-motion preference, errors and success feedback. Confirm rejected
actions do not play success animation/audio. Record manual observations,
or NOT RUN when no graphical environment/device is available.
~~~

## Integration validation prompts

### I1. Cross-system ownership

~~~text
Trace [actual scene] from intent/input → GameplayAction → effects →
state/AI → presentation → save. Inventory precise node paths, exported
bindings, signals and writable owners. Flag missing signal consumers,
competing motors, broken action context, stale targets and save gaps.
Fix the smallest owning layer and verify the old plus new mechanic.
~~~

### I2. Encounter end-to-end

~~~text
In [arena scene], verify wave_requested → existing Spawner2D/3D →
unique instance registration → ValuePool depleted → exactly-once defeat
→ next wave → victory/defeat/retreat → reward at most once. Cover
insufficient pool capacity, duplicate death, cancellation, reload and
network authority if applicable. Reuse Nucleus EncounterDirector and
game-owned policies; do not introduce a competing BattleManager.
~~~

### I3. Turn-based integration without RPG assumptions

~~~text
Validate [board or tactical scene]: correct TurnSession roster,
TurnRequirement gate, FinishTurnEffect ordering, status tick clock,
blocked/timeout turns, pause, reentry and restart. Keep legal moves,
winner and UI game-owned. Run headless and composed checks as available
and document limitations of mid-turn persistence.
~~~

## Local validation and evidence

In the Nucleus repository (adjust paths to a derived game's checkout):

~~~bash
python3 scripts/ci/static_checks.py
python3 scripts/ci/documentation_audit.py
python3 scripts/ci/use_case_audit.py
python3 scripts/ci/build_use_case_catalog.py --check
python3 scripts/ci/productization_audit.py
godot --headless --path . --import
godot --headless --path . res://tests/headless/test_runner.tscn
~~~

For an appropriate smoke, use the [acceptance index](composition_acceptance.md);
for authored scenes and Resources use [validation commands](development_validation_quickstart.md);
for runtime object inspection use the [Scene Object Console](scene_object_console_quickstart.md).
These tools are diagnostic; never expose arbitrary remote execution in a release.

Report a table of checks as **PASS / FAIL / NOT RUN** with command, observed
result, affected platform, remaining risk and smallest next action. A green
parser alone cannot establish playable behavior, appearance or performance.

**Next:** [Playbook](agent_prompt_playbook.md) ·
[Scene/asset/addon prompts](agent_scenes_assets_addons_prompts.md).
