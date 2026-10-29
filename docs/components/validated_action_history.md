# Validated Runtime Action History (P03)

Target engine: Godot 4.7.2. Source:
`addons/nucleus/components/gameplay/state/validated_action_history.gd`.

`NucleusValidatedActionHistory` is a small `RefCounted` history for **data-only**
state snapshots when gameplay restoration may fail validation. It owns no Node,
scene, save slot, input mapping, or global Undo/Redo service. Prefer Godot's
native `UndoRedo` for reversible commands, and `EditorInterface.get_editor_undo_redo()`
for editor-authored actions.

> [!IMPORTANT]
> **Choose this only when snapshots need game-side validation before Undo/Redo
> can advance.** Otherwise prefer Godot native `UndoRedo`.

## Contract

- `record(before: Dictionary, after: Dictionary, label: StringName) -> Error`
  snapshots both values. Equal states return `ERR_ALREADY_EXISTS`; invalid data,
  empty labels or oversized payloads are rejected without altering the history.
- `peek_undo()` / `peek_redo()` return `{ticket, label, snapshot}` with an owned
  deep copy of the relevant state. Neither advances the cursor.
- Apply and validate that snapshot **through your own game's state owner**.
- Only after success, call `confirm_undo(ticket)` / `confirm_redo(ticket)`.
  A cancelled, superseded, stale, mismatched, or repeated ticket fails.
- `cancel_preview()` invalidates an outstanding ticket; `clear()` resets all
  history. Recording a new action after Undo drops the former Redo branch.
- `undo_count()` / `redo_count()` and `can_undo()` / `can_redo()` are read-only.

## Usage

```gdscript
var history := NucleusValidatedActionHistory.new()
history.max_actions = 20
history.record(before_snapshot, after_snapshot, &"inventory_sort")

func undo_action() -> bool:
    var request := history.peek_undo()
    if request.is_empty():
        return false
    var accepted := restore_and_validate(request["snapshot"])
    if not accepted:
        history.cancel_preview()
        return false
    return history.confirm_undo(int(request["ticket"])) == OK
```

`restore_and_validate` belongs to the consuming game; it must reject invalid
state **before mutating canonical gameplay**, or be capable of rolling back an
unsuccessful restoration. The history does **not** implement atomic mutation.
Do not call `confirm_*` before restoration succeeds.

## Limits and trust

- Defaults: 20 actions, **2 MiB per snapshot**, 10,000 recursively visited
  data values, depth at most 16. Configure limits before recording.
- Snapshots contain dictionaries, arrays, packed arrays, and ordinary Godot
  scalar/vector/value variants. Arbitrary `Object`, `Resource`, `Node`, and
  `Callable` references are rejected; use stable IDs and serializable values.
- A new preview invalidates any previous preview. Do not request a second
  preview while the first asynchronous restoration is still in flight.
- The history is transient and not persisted. A game owns schema validation,
  compatibility migration, replay side effects, and animation cancellation.
- Deep copying plus serialization-size checks cost CPU and memory. Record one
  logical player action, not every cursor or drag frame.

## Use cases

| Scenario | Use this? | Alternative or required game work |
| --- | --- | --- |
| In-game editor with reversible data snapshots | Yes, if state restoration may be rejected | Game validates/applies all state atomically |
| Puzzle move with connected groups and rotations | Yes, one logical drag/rotate action per snapshot | Game-owned group rules and tween cancellation |
| Godot editor plugin changing scene Nodes | No | Native `EditorInterface.get_editor_undo_redo()` |
| Simple reversible runtime property action | Usually not needed | Native `UndoRedo` with do/undo methods |

Store **data-only** history. For long-running asynchronous restore, retain one
pending ticket and do not preview another action until it resolves.
