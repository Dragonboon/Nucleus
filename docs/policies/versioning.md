# Nucleus Versioning Policy

## Scope

Nucleus versions the reusable **addon**, not the game created from it.

The source of truth is the root `VERSION` file. Do not couple that version to a
consuming game's `application/config/version` or release number.

## Scheme

Nucleus uses Semantic Versioning:

```text
MAJOR.MINOR.PATCH
```

Prerelease identifiers are valid:

```text
0.13.0-dev.1
0.13.0-alpha.1
0.13.0-rc.1
```

Git tags use the same version with a `v` prefix. The tag and `VERSION` must match
apart from that prefix.

## Before 1.0

Real consuming projects are still part of API discovery.

For `0.x` releases:

- PATCH is for fixes and documentation corrections without an intentional
  public-contract break;
- MINOR may add public API or intentionally revise a public contract;
- migration guidance is required when commonly used public contracts change;
- deprecation periods are best-effort rather than guaranteed.

A consuming game should pin the exact Nucleus version or source commit it uses.

## From 1.0 onward

After `1.0.0`:

- PATCH contains backward-compatible fixes;
- MINOR adds backward-compatible functionality and may introduce deprecations;
- MAJOR may remove deprecated APIs or otherwise break public contracts.

Changing the minimum supported Godot minor version is a compatibility break
after 1.0 unless the previous line remains release-gated.

## What drives a version bump

Public API is defined in `docs/policies/api_stability.md`.

Examples that require a version decision include:

```text
renaming/removing a public Nucleus class_name
renaming/removing a documented public method or signal
changing required Autoload names
changing exported property meaning or serialized representation
changing documented save/settings contracts
raising the minimum supported Godot version
changing required default project wiring
```

Private helpers, tests, CI scripts, implementation details, and undocumented
underscore-prefixed members do not independently require a compatibility bump.

## Release discipline

Before tagging a release:

1. update `VERSION`;
2. verify compatibility, deprecation, and migration documentation;
3. require a green Nucleus CI run;
4. generate the release package;
5. verify its SHA-256 checksum;
6. prepare concise GitHub Release notes from the merged work when useful;
7. tag the exact packaged commit.

Historical iteration logs are not part of the addon source. Git history,
pull requests, tags, and release notes provide project history; repository docs
remain focused on using and maintaining the current Nucleus contract.
