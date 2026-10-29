# Choosing between Godot, Nucleus and game-owned code

Nucleus exists to make game development faster **without becoming a second game
engine**. It does not promise to generate complete games or automatically pick
the correct mechanic. It gives humans and coding agents tested, composable
mechanisms and documented ownership boundaries.

> [!IMPORTANT]
> **Reuse in this order:** native Godot → existing Nucleus contract → small
> game-owned behavior. Only propose a shared Nucleus API after independent
> reuse is demonstrated.

## A request-to-owner decision tree

```text
Player/designer-visible requirement
    |
    +-- Does Godot own the primitive? (input, SceneTree, physics,
    |   NavigationAgent, AnimationTree, Multiplayer*, UndoRedo)
    |       `-- Use it. Do not wrap without an extra reusable contract.
    |
    +-- Is there an existing Nucleus mechanism?
    |       `-- Read contract and tests; compose its scene-owned API.
    |
    +-- Is the remaining code game-specific? (biome, weapon balance,
    |   quest, puzzle geometry, ocean rendering, UI art)
    |       `-- Keep it in the consuming game.
    |
    `-- Is the mechanism proven by two independent scenarios?
            `-- Consider one small optional Nucleus addition,
                backed by tests, docs, example and compatibility checks.
```

## Acceptance criteria for an agent-friendly foundation

| Quality | Observable evidence |
| --- | --- |
| Discoverable | A gameplay request maps to an existing contract in the use-case catalog |
| Composable | One owner per mutable state; direct nodes and signals, no surprise Autoload |
| Approachable | Quickstart explains scene setup and Inspector configuration |
| Verifiable | Headless tests plus relevant gameplay, editor or graphics scene |
| Compatible | Godot 4.7.2 APIs, stable UIDs, save data and RPC trust boundaries |
| Economical | Modules are optional; no new per-frame loop or global service by default |
| Extensible | Product-specific behaviors can plug into documented signals/callbacks |
| Honest | Tests and CI status are reported only when actually observed |

## Known limitations and deliberately unbundled work

- Nucleus is an **addon** that a developer must integrate with the game scene.
  It is not a visual behavior editor or a code-generation model.
- No built-in quests, dialogue tree authoring, crafting balance, combat
  content, full MMO server, authoritative world simulation, or ready-made
  ocean renderer is promised. These are not documentation omissions.
- Headless tests cannot certify visuals, UX, render budget, cross-platform
  exports or multiplayer loss behavior. Real project scenes are necessary.
- The use-case registry is **routing metadata**, not a script execution API;
  do not build dynamic imports, eval, or automatic class construction from it.
- A debug console is not an authorized production administration interface.

## How to decide an abstraction is warranted

Before adding a Nucleus system, write:

1. Which two **different** game/editor situations need the same mechanism?
2. What owns state, time, thread, authority and object lifetime?
3. What native Godot facility is retained, rather than duplicated?
4. What is intentionally game-owned and therefore excluded?
5. What deterministic/headless checks and what real scene prove it works?
6. What remains compatible for current Nucleus consumers?
7. How can an AI and a human **find it by intent** in documentation?

Reject abstractions that add coupling, duplicate engine facilities, introduce
hidden background work, or require a new global manager to save a few lines.

## Documentation responsibility

- [`../guides/use_case_catalog.md`](../guides/use_case_catalog.md): find tools by gameplay problem.
- [`../guides/ai_composition_workflow.md`](../guides/ai_composition_workflow.md): task contract for AI and humans.
- [`../guides/composition_recipes.md`](../guides/composition_recipes.md): concrete cross-component patterns.
- `docs/components/` and `docs/modules/`: canonical technical contracts and limits.
- `AGENTS.md`: coding conduct and acceptance proof, unchanged by this routing layer.
