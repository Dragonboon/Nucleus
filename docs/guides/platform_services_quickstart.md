# Platform Services Quickstart

## 1. Start standalone

Add:

```text
addons/nucleus/modules/platform_services/platform_service.tscn
```

under a persistent game/session owner.

With no provider assigned and:

```text
use_standalone_fallback = true
```

the service creates `NucleusNullPlatformProvider`.

You can then query:

```gdscript
platform_service.get_provider_id()
platform_service.get_local_user()
platform_service.has_capability(
	NucleusPlatformCapabilities.IDENTITY
)
```

The game remains runnable without a storefront SDK.

## 2. Keep gameplay provider-neutral

Prefer checks such as:

```gdscript
if platform_service.has_capability(
	NucleusPlatformCapabilities.ACHIEVEMENTS
):
	_show_achievement_ui()
```

rather than scattering:

```text
if Steam ...
if Epic ...
if console ...
```

through gameplay/UI code.

Capability checks should gate presentation/availability, not replace provider
error handling.

## 3. Add a real provider

A consuming game can create:

```gdscript
class_name GameSteamPlatformProvider
extends NucleusPlatformProvider
```

or an equivalent adapter for another SDK.

Override:

```text
is_available()
get_provider_id()
get_local_user()
get_capabilities()
_initialize_provider()
_shutdown_provider()
```

Keep actual SDK-specific API calls inside that adapter or another explicit
provider-specific service.

## 4. Replace the standalone provider

Assign the adapter in the editor before `_ready()`, or replace it explicitly:

```gdscript
platform_service.replace_provider(
	steam_provider
)
```

The service shuts down the previous initialized provider, connects lifecycle
signals, and initializes the replacement when requested.

## 5. Do not fake unavailable features

If the standalone provider has no achievements capability:

```gdscript
platform_service.has_capability(
	NucleusPlatformCapabilities.ACHIEVEMENTS
)
```

returns false.

Do not silently pretend an external unlock succeeded.

A game may implement its own local achievement model separately if desired.

## 6. Saves

Continue using:

```text
NucleusSave
NucleusSaveSession
Persistent World State
```

for local save contents.

If the real platform supports cloud storage, let the provider/game upload and
download the finished save files according to that SDK's rules.

Do not put save serialization inside the platform adapter.

## 7. Online identity

`NucleusPlatformUser.user_id` is display/session metadata until a trusted
backend/provider authentication flow proves otherwise.

Never authorize network gameplay solely because a client sends a platform user
ID.

## 8. Platform networking

A platform plugin may also expose its own multiplayer/P2P transport.

That is separate from PlatformService capability/lifecycle.

Configure the plugin-provided `MultiplayerPeer` through the game's networking
bootstrap.

Once Godot MultiplayerAPI has a peer, native MultiplayerSpawner,
MultiplayerSynchronizer, RPCs, and Nucleus gameplay replication can operate
above it.

## 9. When to extend Nucleus

Do not add an abstraction merely because one Steam API exists.

Promote a platform feature into Nucleus only after the real game demonstrates a
stable common contract across providers or repeated projects.

Until then:

```text
NucleusPlatformService
    lifecycle + identity + capability discovery

project adapter
    actual SDK semantics
```

is the preferred boundary.
