# Save System Contract

## Ownership and entry points

`NucleusSave` is the application-wide Autoload for versioned save documents:
storage, codecs, validation, integrity, optional encryption, migration, backups
and slot operations. `NucleusSaveSession` is a scene-owned `Node` that gathers
game state through explicitly registered participants and restores it after load.
Neither service searches the SceneTree for gameplay state or defines game-specific
slot menus, progression, content or cloud-sync policy.

Use `NucleusSave.save_manual(slot_id, payload, metadata)` when a game already owns
a plain `Dictionary` payload. Use a `NucleusSaveSession` when the player, inventory,
world or other independent systems need capture/restore callbacks.

## Default directory and configuration

The effective root is `NucleusSave.profile.base_directory` **after** the
Autoload has entered the scene tree and initialized. Nucleus ships with
`addons/nucleus/core/save/defaults/default_save_profile.tres` assigned in `addons/nucleus/core/save/save.tscn`.
Its `base_directory` is empty, which resolves through
`NucleusSaveProfile.get_base_directory()` to:

~~~gdscript
OS.get_user_data_dir().path_join("saves")
~~~

`NucleusPaths.saves_directory()` is the corresponding helper. In the stock
project (named `Nucleus` in `project.godot`, without a custom user-data directory),
a typical Windows path is:

~~~text
%APPDATA%\Godot\app_userdata\Nucleus\saves\
~~~

This is **user data**, not `res://saves` or a directory alongside the executable.
The physical directory depends on operating system, project name, Godot's
application user-directory settings and any explicitly configured save root.

Inspect the path at runtime, after initialization:

~~~gdscript
print(NucleusSave.profile.base_directory)
print(NucleusPaths.saves_directory())
~~~

The first line is authoritative if the save profile overrides the root; the
second shows the platform-specific *default*. To change the root, set
`base_directory` in the Save Profile resource to an absolute writable directory
before the service initializes. The service duplicates the Resource at startup,
validates it, creates the root and returns `ERR_UNCONFIGURED` for save operations
if initialization fails. Changing the project name or save root after release
changes where Nucleus looks; migrating existing user files is game policy.

## Slots and on-disk layout

Save IDs are normalized with `NucleusSavePaths.sanitize_slot_id()`: trimmed,
lowercased, spaces replaced with underscores, unsupported characters replaced
with underscores, leading/trailing underscores removed, and truncated to 64
characters. An empty normalized ID is invalid for write/delete operations.
Choose stable slot IDs once a game has shipped.

The default **binary, unencrypted** layout for `slot_1` is:

~~~text
<resolved-save-root>/
└── slot_1/
    ├── manual.nsav
    ├── manual.nsav.bak1
    ├── manual.nsav.bak2
    ├── quick.nsav
    ├── quick.nsav.bak1
    ├── quick.nsav.bak2
    └── autosaves/
        ├── auto_<unix_time_ms>.nsav
        └── auto_<unix_time_ms>.nsav
~~~

Files appear only after the relevant save operation; the tree is illustrative.
Manual and quick writes replace the corresponding format-specific main file,
with up to `backup_count` retained `.bakN` backups. Autosaves receive timestamped
names and are pruned to the requested `max_slots`; they do **not** use the
manual/quick backup rotation. Writes use a `.tmp` file and filesystem rename.
The repository can load a valid backup after a failed manual/quick primary load;
`NucleusSaveResult.recovered_from_backup` reports that recovery.

`NucleusSave.list_slots()` lists slot directories;
`NucleusSave.list_autosave_paths(slot_id)` lists autosaves newest by file
modification time; `NucleusSave.delete_slot(slot_id)` recursively removes a
slot and returns an `Error`. Deletion is not an undoable operation.

## Formats and save profile defaults

| Setting | Shipped default | Notes |
| --- | --- | --- |
| `default_format` | `BINARY` | `.nsav`, type-preserving Godot Variant binary |
| Other codecs | `TEXT` / `JSON` | `.nsv` / `.json` |
| `backup_count` | `2` | Manual and quick saves |
| `max_file_size_mb` | `64` | Read-side file-size rejection |
| `encryption_mode` | `NONE` | Plain storage with SHA-256 corruption detection |
| `schema_version` | `1` | Application payload schema |
| `rewrite_migrated_saves` | `true` | Eligible migrated manual/quick documents |

Binary and Variant-text codecs preserve supported Godot Variant values; JSON
accepts only JSON-compatible values (for example strings, numbers, booleans,
arrays and string-keyed dictionaries). The JSON codec rejects unsupported
Variant types such as `Vector3` or `Color` rather than silently coercing them.

Payload and metadata dictionaries are validated before writing. Do not save live
Objects/Nodes, Callables, Signals, RIDs or non-string dictionary keys. Store
stable IDs and reconstruct runtime references on restore. Metadata is intended
for menu summaries, not authoritative gameplay state.

## Security and integrity

Every saved document has a SHA-256 checksum used to detect corruption.
**Checksum-only, unencrypted saves are not authenticated** and must not be
treated as tamper-proof or as a multiplayer authority boundary.

`NucleusSaveProfile.encryption_mode` also supports `PASSWORD` and `RAW_KEY`
(32-byte key), producing `.pwd` and `.key` suffixes respectively:

