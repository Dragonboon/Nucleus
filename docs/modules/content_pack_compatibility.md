# Content Pack Compatibility — pre-session comparison

## Why this exists

The trusted Content Packs owner already validates signatures, integrity,
version bounds, dependencies, and mounts. It does **not** provide a read-only
comparison of a host's required content against another installation.
`NucleusContentPackCompatibility` fills that gap without changing the trust
boundary, the pack manager, or network transport.

## Contract

```gdscript
var server_required: Array[NucleusContentPackManifest] = [...]
var local_installed: Array[NucleusContentPackManifest] = [...]
var result := NucleusContentPackCompatibility.compare(
    server_required,
    local_installed,
)
if result.error != OK:
    # Malformed, duplicate or oversized inventories; reject the comparison.
    return
if not result.compatible:
    # Show result.missing / result.mismatched / result.extra.
    return
# Only now proceed to the game's other admission checks.
```

The example uses placeholders for project-owned inventories. Nucleus does
**not** discover remote resources, download assets, join multiplayer sessions,
or install packs through this API.

Input: two typed `Array[NucleusContentPackManifest]` lists. The required side
normally represents what the **authoritative session** demands, and available
represents what the **local participant** has installed and independently
verified. Reorderings do not matter. Pack IDs are unique; both lists are
bounded to 256 entries. Null manifests and manifests failing `validate(true)`
are rejected.

Result fields:

| Key | Meaning |
| --- | --- |
| `error` | `OK` or `ERR_INVALID_DATA`; invalid inventories fail closed |
| `compatible` | Whether all required manifests match, respecting extra-pack policy |
| `missing` | Sorted IDs required but unavailable |
| `mismatched` | Sorted dictionaries with `pack_id` and changed `fields` |
| `extra` | Sorted IDs locally available but not required |
| `message` | Reason for invalid inventory; empty for valid comparisons |

Mismatches inspect SemVer string, archive SHA-256, pack kind, namespace,
dependencies, game-version bounds, and entitlement identifier. Display names
are not gameplay identity. **A manifest comparison is not a proof that the
on-disk archive matches its digest**; this remains the responsibility of
`NucleusContentPackVerifier` on each machine.

## Strict by default

Unknown local packs may affect game behavior. By default they make a session
incompatible. `allow_extra_local=true` is an explicit opt-out for games that
prove extras cannot influence that session. Extra IDs are still returned for
reporting when the opt-out is enabled.

## Security / authority

1. Treat inventories arriving over the network as untrusted input. Apply a
   transport-size limit and typed parsing before constructing manifests.
2. Never interpret an advertised hash as verification of the local archive.
   Run the existing signature and archive verification first.
3. The server must still validate membership, entitlements, content policy,
   game version and gameplay authority. Clients must not mount anything based
   on a remote compatibility result.
4. Different signatures for equivalent metadata are not checked here. This
   utility compares descriptors, **not** signing keys or signature chains.
5. Community data mods are a separate trust model; no Godot resource pack is
   mounted just because an ID appears in the comparison.

This is intentionally a pure stateless API in optional `addons/nucleus/modules/content_packs`.
It has no network calls, file writes, OS execution, Autoload, or SceneTree access.
