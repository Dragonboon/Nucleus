# Optional Platform Services

## Goal

`addons/nucleus/modules/platform_services` defines the smallest useful provider boundary for a
game that may run:

```text
standalone
Steam
Epic
console
another storefront/platform SDK
```

Nucleus does not wrap those SDKs feature by feature.

Production-tested integrations such as GodotSteam should remain the source of
truth for their platform APIs.

## Architecture

```text
NucleusPlatformService
        ↓
NucleusPlatformProvider
        ↓
game/plugin adapter
        ↓
external platform SDK
```

Fallback:

```text
NucleusNullPlatformProvider
```

## Service responsibility

The generic service standardizes only:

```text
provider lifecycle
provider ID
local user identity
locale
capability discovery
provider change notifications
```

It deliberately does not standardize the method signatures for:

```text
achievements
stats
cloud saves
friends
lobbies
commerce
overlay
authentication
platform networking
```

Those APIs differ enough between providers that prematurely hiding them behind
one universal interface usually loses important semantics.

## Capabilities

`NucleusPlatformCapabilities` defines provider-neutral identifiers:

```text
identity
achievements
stats
cloud_storage
rich_presence
friends
lobbies
auth
commerce
overlay
network_peer
```

`has_capability()` answers only:

```text
does this provider advertise support?
```

It does not imply that Nucleus implements that capability.

The game or adapter still owns the actual provider call.

## Identity

`NucleusPlatformUser` contains only:

```text
provider_id
user_id
display_name
locale
```

Do not assume one provider's account identifier format applies to another.

Do not expose sensitive auth tokens through this object.

## Standalone provider

`NucleusNullPlatformProvider` provides a deterministic fallback:

```text
provider_id = standalone
user_id = local
identity capability
```

This lets a game run outside Steam/Epic/etc. without filling gameplay code with
platform checks.

## Lifetime

Platform SDK lifetime is normally application/session-wide.

Recommended ownership:

```text
GameSession
└── PlatformService
```

or an intentional optional Autoload.

Nucleus does not add the service to the default project.

## GodotSteam integration model

Nucleus has **no compile-time dependency** on GodotSteam.

A Steam-enabled game should add the production integration/plugin it has chosen
and implement a thin project adapter:

```text
GameSteamPlatformProvider
    extends NucleusPlatformProvider
```

The adapter can:

```text
detect Steam availability
initialize/shutdown the Steam integration
return Steam user identity
advertise supported capabilities
emit identity/capability changes
```

Steam-specific operations may remain explicit in the game/provider layer.

Do not add generic Nucleus methods merely to mirror the entire Steam API.

## Platform networking

Some platform integrations can expose a `MultiplayerPeer` or their own P2P
transport.

That belongs to the networking/provider adapter boundary, not to
`NucleusPlatformService`.

If a provider-specific networking plugin is used, configure Godot's
`MultiplayerAPI` with the peer according to that plugin's production guidance.

Gameplay replication above the peer remains compatible with the Nucleus online
replication contracts.

## Achievements and stats

The capability names exist so game code can decide whether to expose a feature.

Nucleus intentionally does not currently define:

```text
unlock_achievement()
set_stat()
store_stats()
```

Different providers have different initialization, synchronization, failure,
offline, and publication semantics.

The first real game should determine whether a common subset is genuinely worth
standardizing.

## Cloud saves

Nucleus Save owns local save serialization.

A future platform adapter may upload/download the completed save artifact, but
the platform service does not replace:

```text
NucleusSave
save migrations
world persistence
save-slot policy
```

Conflict resolution and cloud ownership are game/platform concerns.

## Authentication

A platform user ID is not automatically a trusted multiplayer login.

For public online games, platform authentication tickets/tokens must be
validated according to the provider/backend architecture.

Never treat a client-supplied provider user ID as proof of identity.

## Testing

Standalone builds can use `NucleusNullPlatformProvider`.

Provider-specific integration tests should live in the consuming game/plugin,
where the real SDK is present.

This keeps baseline CI free from Steam/Epic/console binary dependencies.

## Not included

```text
GodotSteam dependency
Steam API wrapper
EOS dependency
console SDK code
achievement implementation
cloud synchronization
store overlay calls
matchmaking/lobby abstraction
commerce
auth ticket verification
platform-specific networking
```

That boundary is intentional.
