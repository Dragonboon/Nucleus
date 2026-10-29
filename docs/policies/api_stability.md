# Nucleus API Stability Expectations

## Current stability level

Nucleus is usable but currently **pre-1.0**.

The public surface is documented and tested, but production use may still reveal
contracts that should change before a stable 1.0 declaration. Pin the Nucleus
version or source commit used by a game.

## Public API

Unless a technical document says otherwise, these are public contracts:

```text
Nucleus-prefixed class_name types
mandatory default Autoload names and documented methods/signals
documented public methods and signals on reusable addons/nucleus/components/resources
documented exported properties whose values serialize into scenes/resources
documented settings/save schema boundaries
documented reusable scene/resource entry points
```

Public does not mean immutable before 1.0. It means a change requires an
intentional version decision plus updated contract/migration documentation.

## Internal API

The following are not compatibility contracts by default:

```text
underscore-prefixed functions and fields
private scene child names
implementation-only script paths
tests and test helpers
CI and release scripts
validation fixtures
undocumented implementation Resources
```

Internal code may change without deprecation when public behavior is preserved.

## File paths

Nucleus is a Godot addon. Paths matter through `project.godot`
or serialized Godot resources.

Paths explicitly referenced by project configuration or public documentation are
integration contracts. Other implementation paths should not be used as an API
when a `class_name`, Resource, scene, or documented service exists.

## Autoload stability

The baseline Autoload names are:

```text
NucleusApp
NucleusSettings
NucleusInput
NucleusAudio
NucleusSave
NucleusSceneFlow
```

Changing/removing one is a public-contract change. Optional modules do not
become baseline dependencies merely because they expose public Nucleus classes.

## Signals over hidden global coupling

Local signals are preferred public integration points for scene-owned systems.
The optional EventBus is not a compatibility substitute for direct component
contracts.

## Source ownership in a consuming game

Install Nucleus under `addons/nucleus/` in an existing or new game repository.
Keep game-owned code outside the addon; prefer composition over editing vendor code.

A consuming game may modify any source. Once it does, automatic upgrades from a
newer Nucleus release are not guaranteed. Upgrades should be selective merges
guided by current technical docs, migration notes when present, release notes,
and Git history.

## 1.0 threshold

Nucleus should not declare 1.0 solely because its feature list is large. A stable
1.0 is appropriate after real games have exercised the baseline, recurring API
friction has been resolved, public/core boundaries have proven durable, and
release/migration processes have been exercised.
