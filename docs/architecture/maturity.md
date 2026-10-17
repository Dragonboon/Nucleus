# Nucleus maturity and integration map

This is a scope/evidence map, **not a production certification or percentage complete**.
The source of truth for exact contracts is each linked document; the test manifest
and CI retain the executable checks. A listed test must actually pass for its
claimed evidence to apply to the checked-out revision.

- **Validated within scope:** automated behavior checks plus a runnable composed fixture.
- **Integrated:** usable contracts and regression tests; important real-world conditions remain unverified.
- **Experimental:** deliberately narrow or evolving behavior; pin the revision and validate assets.

## Baseline and component families

| Family | State | Evidence / entry point | Remaining validation |
| --- | --- | --- | --- |
| Core settings/input/audio/save/scene lifecycle | Validated within scope | [Foundation](../guides/foundation_quickstart.md), bootstrap/resource smoke scenes | Device audio/input, game-specific save migrations |
| Character locomotion | Validated within scope | `locomotion_3d_smoke.tscn`, [boat transfer](../guides/composition_acceptance.md) | Player feel, slopes and authored hulls in the actual game |
| Animation/ragdolls | Integrated | [Animation](../components/animation_integration.md), headless animation/ragdoll suites | Imported skeletons, art and physics feel |
| Gameplay actions/state/attributes/combat | Integrated | [Gameplay contracts](../components/gameplay_foundation.md), state/action suites | Game rules, balancing and concurrency in composed actors |
| RPG progression, unlocks, encounters and reaction composition | Experimental | [RPG composition](../components/rpg_composition.md), headless contract suites | No RPG battle smoke scene, no turn arbiter, game-specific rule validation pending |
| UI/accessibility | Integrated | [UI quickstart](../guides/ui_quickstart.md), UI example scenes | Real localization, screen readers/platform accessibility, device navigation |
| Grids/modular building/splines/placement | Integrated | Respective `examples/` labs and headless suites | Imported assets, authored placement constraints and editor ergonomics |
| Water/surfaces/buoyancy | Validated within scope | [Buoyancy](../components/world_buoyancy.md), [boat fixture](../guides/composition_acceptance.md) | Waves, steering, rotating hulls, swimming and multiplayer vehicles |
| Biomes/POIs/world composition | Validated within scope | [World composition](../components/world_composition.md), native scene smoke | Full texture/PBR transitions, gameplay structures, long-running worlds |

## Optional modules

| Module directory | State | Evidence / contract | Limit |
| --- | --- | --- | --- |
| `ai` | Integrated | [AI navigation](../modules/ai_navigation.md), AI suite | Game-specific behavior and navigation content |
| `content_packs` | Integrated | Content-pack compatibility/security suites | Community content and signing/deployment policy |
| `destruction` | Experimental | [Destruction](../modules/destructible_meshes.md), mesh-slice suite | Single simple cut loop; no general fracture solver |
| `development_tools` | Integrated | Development/preflight suites | Production authorization remains game-owned |
| `event_bus` | Integrated | Explicit optional contract in [documentation index](../README.md) | Prefer direct signals for scene-local communication |
| `inventory` | Integrated | Inventory/equipment suites | Game item definitions, authority, UI and persistence composition |
| `loot` | Integrated | Loot suite | Economy and authoritative outcome ownership |
| `mobile` | Integrated | Mobile-input/accessibility suites | Physical devices, permissions and storefronts |
| `networking` | Validated within scope | [Session fixture](../guides/composition_acceptance.md), ENet smoke | Localhost; dedicated processes, WAN impairment and collision replay still require game validation |
| `performance` | Integrated | [Measured lab](../modules/performance.md), adaptive suites | No device FPS promise, CPU/GPU diagnosis or power management |
| `platform_services` | Integrated | Platform-service suite | Real provider SDK/account behavior |
| `scatter` | Validated within scope | [World composition](../components/world_composition.md), scatter suite | Visual decoration; no authoritative actors or automatic collision |
| `terrain` | Validated within scope | Terrain labs/suites and [composition](../components/world_composition.md) | Heightfields, finite build steps, hardware-specific budgets |
| `world_state` | Validated within scope | [Persistence](../modules/persistent_world_state.md), procedural disk round-trip smoke | Explicit identities/adapters; no SceneTree serialization |

## How to improve a maturity claim

Keep the same owner and add the missing reproducible scenario. State engine,
renderer, platform, seed/assets and expected outcome. A green headless suite does
not promote a rendering, hardware or networking feature to production-proven.
A lab that only injects synthetic data remains useful policy evidence; keep it
clearly distinguished from measured live work.
