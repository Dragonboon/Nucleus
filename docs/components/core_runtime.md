# Core Runtime Contract

## Scope

This document covers:

```text
core/application
core/platform
core/window
core/diagnostics
core/utils
```

These systems provide process-wide infrastructure and small stateless helpers.
They should not become a Service Locator for game-facing systems.

## Ownership and lifetime

`NucleusApp` is a project Autoload because application lifecycle events genuinely
span scene changes. Platform, path, window, logging, and general utility classes
are primarily stateless APIs and should be called directly.

Scene-owned gameplay systems must not reach into a global registry to discover
each other.

## Application lifecycle

The application layer owns process-level startup/quit behavior. Games should use
it for lifecycle concerns rather than duplicating platform-specific shutdown
handling in scenes.

It does not own gameplay state.

## Platform and paths

`NucleusPlatform` centralizes runtime capability/platform queries.

`NucleusPaths` centralizes writable user-data locations:

```text
logs
saves
screenshots
settings
```

Project assets continue to use `res://`.

Prefer capability checks over scattered operating-system name comparisons.

PC gaming handhelds are classified on demand by `NucleusHandheldDetector`
through `NucleusPlatform.get_handheld_info()`. The classifier preserves
uncertainty; it never sets rendering quality or assumes Steam OS implies
Valve hardware. See [handheld detection](handheld_detection.md).
Web-specific restrictions should be handled at the boundary where a feature is
requested.

## Window helpers

`NucleusWindow` contains stateless viewport/desktop-window calculations and
still-image viewport capture.

Godot's:

```text
Viewport
Window
DisplayServer
RenderingServer
Image
```

remain the underlying source of truth.

Screenshot capture follows this boundary:

```text
Viewport last rendered texture
→ Image
→ optional PNG/JPEG/WebP save
```

For a current rendered frame, use the async helper that waits for
`RenderingServer.frame_post_draw`.

The default save directory comes from `NucleusPaths.screenshots_directory()`.
Directory creation reuses `NucleusFileUtils`.

Screenshot capture performs a rendering-data readback and is intended for
occasional still images. It is not a video/trailer recorder and should not run
every frame.

Any Viewport may be supplied, including a dedicated high-resolution
`SubViewport`.

## Diagnostics

`NucleusLog` is the stable logging facade.

Its basic severity methods stay aligned with Godot:

```text
debug
info
warning → push_warning
error → push_error
```

Warnings/errors cannot be hidden by the Nucleus minimum-level filter.

`NucleusLogFormatter` provides bounded deterministic formatting for development
snapshots. `NucleusDebugTable` formats bounded plain-text tables.

Optional call-site prefixes are a debug convenience and are disabled by default.

`NucleusFileLogger` integrates with Godot's native `Logger` API when file capture
is installed. It remains thread-safe, non-recursive and plain text. Runtime log
files include process identity so multiple local processes can be distinguished.

Logging is diagnostic infrastructure, not an event system, telemetry backend or
service locator.

Detailed contract:

```text
docs/components/diagnostics.md
```

## Utilities

The utility layer includes narrowly scoped helpers such as:

```text
arrays / dictionaries
nodes
files
time
UUID identity
semantic versions
random geometry
enum helpers
```

For exact integer quantity arithmetic and abbreviated numeric presentation,
use `NucleusBoundedIntMath` and `NucleusNumberFormatter`, respectively. Their
limits, rounding behavior, localization boundary, and examples are documented
in [`numeric_utilities.md`](numeric_utilities.md). Neither is a global service
or an incremental-game system.

Use native Godot APIs directly when they already express the operation clearly.
A utility belongs here only when it removes repeated project code without hiding
important engine behavior.

## Thread/process assumptions

Unless an individual API explicitly documents otherwise, treat the application
and SceneTree-facing infrastructure as main-thread code. Pure value helpers may
be used wherever the Godot API they call is thread-safe.

Rendering capture is main-thread/render-frame work.

`NucleusFileLogger` is the exception explicitly designed for Godot Logger
callbacks that may arrive across threads.

## Extension rule

Add a helper when the operation is broadly reusable and stateless. Add an
Autoload only when cross-scene lifetime is intrinsic to the responsibility.
