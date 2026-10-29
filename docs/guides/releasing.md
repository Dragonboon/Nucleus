# Releasing and Packaging Nucleus

## Release artifact

Nucleus releases are **Godot addon packages**, not exported games.

Game exports in CI are smoke tests that prove project exportability. They are
separate from the Nucleus addon archive.

Generate a package with:

```bash
python3 scripts/package_release.py
```

Default outputs:

```text
dist/releases/Nucleus-<version>.zip
dist/releases/Nucleus-<version>.zip.sha256
```

The package version comes from the root `VERSION` file.

## Package contents

The package contains only Git-tracked files under `addons/`, with no outer
wrapper. Development documentation, examples, tests, labs and the root project
are excluded. LICENSE and VERSION are included inside the main addon. This prevents local caches,
untracked experiments, credentials, game prototypes, or editor state from
entering a release.

Generated/cache/output directories such as these are excluded:

```text
.git/
.godot/
.ci/
build/
dist/
__pycache__/
```

The archive includes `addons/nucleus/RELEASE_MANIFEST.json` with the Nucleus version, source
commit, dirty-state marker, Godot reference, file count, SHA-256, and size for
every packaged source file.

ZIP ordering and timestamps are normalized so the same tracked content can
produce reproducible packages.

## Clean-tree requirement

Official packages require a clean Git working tree.

For local packaging experiments only:

```bash
python3 scripts/package_release.py --allow-dirty
```

Do not publish a dirty package.

## Validation

By default, packaging runs:

```text
scripts/ci/static_checks.py
scripts/ci/documentation_audit.py
scripts/ci/productization_audit.py
```

It does not duplicate expensive Godot runtime/export CI. An official release
requires the corresponding commit to have a green `Nucleus CI` run.

Use `--skip-validation` only when validation already ran in the same trusted
automation job.

## Manual GitHub package workflow

The repository includes:

```text
.github/workflows/nucleus-package.yml
```

It is `workflow_dispatch` only. It creates a versioned package artifact but does
not automatically publish a GitHub Release.

## Stable release checklist

1. Confirm Nucleus CI is green on the target commit.
2. Update `VERSION` to the release version.
3. Review compatibility, deprecation, and migration documentation.
4. Commit the release metadata and run CI again.
5. Run the package workflow or local package script.
6. Verify the generated `.sha256`.
7. Tag the exact commit as `v<VERSION>`.
8. Create concise GitHub Release notes from the shipped changes.
9. Attach the ZIP plus checksum to the GitHub Release when publishing binaries.

Nucleus does not keep iteration journals or a committed changelog in the addon
source. Git tags, pull requests, commits, and GitHub Release notes retain
history without mixing planning records into user documentation.

## Prereleases

Prerelease versions are valid:

```text
0.13.0-dev.1
0.13.0-alpha.1
0.13.0-rc.1
```

Use them when a game needs a reproducible Nucleus snapshot before the public API
is ready for a stable release.

## Consuming-game releases

A game built on Nucleus owns its own versioning, export presets, store metadata,
signing, and release process. Do not use the Nucleus addon `VERSION` as the
game's version.
