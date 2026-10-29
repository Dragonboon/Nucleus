# Save Quickstart

Nucleus separates global storage/format policy from scene-owned game-state
capture. For the complete format, backup, migration, security and failure
contract, see [Save System](../components/save_system.md).

## 1. Find the save directory

The default Save Profile in `addons/nucleus/core/save/save.tscn` leaves `base_directory` empty,
so the application resolves the root as:

~~~gdscript
OS.get_user_data_dir().path_join("saves")
~~~

For the stock `Nucleus` project on Windows, this is typically
`%APPDATA%\Godot\app_userdata\Nucleus\saves\`. It is **not** in `res://`.
Use the runtime value when the project or profile changes:

~~~gdscript
print(NucleusSave.profile.base_directory)
~~~

To override it, edit `addons/nucleus/core/save/defaults/default_save_profile.tres` and set
`base_directory` to an absolute writable directory. Do so before shipping
saves; changing locations later requires a game-owned migration.

By default, a `slot_1` manual save is `slot_1/manual.nsav` under that root;
quick saves use `quick.nsav` and autosaves live under
`slot_1/autosaves/auto_<unix_time_ms>.nsav`. The profile defaults to binary
format, two manual/quick backups, no encryption and schema version 1.
Alternative codecs use `.nsv` (Variant text) or `.json`; encrypted files add
`.pwd` or `.key`.

## 2. Choose the entry point

Use `NucleusSave` when you already have a plain-data payload:

~~~gdscript
var result: NucleusSaveResult = NucleusSave.save_manual(
    "slot_1",
    {"level": 2, "coins": 25},
)
if not result.succeeded():
    push_error(error_string(result.error))
~~~

Use `NucleusSaveSession` when several systems own independent capture/restore
state:

~~~text
GameSession
├── SaveSession : NucleusSaveSession
├── Player
├── Inventory
└── WorldState
~~~

Register explicit participants:

~~~gdscript
save_session.register_participant(
    &"player",
    player.capture_state,
    player.restore_state,
)
~~~

The save service never scans the SceneTree to discover gameplay state.

## 3. Use save-safe data

Prefer booleans, numbers, strings, arrays, string-keyed dictionaries, stable
IDs and explicit snapshots. Do not persist Nodes, Objects, Callables, Signals,
RIDs or transient instance IDs. JSON additionally rejects Godot-specific types
such as `Vector3` or `Color`; binary and Variant text are better when those
types must be preserved. Keep presentation metadata separate using
`save_session.set_metadata_provider()`.

## 4. Manual, quick and autosave

Synchronous scene-session methods are:

~~~text
save_manual()
save_quick()
autosave(force = false)
~~~

They suit small/medium snapshots and lifecycle boundaries that must complete.
The global storage equivalents also accept slot ID and a Dictionary payload.

`NucleusAutosavePolicy` defaults to enabled, 120-second timer, three retained
autosaves, five-second minimum interval, pause/quit saving, and no save on focus
loss. Its lifecycle autosaves remain synchronous. An autosave can be skipped
(`ERR_BUSY`) when disabled, throttled or already in progress. Configure policy
on the session and call `refresh_autosave_policy()` after changing it at runtime.

Manual and quick saves rotate up to two backups by default (`.bak1`/`.bak2`);
autosaves are timestamped and pruned instead. Writes use a temporary file and
rename. See the [Save System contract](../components/save_system.md) for
integrity and backup-recovery guarantees.

## 5. Continue / resume the newest snapshot

To restore whichever successfully loaded kind is newest:

~~~gdscript
var result: NucleusSaveResult = save_session.load_latest()
if not result.succeeded():
    push_error(error_string(result.error))
~~~

Nucleus compares microsecond update timestamps first and uses the order
`AUTOSAVE`, `QUICKSAVE`, `MANUAL` only for exact ties. Older documents with
whole-second timestamps remain compatible.

To restrict kinds, use the service or session equivalent:

~~~gdscript
var result: NucleusSaveResult = NucleusSave.load_latest(
    "slot_1",
    PackedInt32Array([
        NucleusSaveTypes.Kind.MANUAL,
        NucleusSaveTypes.Kind.AUTOSAVE,
    ]),
)
~~~

This chooses among the latest valid candidates per kind; it is not an
exhaustive scan of historical autosaves. See
[Resume Selection](../components/save_resume.md).

## 6. Budget large captures

If participant capture causes a frame spike:

~~~gdscript
var result: NucleusSaveResult = await save_session.save_manual_incremental(8)
~~~

Or drive the capture job yourself:

~~~gdscript
var job: NucleusSaveCaptureJob = save_session.create_capture_job()
while not job.is_completed():
    job.step(8)
    await get_tree().process_frame

var payload: Dictionary = job.take_snapshot()
~~~

`capture_snapshot_incremental(8)` and incremental quick/autosave helpers are
also available. Participants are captured across frames **on the main thread**;
file writing is still synchronous. Participants added after a capture job starts
belong to the next snapshot. Pause/quit saves intentionally remain synchronous.

## 7. Restore, migrate and diagnose

Loaded participant payload remains pending, allowing participants registered
after `apply_snapshot()` to receive their state. Restore dependencies before
dependents when their order matters.

Payload schema upgrades use `schema_version` and registered
`NucleusSaveMigration` resources. Eligible migrated manual/quick saves may be
rewritten; autosaves are not automatically rewritten.

Always inspect `result.error`; on success also inspect
`result.recovered_from_backup` and `result.migrated` when relevant. The
Save Profile's password/key credentials must be configured at runtime before
loading encrypted saves; they are never stored in the profile.

Hands-on: [Save Tutorial](tutorials/save_system.md).
