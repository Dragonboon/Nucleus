# Generic turn sessions (Turnity migration)

Nucleus ports the **mechanisms**, not the editor plugin or singleton, from the
user-owned Turnity repository (`sempitern0/Turnity`, legacy Godot 4.3).
The replacement is scene-owned and compatible with Godot 4.7.2.

## Files

- `components/gameplay/turns/turn_participant.gd` — a stable-id turn seat and
  optional actor reference; one session at a time; manual end, skip and blocks.
- `components/gameplay/turns/turn_session.gd` — deterministic scheduler, events,
  turn limits, round boundaries, clock, pause and cleanup.
- `components/gameplay/turns/turn_counter.gd` — independent discrete event
  counter for status rounds, action counts, objectives or cooldowns.

No references to damage, RPGs, multiplayer, user interface or Autoloads.
Turn sessions work for board games, chess-like games, card play and tactics.

## Modes and semantics

`NucleusTurnSession.start_session(participants)` accepts one or more
`NucleusTurnParticipant` nodes with distinct, nonempty `participant_id`.
Participants must already be in the scene and must not belong to a different
session. Zero duration means indefinite; the participant's `turn_seconds=-1`
inherits the session default.

| Mode | Ordering | Activity |
| --- | --- | --- |
| `SERIAL` | Authored roster order | Exactly one seat at a time |
| `INITIATIVE` | Highest `initiative` first; stable ties | One seat at a time |
| `SIMULTANEOUS` | Authored roster order | All eligible seats act during the same round |

The session emits start/end signals for rounds and turns; each participant
also emits turn-start/turn-end/turn-skipped signals. A participant's actor is
not required to implement an interface, and has no implicit commands.

`complete_turn(seat)` and `skip_turn(seat)` require an active seat. The
`maximum_turns` limit counts **completed or skipped participant
opportunities**, not rounds. Zero means unlimited; blocked opportunities
also count toward the limit. Skipped/blocked seats never execute a turn.
If no enabled/valid seats remain, the session ends.

`block_turns(n)` reserves n future opportunities on one participant;
one is consumed when that seat is scheduled. Blocks are not automatically
cleared at session end. `clear_blocks()` removes them. `enabled=false`
excludes a seat from scheduling without consuming its block.

Timed sessions use `advance(delta)` for deterministic tests or an optional
automatic `_process` clock. Timeouts finish the active turn. New turns
opened by a timeout do not retroactively consume the preceding delta.
`set_paused(true)` suspends timers, not explicit game ownership of turns.

## Integration and limits

An RPG may connect `turn_started` to its action selection and connect
`turn_ended` or `round_ended` to `NucleusTurnCounter.advance()`.
The status-effect container still uses real seconds: never reinterpret its
duration as rounds. Use separate counters and deliberate listeners for
turn-based status policies.

Sessions do not validate legal chess moves, assign initiative from attributes,
automatically choose AI actions, replicate turns, or arbitrate simultaneous
network commands. Those are separate game or optional module contracts.

`end_session(reason)` clears ownership and emits an explicit outcome.
As with other scene-owned components, save stable participant IDs and
game-specific decisions, not live Node references. This iteration does not
persist a mid-turn running session or support roster mutation during a run.

## Verification

Run `godot --headless --path . res://tests/headless/test_runner.tscn`
or open the test scene in Godot 4.7.2. The suite
`tests/headless/turn_session_test.gd` checks ordering, initiative, parallel
activation, finite timers, blocks, pauses and maximum-turn cleanup.
An actual Godot execution is needed before claiming the tests pass.
