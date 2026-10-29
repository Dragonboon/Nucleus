# Optional Network Clock Synchronization Contract

## Purpose and boundaries

`NucleusNetworkClockSync` estimates the mapping between a remote server's
**monotonic** microsecond clock and the local client's monotonic clock. It is a
small, transport-independent, scene/session-owned helper, not a new Autoload.
It never performs RPCs, authenticates clients, takes authority over gameplay,
or sets `NucleusWorldClock`. Both sides must sample `Time.get_ticks_usec()`;
do **not** mix these timestamps with Unix epoch timestamps.

The game or its existing `NucleusNetworkHandler` owns the connection and RPC
transport. The game must allow responses **only from its authenticated and
authorized server**, using Godot's `@rpc("authority", ...)` (or an equivalent
provider-specific trusted channel). The estimates are unsuitable as a security
authority for cooldowns, loot, trades, inventory, or combat.

## Install and initialize

Add the two GDScript classes:

```text
addons/nucleus/modules/networking/clock/network_clock_sync_profile.gd
addons/nucleus/modules/networking/clock/network_clock_sync.gd
```

They do not need a `.tscn`, Autoload, C# runtime, or SpacetimeDB. Instantiate one
client-side estimator per authenticated connection/session:

```gdscript
var clock := NucleusNetworkClockSync.new()

func on_network_session_started() -> void:
    clock.begin_session()  # Drops in-flight tickets and old offset/RTT samples.
```

For a game using Generation 1's `NucleusNetworkReconnectController`, call
`clock.begin_session()` from `recovery_started` or before starting the next
connection. Do not consider server time valid until a new sample is accepted.

## Exchange timestamps through existing RPCs

A request is a **ticket**, not a timestamp sent by the client. The local send
time stays in a bounded pending table. The server samples `Time.get_ticks_usec()`
on receipt (`t1`) and immediately before responding (`t2`). The client samples
`Time.get_ticks_usec()` on receiving the reply (`t3`). `t0` was captured when
the request ticket was created.

A minimal *game-owned* bridge may look like this on a Node present at the same
NodePath on client and server:

```gdscript
# Scene-owned example; wire _send_clock_probe() to a timer in your game.
var clock := NucleusNetworkClockSync.new()

func _send_clock_probe() -> void:
    if multiplayer.is_server():
        return
    var ticket: Dictionary = clock.create_request()
    if ticket.is_empty():
        return
    _clock_probe.rpc_id(1, int(ticket["session_id"]), int(ticket["request_id"]))

@rpc("any_peer", "call_remote", "unreliable")
func _clock_probe(session_id: int, request_id: int) -> void:
    if not multiplayer.is_server():
        return
    var sender_id: int = multiplayer.get_remote_sender_id()
    if sender_id <= 1 or session_id <= 0 or request_id <= 0:
        return
    # Production: check sender admission/rate using game-owned session policy.
    var t1: int = Time.get_ticks_usec()
    var t2: int = Time.get_ticks_usec()
    _clock_probe_reply.rpc_id(sender_id, session_id, request_id, t1, t2)

@rpc("authority", "call_remote", "unreliable")
func _clock_probe_reply(
    session_id: int,
    request_id: int,
    server_received_usec: int,
    server_sent_usec: int,
) -> void:
    if multiplayer.is_server():
        return
    clock.accept_response(
        session_id, request_id, server_received_usec,
        server_sent_usec, Time.get_ticks_usec()
    )
```

Ensure `clock.begin_session()` executes when the trusted transport/session
starts and on each reconnection. In a real game, rate-limit probes server-side,
validate the RPC sender against the admitted peer list, and keep RPCs at
matching Godot NodePaths. Treat the example as an integration sketch, not a
complete authenticated network service.

Recommended sampling interval is approximately **1–5 seconds** while online,
adjusted for the game's requirements. The library does not schedule requests;
it intentionally avoids another competing connection or Timer owner.

## Formulas and quality filters

With `t0`/`t3` in client monotonic microseconds and `t1`/`t2` in server
monotonic microseconds:

```text
server-minus-client offset = ((t1 - t0) + (t2 - t3)) / 2
network RTT                = (t3 - t0) - (t2 - t1)
estimated server ticks     = client_now_ticks + estimated offset
```

These are the standard four-timestamp round-trip relations. They approximate
offset under the usual assumption that forward/reverse path latencies are
similar. Large path asymmetry and scheduling delays may bias the estimate.

`NucleusNetworkClockSyncProfile` controls:

| Option | Default | Meaning |
| --- | --- | --- |
| `max_pending_requests` | 16 | Bounds requests awaiting replies |
| `request_timeout_seconds` | 8 | Reject late replies / retire tickets |
| `max_rtt_ms` | 3000 | Reject unusably slow samples |
| `max_server_processing_ms` | 1000 | Bound server-side processing time |
| `outlier_tolerance_ms` | 75 | Reject RTT above the best recent accepted RTT plus this margin |
| `rtt_window_size` | 8 | Recent accepted RTT history |
| `smoothing_factor` | 0.25 | EWMA weight for subsequent offset observations |
| `stale_after_seconds` | 15 | Expire estimates without fresh accepted samples |

The first sample initializes the offset immediately. Subsequent accepted
observations smoothly adjust it. RTT outliers and malformed timestamps are
rejected. Once the estimate is stale, new samples establish a fresh baseline
rather than blending with an obsolete offset or historical minimum RTT.

On reconnect, `begin_session()` invalidates all request IDs, old samples,
previous time mapping, and pending requests. Every reply echoes the session ID
and request ID: a previous connection cannot complete a request on the new one.
Duplicate and malformed replies consume no valid additional sample.

## Reading the estimate

```gdscript
if clock.is_synchronized():
    var server_ticks_usec: int = clock.get_server_ticks_usec()
    var estimated_server_seconds: float = clock.get_server_ticks_seconds()
    var latency_seconds: float = clock.get_round_trip_seconds()
```

`get_server_ticks_usec()` returns `-1` while unsynchronized or stale.
`get_server_ticks_seconds()` returns `-1.0` in those cases. The estimated time
is in the **server process's boot-time domain**, not a wall-clock timestamp or
save-file timestamp. `get_offset_seconds()` returns the most recent offset
estimate and should only be consumed after `is_synchronized()` succeeds.
The estimate may adjust when better measurements arrive; never use it as a
strictly monotonic transaction sequence.

## Signals and errors

The helper emits:

```text
session_reset(session_id)
sample_accepted(offset_seconds, round_trip_seconds)
sample_rejected(reason: StringName)
```

`create_request()` returns `{}` when not initialized, invalid or full.
`accept_response()` returns `false` for mismatched/replayed tickets,
invalid timestamps, expired tickets and outliers. This is normal on lossy
transport; it is not a signal to disconnect the user. Loss does not prevent
future valid samples, provided the connection remains authenticated.

## Testing and compatibility

`tests/headless/network_clock_sync_test.gd` exercises exact microsecond
calculations, smoothing, duplicate replies, generation invalidation, pending
limits, timeouts, malformed timestamps, outliers and stale-estimate recovery.
It is registered in `tests/headless/test_manifest.gd` alongside Generation 1's
`network_recovery_test.gd`.

This generation changes no `NucleusNetworkHandler` or `NucleusWorldClock` API.
It is compatible with the optional network module architecture and requires
no C# or SpacetimeDB dependency. It does **not** assert that any specific
network provider has passed real-world jitter, packet-loss or reconnect tests.
