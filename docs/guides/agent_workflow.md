# Development tooling for humans and agents

[Agent entry point](../../AGENTS.md) · [Detailed contract](agent_development_contract.md)

These offline Python tools are development-only. They add no runtime dependencies,
Autoloads, external model service, network retrieval or game policy. The registry
owners remain documentation_coverage.json, use_case_registry.json, addon_manifest.json
and actual source/tests. No parallel hand-maintained capability registry is introduced.

## Feature contract

Before editing, record this in work notes or the PR:

```text
Problem and concrete before/after acceptance:
Native owner and existing Nucleus adapter:
Game-owned policy and actual missing capability:
State owner and explicit scene bindings:
Public/API/save compatibility:
Independent consumer scenarios:
Reproduction and composition test:
Unavailable device/export evidence:
```

## Discover and retrieve focused context

```bash
python3 tools/development/nucleus_dev.py context NucleusAdventureSession
python3 tools/development/nucleus_dev.py context inventory
```

Returns up to three matched subsystem owners, actual declared classes/signatures,
existing guide/use-case routes (including game-owned policy), addon dependencies
and referencing tests/examples. Search is deterministic keyword matching, not a
semantic model. An empty result means inspect source with rg, not invent an API.
References can occur in comments: they are discovery hints, never proof that a
scene binds the component or that the referenced test covers a behavior. Limitations,
required native nodes and error semantics must be read in the returned guides/source.
Read only relevant domain guides plus the compact agent entry point.

## Select validation by change

```bash
python3 tools/development/nucleus_dev.py plan --base origin/main
python3 tools/development/nucleus_dev.py plan --base origin/main --run --engine godot
```

The plan includes committed changes since the selected base, local index/worktree
changes and untracked files. It computes reverse dependencies from the existing
addon manifest, then finds referencing native suites and smoke scenes. Affected
suite filenames are selected only from the native test manifest. The runner also
supports explicit filters:

```bash
python3 scripts/ci/run_godot_checked.py godot --headless --path . \
  res://tests/headless/test_runner.tscn -- --nucleus-suites=image_screen_test.gd,adventure_session_test.gd
```

Empty or unknown explicit suite filters fail; no filter runs the full manifest.
Core/editor/tooling/CI changes, deleted or unindexed addon files, unknown code and
unresolved runtime coverage fall back to the full headless battery and smoke scenes.
Docs-only plans run audits without importing Godot. Review a plan before --run;
subprocess failures/timeouts stop execution. Selection is conservative local feedback,
not certification and not a replacement for full CI, native editor/install, export,
network/physical-device and GPU checks. Regenerate the dependency manifest after
addon changes; stale inventories fail the plan's audit rather than silently pass.

## Public declarations and compatibility

```bash
python3 tools/development/nucleus_dev.py api
python3 tools/development/nucleus_dev.py api --check
python3 tools/development/nucleus_dev.py api-diff --base origin/main
```

`docs/api_surface.json` is generated from top-level Nucleus class declarations:
public method signatures, signals and exported declarations. Private methods,
method bodies and nested classes are excluded. It is a lexical inventory, not a
GDScript parser, inherited Godot API, documentation of every public property or a
proof of semantic/serialization compatibility. Native import/tests remain required.
The source comparison reads the actual base revision, including revisions before
the snapshot existed. It reports additions, removals, moved classes and changed
signatures/defaults. Additions still need subclass/consumer review.

Changed/removed declarations fail without a tracked Markdown decision passed via
`--decision`. That document needs `## Compatibility`, `## Version`, `## Migration`
and `## Consumers` sections; review must verify their substance. The decision must be updated relative
to the base; an unchanged old decision cannot approve a new change. CI uses
`docs/policies/api_change_decision.md` as the decision path. Merely satisfying
headings is not approval, and behavioral breaks can exist without declaration changes.
Use the existing version/deprecation policy. Never bless a regenerated snapshot
as evidence that a breaking change is compatible.

## Verify real composition and independent consumers

The existing test base now offers `expect_composition_binding`,
`expect_composition_signal` and `expect_single_binding`. They inspect native Node
properties and Signal connections. Callers explicitly declare candidate owners;
no tool can infer every transform/state writer in arbitrary scripts. Exercise
behavior and teardown too, and never label a static scan a successful composition.

`composition_contracts_test.gd` proves wiring failures and two independent policies:
a one-way image catalog and an inspection view with explicit return navigation.
The real point-click smoke proves GUI dispatch separately. These are isolated
validation fixtures, not game starters or required addon content. New capabilities
need their own consumer scenarios; two copies of the same game are not sufficient.

## Evaluate effectiveness using measured work

Use the same pinned starting revision, engine, task scope and acceptance criteria
for baseline and candidate runs. Preserve raw evidence/review notes. Repeat tasks
across runtime, UI, editor, optional-module and persistence changes; do not mix
unrelated tasks or treat synthetic examples as measurements.

Representative task bank (define an isolated fixture and acceptance before each run):

| Task | Acceptance evidence |
| --- | --- |
| Extend an image view with deterministic return | Real viewport input, multiple aspect ratios, no trapped page |
| Fix a stale UI binding after tree reentry | Actual attachment, disconnect/rebind, no duplicate callback |
| Add an optional subsystem adapter | Baseline remains installable without its optional dependency |
| Reject malformed save state | Failure before mutation; original committed state preserved |
| Add an editor action | Native UndoRedo/ownership, repeated invocation and existing-host test |

Store real paired observations outside the public source tree, then run:

```bash
python3 tools/development/nucleus_dev.py evaluate /path/to/measurements.json
```

Schema (replace values with actual measurements; the sample is not benchmark data):

```json
{"records":[{"task":"unique-task-id",
  "baseline":{"minutes":12,"corrections":2,"regressions":0,"invented_apis":0,"scope_violations":0,"first_pass":false},
  "candidate":{"minutes":6,"corrections":0,"regressions":0,"invented_apis":0,"scope_violations":0,"first_pass":true}}]}
```

The tool rejects missing, duplicate, empty, nonfinite and negative observations.
It reports median duration, paired speed ratios, first-pass rate, correction counts,
regressions, invented APIs and scope violations. There is no fabricated combined
quality score or automatic telemetry. Paired observations alone do not establish
causality, broad statistical confidence or a 200% improvement. No effectiveness
percentage is claimed by this change.
