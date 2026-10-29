# Manage the Nucleus addon

Enable **Nucleus** in Project Settings > Plugins. The **Nucleus** editor dock has
**Manage** and **Localization** tabs. It replaces the earlier separate localization
plugin. Management never adds runtime services beyond the existing six Autoloads.

## Choose a dimensional profile

Select **Full**, **2D only** or **3D only**, then click **Preview profile**. The
preview lists the exact source and UID files that would be physically removed.
The corresponding dependency-closed inventory is generated from explicit resource
paths and Nucleus class references. Dependent optional adapters are removed too;
core, editor tools and shared gameplay/UI infrastructure remain.

UI is shared: 3D games still need menus, text, inventory UI and canvas effects.
Core settings adapters may retain native 3D preference APIs. These are code
profiles, not custom Godot engine builds or guarantees about export binary size.

Applying refuses local addon modifications/unmanaged files and scans host scripts,
serialized resources, UIDs, configuration and other addons for references to
removed classes/resources. A consuming game owns the decision to remove or replace
those uses. In the development repository, examples/tests can therefore block a
profile; use the package in a consuming project for dimensional installs.

Review dynamically constructed paths/class names yourself: static scans cannot
prove code that assembles resource identifiers at runtime. Previewing does not
execute optional scripts or change project files.

**Apply profile** requests confirmation of the physical change. Stop the running
game and wait for Godot imports. The manager retains a complete verified source
cache and prepares a candidate outside the active addon; it then moves the old
folder to a backup and swaps the candidate into place. Failed swaps restore the
previous folder. Reopen the editor after applying to refresh all classes/UIDs.
You can move between 2D, 3D and Full using the retained source cache.

## Update from stable main

1. Click **Check stable main**. No background network requests run on dock startup.
2. The updater resolves `main` and the latest successful `push` run of
   `nucleus-ci.yml` on main (among the 20 returned successes).
3. It verifies the successful commit is still an ancestor of the resolved main
   head. If main has a failing/newer build, the last successful ancestor is used.
4. It fetches `addon_manifest.json` and the source ZIP from that immutable SHA,
   using fixed HTTPS URLs in `Dragonboon/Nucleus`. It requires the supported Godot
   minor line and compatible inventory schema. Current identical inventories
   show **already up to date**. A main revision predating this manager cannot be
   installed automatically.
5. Click **Download and verify update**. Path traversal, duplicate/case-colliding
   paths, links, oversized ZIPs, unsupported ZIP variants, missing files, size/hash
   mismatches and unexpected addon contents are rejected. Staged scripts are not
   imported or executed. The embedded manifest must match the pinned manifest.
6. Review the version and profile preview, then **Apply prepared update**.
   The selected dimensional profile is preserved. Local vendor modifications or
   host references to deleted files block replacement. Reopen the editor afterwards.

The updater does not change the host main scene, InputMap, audio layout, renderer,
physics settings, translations or arbitrary other addons. HTTP/rate-limit failures
and cancellation leave the active addon unchanged. Retry the operation after
addressing the reported error. Updates are trusted repository code; file hashes
verify consistency with the selected commit, not an independent publisher signature.

## Backups and recovery

`addons/nucleus/installation_profile.json` travels with a trimmed addon in version
control, so another checkout can identify its profile without local caches.
`.nucleus/installation.json` records the selected profile, pinned update SHA,
verified source cache and previous backup. `.nucleus/.gdignore` prevents backup
and staged classes from being imported as duplicate scripts. Keep `.nucleus/`
out of version control; the development repository already ignores it.

**Restore previous installation** verifies the previous inventory and uses the
same staged swap, with a backup of the current installation. Retain source caches
while switching profiles or rolling back. A fresh checkout without caches can
download verified main source to restore dimensions or upgrade the addon. Source and backup disk space is separate
from the trimmed addon; remove old backups manually when no longer needed.

If an editor or operating-system crash interrupts a swap, close Godot and inspect
`.nucleus/backups/<transaction>/nucleus/` and `previous_state.json`. Restore that
folder to `addons/nucleus/` and the saved state to `.nucleus/installation.json`
before reopening. Never copy backups under `addons/` alongside the active copy.
The manager reports rollback errors with the exact backup path.

## Development validation

Run `python3 scripts/ci/build_addon_manifest.py` after changing shipped files,
then `--check` in CI. The inventory covers every shipped file except itself and
build-generated release metadata. UIDs and all profile dependency edges are tracked.

The isolated `check_addon_management.py` gate verifies physical pruning, host
reference protection, local edit protection, profile switches, backup restoration,
staged updates, corrupted archives and fresh imports/resource loads for each
retained profile. The ordinary complete headless suite still runs separately.
