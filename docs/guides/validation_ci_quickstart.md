# Validation and CI Quickstart

Nucleus has one authoritative automated path: load the real Godot project so the
normal Autoload contract exists, then run the registered headless suites and smoke
scenes.

## 1. Repository checks

```bash
python3 scripts/ci/static_checks.py
python3 scripts/ci/documentation_audit.py
python3 scripts/ci/productization_audit.py
python3 scripts/ci/use_case_audit.py
python3 scripts/ci/build_use_case_catalog.py --check
```

These catch source conventions, test-manifest mistakes, documentation coverage
and productization contract errors without pretending to be runtime validation.

## 2. Import with the CI engine

```bash
godot --headless --path . --import
```

The release-gated reference is currently Godot `4.7.2-stable`.

## 3. Run the native test scene

```bash
godot --headless --path . res://tests/headless/test_runner.tscn
```

Every dependency-free regression suite lives under `tests/headless/*_test.gd`,
extends `tests/headless/test_case.gd`, returns `finish()`, and is registered in
`tests/headless/test_manifest.gd`.

The runner is a normal project scene on purpose. Do not replace this with
`godot --script tests/headless/test_runner.gd`: transitive Nucleus source expects
the project's Autoloads to exist during compilation and execution.

### Editor workflow

For fast local iteration, open:

```text
tests/headless/test_runner.tscn
```

and press **F6 — Run Current Scene**. The same suite graph is used in editor and headless validation; there is no
second editor-only test contract.

## 4. Smoke scenes

Baseline Core/Autoload smoke:

```bash
godot --headless --path . res://tests/smoke/smoke_main.tscn
```

Threaded resource-loading smoke:

```bash
godot --headless --path . res://tests/smoke/resource_loading_smoke.tscn
```

Run the loading smoke whenever `core/loading`, warmup/loading integration or its
public presentation bindings change.

Movement and networking composition checks:

```bash
godot --headless --path . res://tests/smoke/locomotion_3d_smoke.tscn
godot --headless --path . res://tests/smoke/network_replication_smoke.tscn
```

The first exercises a body over real Jolt frames; the second connects two ENet
peers on localhost UDP port 48472. Neither validates a game's art, input device
feel, WAN conditions or four-player gameplay. All four smoke scenes run in CI.

RPG-neutral composed battle acceptance (does not need authored art):

```bash
python3 scripts/ci/run_godot_checked.py godot --headless --path . \
  res://tests/smoke/rpg_battle_smoke.tscn
```

Run the same scene with F6. It exercises an unlocked ActionSet ability, mana,
shield spillover, cast interruption, level advancement, and two encounter waves.
No GitHub Actions run is required for local validation.

## 5. Manual validation scenes

Use representative scenes under `examples/` for visual or interaction behavior
that cannot be proven headlessly. Examples include gameplay, UI polish, terrain,
decals and other scene-owned integrations.

A manual scene is evidence for its visual/interaction contract; it is not a
replacement for the automated suite.

## 6. Smoke exports

With official export templates installed:

```bash
GODOT_BIN=/path/to/godot bash scripts/ci/smoke_exports.sh "$PWD"
```

The CI workflow validates Linux, Windows and Web packaging for the reusable
baseline. That proves exportability of Nucleus itself, not every game-specific
renderer/plugin/platform SDK.

## Recommended order

```text
1. static/documentation/productization audits
2. headless import
3. native test scene
4. affected smoke scene(s)
5. affected manual validation scene(s)
6. smoke exports for release-facing work
```

Call a change runtime-green only after the relevant Godot steps have actually
executed successfully.

## Script-error guard and composed scenarios

Run Godot through `python3 scripts/ci/run_godot_checked.py <godot> <arguments>`
when validating automation. The wrapper preserves nonzero exits and also fails
on script/parse/compile errors that Godot can otherwise log and continue past.
See [composed acceptance](composition_acceptance.md) for world persistence,
boat transfer, multi-client readiness/reconnect and measured adaptive work.
