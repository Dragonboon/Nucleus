# Composed acceptance scenes

These small fixtures close cross-component contracts without shipping a game
starter. Run visual labs with F6. CI runs the smoke scenes below using
`scripts/ci/run_godot_checked.py`, which rejects script/compiler errors even if
Godot exits with code zero.

| Composition | Owners | Runnable acceptance | Expected result |
| --- | --- | --- | --- |
| Hero ability unlock, mana cost, shield spillover, interrupt, XP and two-wave encounter | RPG action / combat / progression / encounters | `tests/smoke/rpg_battle_smoke.tscn` | Deterministic in-process battle sequence ends with one completion and no assertion failures |
| Procedural region, POI clearing, collect, unload/reload, disk save | Terrain + BiomeSurfaceQuery + ScatterDensityVolume + WorldRegion/Entity + SaveSession | `tests/smoke/world_composition_smoke.tscn` | Same generated IDs; collected POIs remain hidden; decoration never occupies reserved sites |
| Walking onto/off a moving buoyant hull | CharacterMotor3D + native CharacterBody3D platform following + Buoyancy3D/RigidBody3D | `tests/smoke/boat_transfer_smoke.tscn` | Rider boards, follows the moving hull and reaches the second dock without reparenting |
| Three clients joining and reconnecting | ENet/MultiplayerAPI + NetworkWorldReadiness + NetworkIntentChannel | `tests/smoke/world_session_smoke.tscn` | Pre-ready interactions rejected; valid interactions accepted; stale readiness rejected after reconnect |
| Real adaptive background workload | PerformanceSampler + AdaptiveController + WorkloadBinding + MaterializationQueue + TerrainBuildJob | `tests/smoke/adaptive_measured_smoke.tscn` | Actual jobs complete and measured windows are recorded; original budgets restored |

## Inspect encounters and rewards

The RPG smoke scene checks ability use, shields and wave completion. The
headless `encounter_lifecycle_test.gd` suite checks duplicate defeat
notifications, terminal outcomes, restarts, and victory-only experience.
Connect `wave_requested` to the existing 2D/3D Spawner in each game;
Nucleus does not own placement, team membership, inventory delivery,
or authoritative network input.

## Inspect the world

Run `examples/world_composition/world_composition_lab.tscn`. **Collect POIs**,
switch regions with Tab and return. **Save/Load** use the dedicated
`nucleus_world_composition_lab` slot through NucleusSaveSession; autosaving is
disabled for this example. This slot is example-owned and Save replaces its
previous contents. The smoke test uses its own temporary slot and deletes it.

World State persists only explicit landmark visibility here. Terrain/scatter
are regenerated from profiles and seeds. Stable POI cell IDs bridge generation
to persistence; the save service does not know about biomes. POI reservations
include neighboring sites within the clearing radius, so region borders do not
create decoration intrusions. Collecting a landmark intentionally retains its
clearing: that is example policy, not a framework requirement.

`NucleusBiomeMaterialMap3D.build(query, minimum, size, resolution)` bakes an
ImageTexture from the selected biome's existing `terrain_material.base_color`.
The example shader samples it in world X/Z. Both generated terrain and an
ordinary MeshInstance can consume this map. Resolution is bounded to 2–256;
an uncovered sample or missing material uses the supplied fallback color.
An invalid query, missing surface node or invalid bounds returns an explicit error. This is explicit
CPU work: rebuild after changed climate/surface inputs. It is base-color
composition, **not** automatic blending of full PBR texture stacks or meshes.

## Inspect movement and water

Run `examples/validation/boat_transfer/boat_transfer_lab.tscn`. It automatically
walks a capsule between docks and the hull, showing its current phase and final
PASS/FAIL. Flat water, locked hull rotation and one scripted velocity impulse
isolate buoyancy and native platform following. This proves no waves, steering,
swimming, rotating-deck controller or replicated boat simulation.

## Inspect adaptation under actual work

Run `examples/adaptive_performance/adaptive_measured_lab.tscn` and press **Run**.
Equal-duration baseline/adaptive phases repeatedly build bounded 96-cell terrain
patches with identical profiles. At most four jobs are admitted at once and only
the last patch is displayed. A third phase stops admissions and observes recovery.
There are no injected FPS values, sleeps or synthetic busy loops.

`user://adaptive_measured_comparison.json` contains native sampler reports,
completed/submitted jobs, remaining work, minimum/final recommendations and raw
recovery windows. Compare frame pacing **and throughput**; reducing work per frame
can increase generation latency. A faster host may never reach adaptation
thresholds. A slow host may not recover during the observation period. Both are
valid measurements; the test never asserts an invented FPS gain.

The lab reduces background queue budgets, not persisted display settings or
physics. It keeps the existing 60 FPS/80% recommendation bounds; the percentage
is a pressure proxy, not a diagnosis. Hysteresis windows are shortened explicitly
for a finite lab run. Use the original defaults in a game unless measured tuning
justifies changing them. Run the same workload on target hardware before making
Steam Deck/ROG Ally performance claims.

## Network evidence boundary

The session smoke uses real localhost UDP with four independent MultiplayerAPI
roots in **one process**. This isolates three-client admission, interaction and
reconnect. The fixture supplies trusted peer identities/epochs; it is not an
authenticator. Dedicated-server deployment, multiple machines, packet impairment,
asset transfer and deterministic CharacterBody replay remain separate game gates.
