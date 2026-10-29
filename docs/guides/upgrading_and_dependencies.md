# Selective integration and upgrades

Nucleus is an installable Godot addon. See [addon migration](addon_migration.md). Optional modules are opt-in at runtime, not
independent installable packages with automatic dependency resolution. Copying
one script without its referenced classes can break Godot's global-class parse.
Start with the pinned addon; remove code only after checking references and
running import, audits and tests on that reduced project.

## Composition dependencies

| Requirement | Bring together | Keep in the game |
| --- | --- | --- |
| Baseline | Six documented core Autoloads, settings catalog, audio buses | Main scene, branding, settings choices |
| Biome classification | World biome Resources; current profiles reference `addons/nucleus/modules/terrain` and `addons/nucleus/modules/scatter` types | Climate authoring and content |
| Procedural decoration | Surface sampler + Scatter profile/region + core MaterializationQueue | Desired regions and budgets |
| Biome color map | BiomeSurfaceQuery + terrain integration map + a material consuming its texture | Shader/PBR art policy |
| Persistent procedural objects | World State region/entity/adapters + SaveSession + baseline save service | Stable IDs, generator revision and schema |
| Adaptive workload | Performance sampler/controller/profile + explicitly selected queue/stream/scatter targets | Critical/background split and opt-in |
| Network world admission | Native peer/spawner/synchronizer + networking readiness/intent components | Authentication, actor authority and session epoch |

The [use-case catalog](use_case_catalog.md) routes other mechanics to their
existing owners. The [maturity map](../architecture/maturity.md) says what those
contracts have actually demonstrated.

## Upgrade without losing authored work

1. Record the Nucleus commit/version, pinned Godot version and game-owned schema
   in the consuming repository. Commit the game's current changes first.
2. Merge the selected upstream change into a review branch. Inspect source,
   Resources, project settings, UIDs, tests and contract docs together.
3. Preserve tracked `.gd.uid` identity. If Godot generated untracked UID files
   now supplied upstream, move **only those conflicting files** to a backup
   outside the checkout before pulling. Review references before accepting the
   upstream IDs. Do not use a repository-wide clean or regenerate every UID.
4. Run import through `run_godot_checked.py`, then the headless runner and the
   composition smokes used by the game. Finally run actual game scenes with
   representative assets, physics, input and networking.
5. Confirm previously saved games and authored scenes still load. Keep rollback
   commits and sample old saves until migration behavior is verified.

## This stabilization iteration

- Existing active-state requests remain successful no-ops. The capacity test
  now submits a genuinely queued transition; no runtime state-machine behavior
  was changed to satisfy an incorrect expectation.
- Mesh slicing supports PrimitiveMesh and ArrayMesh through their actual native
  APIs, including meshes without authored normals/UVs or indices. Generated
  normals and caps use clockwise winding; tangents are rebuilt. Secondary UVs,
  vertex colors, skinning and complex contours remain rejected.
- The new biome color-map helper is additive. It does not rewrite authored
  materials. The example now demonstrates palette colors, POI reservations and
  explicit persistence using existing Resources and owners.
- Session epochs must increase. Beginning an older epoch is rejected instead of
  resetting the current world's readiness state.
- Previous Scatter hash/POI eligibility corrections can change regenerated
  distributions. Preserve game-owned saved descriptors or pin the generator
  revision; a stable seed alone is not a generator-version migration strategy.

The version is advanced to `0.33.0-dev.1` for the additive public material-map
API. No existing public classes, exported properties or UIDs are renamed.
