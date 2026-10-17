# Agent prompt playbook: build games with Nucleus

**Purpose:** make a coding agent productive quickly without trading away
correctness, maintainability, accessibility or test evidence. These prompts
extend the mandatory [agent operating contract](../../AGENTS.md); they do not
replace or override it.

Nucleus is a Godot 4.7.2-stable **foundation, not a game generator**. Native
Godot owns engine primitives, Nucleus owns reusable contracts, and each game
owns its rules, levels, art and interaction design. A good prompt makes that
boundary explicit and asks for a small, observable result.

> [!TIP]
> **Fast path:** copy the [task preamble](#task-preamble) once when opening a
> coding task, then use one [stage prompt](#copy-ready-stage-prompts) at a time.
> For worked 2D, turn-based and 3D sequences, see
> [worked prompt sequences](agent_prompt_examples.md).

## Choose the next prompt

| Your next decision | Use |
| --- | --- |
| Turn an idea into a prioritized backlog | [1. Discover use cases](#1-discover-use-cases) |
| Identify the existing Godot/Nucleus API | [2. Inspect and route](#2-inspect-and-route) |
| Make one mechanic playable | [3. Deliver a vertical slice](#3-deliver-a-vertical-slice) |
| Add a second mechanic without regressions | [4. Compose the next iteration](#4-compose-the-next-iteration) |
| Reproduce and fix a bug | [5. Repair a regression](#5-repair-a-regression) |
| Confirm quality before the next feature | [6. Harden and validate](#6-harden-and-validate) |
| Optimize based on evidence | [7. Measure and polish](#7-measure-and-polish) |
| Decide whether a feature belongs in Nucleus | [8. Propose shared extraction](#8-propose-shared-extraction) |
| Continue after another session or contributor | [9. Resume from a checkpoint](#9-resume-from-a-checkpoint) |

## Task preamble

Supply the project facts **once** at the start of a new task. Replace the
bracketed values; delete facts that do not apply. For follow-up iterations,
refer to the same accepted constraints rather than reposting the entire plan.

~~~text
Project: [game repository and branch, or Nucleus itself].
Engine: the version pinned by this checkout (currently Godot 4.7.2).
Game concept: [genre, 2D/3D, camera, platform, one-sentence player loop].
Current goal: [one player-visible behavior].
Constraints: [controls, save/network needs, art assets, target hardware].
Git permission: [inspect only / edit locally / commit to named branch].
CI permission: [local checks only / explicitly permitted workflows].

Follow this repository's AGENTS.md and CRISP (Context, Role, Inspection,
Standards, Proof). First inspect HEAD and changes, the use-case catalog,
real source signatures, the nearest scene/test and the relevant contract.
Before edits, give a compact ownership map: Godot native | existing Nucleus
owner | game-owned policy | genuine gap. Prefer existing Nodes, Resources,
signals and Godot facilities; one writable owner per behavior. Keep game
mechanics under the consuming game's game/ directory. Do not invent APIs,
add an Autoload, fork a Nucleus component or broaden scope without evidence.

Implement the smallest runnable slice with its failure cases, regression
checks and game-facing feedback. Execute only permitted validation. Report
changed files, observed evidence, unrun checks, risks and next single slice.
Never claim that passing unit tests proves visuals, feel or performance.
~~~

> [!IMPORTANT]
> **Checkout matters.** A derivative game is not the Nucleus repository. Do
> not change the shared template for game-specific content. Do not push or
> trigger GitHub workflows without explicit authorization; a push to a
> CI-enabled branch may itself trigger workflows, so check repository policy.

## Copy-ready stage prompts

The examples assume the task preamble is already active. Each stage states
**one goal and a stopping condition**. When a stage passes its gate, proceed
to the next; if it fails, repair it before adding more features.

### 1. Discover use cases

~~~text
Turn this game idea into 6–10 observable player/designer use cases:
[idea]. For each, state "When [event], [player-visible result]",
the existing Nucleus or native owner to inspect, game-owned rules,
failure cases, how to verify it and key dependencies.
Do not write code yet. Rank by player value, uncertainty and dependency.
Choose one minimal playable loop and split it into three independently
verifiable vertical slices. Identify what must NOT be built for slice one.
~~~

**Gate:** a prioritized list with observable behavior, ownership candidates
(not invented API guarantees), testable outcomes and a deliberately small
first slice. Use the [use-case catalog](use_case_catalog.md) to route features.

### 2. Inspect and route

~~~text
For the selected use case [behavior], inspect the current HEAD, the exact
Nucleus/Godot symbols and the closest caller, scene and regression test.
Show an ownership map, minimal Node/Resource scene tree, signal/data flow,
runtime and persistence ownership, and negative cases. Separate verified
APIs from assumptions. Decide reuse vs. one small game adapter vs.
a documented missing general mechanism. No implementation yet.
~~~

**Gate:** no duplicated transform, action, navigation, UI state or save
authority; the wiring plan names real source files and existing APIs.

### 3. Deliver a vertical slice

~~~text
Implement only [specific observable behavior] in the consuming game.
Reuse the inspected contracts. Add or wire one real scene, the smallest
game-owned rule script, and a regression test or executable acceptance
scene. Cover at least one success, one rejection and teardown/retry where
applicable. Keep existing saves, controls and scenes compatible.
Run the allowed local checks. Stop when the actual scene reproduces the
behavior; report proof and do not start the next backlog item.
~~~

**Gate:** real scene wiring and an observable pass/fail, not just code
generation or "should work" prose. Use the
[composition verification guide](composition_verification.md).

### 4. Compose the next iteration

~~~text
The previous slice is accepted. Add only [next behavior] to [actual scene].
First inspect its current owners and HEAD, then reuse those owners rather
than building parallel managers. List integration points and regressions:
actions/costs/status, movement/AI, UI/focus, save/load and multiplayer only
where relevant. Test the existing loop plus the new behavior. Preserve
the original acceptance gate. Record a brief checkpoint for iteration N+1.
~~~

**Gate:** both old and new loops still pass. Do not introduce new components
merely because multiple mechanics coexist.

### 5. Repair a regression

~~~text
Investigate [bug and reproduction]. Compare expected and observed behavior.
Locate the single owning component or invalid scene binding. Add a failing
regression first where feasible. Fix the smallest cause without disabling
checks or bypassing Nucleus/Godot ownership. Validate related actions,
restore/teardown and negative paths. List exactly what was run and what
remains unverified.
~~~

**Gate:** reproducible before/after evidence, no unrelated rewrite.

### 6. Harden and validate

~~~text
Audit the accepted slices as one game loop. Check input and focus,
resource costs/cooldowns, repeated interactions, cancellation, missing
assets/nodes, scene disposal, save/load compatibility, network authority
if relevant, and UI accessibility. Add only tests/fixes supported by
observed gaps. Run static/documentation audits, Godot import/headless
and the actual composed gameplay scene as available. Report per-check
PASS, FAIL or NOT RUN with the reason. Do not declare release readiness
from headless tests alone.
~~~

**Gate:** no unexplained critical failures and an explicit list of manual,
device, multiplayer and platform checks still needed.

### 7. Measure and polish

~~~text
Measure [scene/metric/target device] under a repeatable workload and
capture the baseline. Check readability, focus, controller navigation,
contrast, reduced-motion choices and input feedback. Use existing
Nucleus diagnostics and Godot profilers. Optimize only the observed
bottleneck without changing game rules or hiding visual regressions.
Repeat the same workload and compare measurements. If measurement is
unavailable, report NOT MEASURED instead of promising faster performance.
~~~

**Gate:** before/after evidence and no regression in behavior/accessibility.
Quality means verified behavior and suitable presentation, not file count.

### 8. Propose shared extraction

~~~text
We implemented [mechanic] in the game. Compare it against current Nucleus
contracts and identify two independent games that need the same generic
mechanism. Show what is game-specific, what may be reusable, ownership,
compatibility, minimal API, tests and documentation cost. Propose a small
optional adapter only if native Godot/existing Nucleus cannot cover it.
Do not modify Nucleus main or publish an API without explicit approval.
~~~

**Gate:** a justified reuse boundary, not a genre manager.

### 9. Resume from a checkpoint

~~~text
Continue the accepted game work from this checkpoint:
[repository, commit, scene, completed slices, accepted tests, pending issue].
Verify the current HEAD and changes before touching files. Reinspect only
the contracts implicated by this slice or any changed dependencies.
Choose the smallest pending acceptance criterion, implement and test it,
then publish a new checkpoint. Preserve the approved scope and Git/CI rules.
~~~

**Gate:** no lost constraints, fabricated prior tests or duplicated
framework components.

## Iteration contract: quality at every step

For each slice, keep this concise record in the task, game planning notes
or commit description; it is **not** a journal to add to Nucleus itself.

| Field | Record |
| --- | --- |
| Behavior | When [trigger], the player can observe [result] |
| Ownership | Godot native / Nucleus / game rule / single mutable owner |
| Scope | Included; deliberately deferred |
| Acceptance | Real scene, input or event and expected observable result |
| Regression | Previous slice(s) that must remain valid |
| Evidence | Exact checks run and actual result; mark unrun checks |
| Checkpoint | Commit/branch, changed files, risks, next one slice |

A slice is not complete if it lacks a connected scene, cannot reject invalid
input, breaks an earlier loop, or claims performance/accessibility without
evidence. Use [local validation](validation_ci_quickstart.md), then real
device/player observation where required.

## Efficiency rules that do not lower quality

1. **Inspect once, reuse often:** use symbol-level searches and read source,
   callers and nearest tests rather than dumping the entire repository.
2. **Reduce simultaneous work:** one observable slice per iteration; defer
   polish and systems that do not unblock it.
3. **Ask for a decision, not a speculative framework:** prefer a tiny adapter
   under game/ over new Nucleus APIs and Autoloads.
4. **Batch related checks:** run relevant tests after a coherent change, and
   the full suite at integration milestones. Never substitute a static audit
   for an actual Godot scene check.
5. **Preserve checkpoints:** commit only with authorization and retain a
   concise owner map, validated behaviors and outstanding risks.
6. **Limit output noise:** request a short result report with changed paths,
   commands/results and the next highest-value slice. Keep details in docs
   and tests, not repetitive chat summaries.

There is no honest universal promise of "a finished game in record time".
The intended acceleration comes from **less reinvention, fewer integration
regressions and earlier measurable feedback**, while preserving quality gates.

## Continue reading

- [Worked prompts for three game types](agent_prompt_examples.md)
- [Agent/human composition workflow](ai_composition_workflow.md)
- [Game Development Use Cases](use_case_catalog.md)
- [Composition recipes](composition_recipes.md)
- [Architecture and owner selection](../architecture/component_selection.md)
- [Agent contract](../../AGENTS.md)