~~~text
manual.nsav.pwd
quick.nsv.key
auto_<unix_time_ms>.json.pwd
~~~

Provide credentials at runtime via `NucleusSave.configure_password(password)`
or `NucleusSave.configure_raw_key(key)` *before* reading or writing the encrypted
save. Passwords/keys are not stored in the Save Profile. Encrypted documents
also carry HMAC-SHA256 verification; mismatched credentials or integrity
failure make loading fail. Keep credentials recoverable through a game-owned
secure policy; losing them can make saves unreadable.

## Manual, quick, autosave and Continue

The global service exposes:

~~~gdscript
var saved: NucleusSaveResult = NucleusSave.save_manual(
    "slot_1",
    {"chapter": 2, "coins": 120},
    {"area": "Forest"},
)
if not saved.succeeded():
    push_error(error_string(saved.error))

var loaded: NucleusSaveResult = NucleusSave.load_latest("slot_1")
if loaded.succeeded():
    print(loaded.document.payload)
~~~

Other methods include `save_quick`, `save_autosave`, `load_manual`,
`load_quick` and `load_latest_autosave`. For participant-based scenes, use
`save_session.save_manual()`, `save_session.save_quick()`,
`save_session.autosave()` and `save_session.load_latest()`: successful loads
automatically route the payload to registered restore callbacks.

`load_latest()` tries the latest available candidate **per requested kind**,
selects the newest successfully decoded/verified document by microsecond update
timestamp, and uses the default kind order `AUTOSAVE → QUICKSAVE → MANUAL`
only to break identical timestamps. An explicit `PackedInt32Array` of kinds
limits eligible kinds and sets that tie order. Legacy whole-second timestamps
remain readable. A failed candidate can lose to a successful candidate from
another kind; this is **not** a scan of every older autosave. In particular,
`load_latest_autosave()` targets the newest autosave rather than automatically
trying the whole autosave history.

## Scene participants and autosave lifecycle

Register a stable ID, a capture Callable and an optional restore Callable:

~~~gdscript
save_session.register_participant(
    &"player",
    player.capture_state,
    player.restore_state,
)
~~~

`NucleusSaveSession` supports pending payload for late-registered restore
participants; register dependencies before their dependents if order matters.
`set_metadata_provider()` supplies display metadata separately.

Both synchronous and incremental capture use `NucleusSaveCaptureJob`, which
freezes participant IDs and callbacks at capture start. Replacing a callback
during capture affects the next snapshot; callbacks whose target has been freed
are skipped. This stabilizes registration, not the game world: incremental
capture still observes different participants on different frames.

Its default `NucleusAutosavePolicy` enables autosaving every 120 seconds, keeps
up to three autosaves per slot, enforces a five-second minimum between normal
successful autosaves, saves on application pause and quit, and does not
autosave on lost focus. `refresh_autosave_policy()` reapplies changed settings.
`autosave(force = true)` bypasses the minimum interval but still respects the
enabled flag; skipped saves return `ERR_BUSY` and emit `autosave_skipped`.

Removing a session from the scene tree stops its timer and disconnects app
pause/focus/quit listeners. Adding the same session back reuses its timer and
reconnects once. Participants and pending restore data remain attached to that
session instance. Free the session to end its lifetime permanently.

For many participants, `save_manual_incremental()`,
`save_quick_incremental()`, `autosave_incremental()` or
`capture_snapshot_incremental(participants_per_frame)` distribute participant
capture across frames **on the main thread**; they do not make disk writing
asynchronous. Pause/quit-triggered autosaves intentionally use the synchronous
path because another frame might never arrive.

## Schema migrations and observable failures

`NucleusSaveDocument` includes a container version, save kind, slot ID, game and
engine versions, schema version, created/updated timestamps, metadata, payload
and integrity data. `schema_version` describes the consuming game's payload
contract; registered `NucleusSaveMigration` resources form an ordered chain
when loading an older payload. Loading a newer schema, or lacking a required
migration step, fails explicitly.

A successful migration may rewrite a manual/quick save when
`rewrite_migrated_saves` is enabled; autosave migration does not rewrite the
original autosave. Test migrations on copies of real released saves.

All operations expose explicit `NucleusSaveResult.error` codes;
`succeeded()` means `error == OK`. Save/load results can also provide `path`,
`document`, `migrated` and `recovered_from_backup`. The global service emits
`save_completed` / `save_failed` and `load_completed` / `load_failed`;
the session emits `snapshot_saved` / `snapshot_loaded` and capture-progress
signals. Handle missing files, unconfigured credentials, validation errors,
corrupt data and absent migrations in the consuming game's UI.

## Boundaries and further reading

- `res://` stores authored game assets; writable player data belongs in user
  storage. Do not hardcode the Windows path for cross-platform games.
- Nucleus does not automatically implement cross-device sync, backup uploads,
  platform cloud-save quotas or conflict resolution. These are integration
  policies owned by the game/platform.
- Do not infer a successful *load* from a file's existence; use the explicit
  result and validated document.

See [Save Quickstart](../guides/save_quickstart.md),
[Save Tutorial](../guides/tutorials/save_system.md),
[Resume Selection](save_resume.md) and
[Persistent World State](../modules/persistent_world_state.md).
