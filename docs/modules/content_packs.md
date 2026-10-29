# Content Packs Contract

## Scope

```text
addons/nucleus/modules/content_packs
scripts/content_packs
```

Content Packs is the optional Nucleus boundary for extending an exported game
with official patches/DLC and for exposing a **separate, data-only** community
mod path.

It does not replace Godot resource packs. It decides **when and under which trust
policy** `ProjectSettings.load_resource_pack()` may be called.

## Security model

External content is a trust boundary.

Nucleus intentionally separates:

```text
trusted official resource pack
    PCK/ZIP created by the game's release pipeline
    may contain Godot resources and code
    must be verified before mount

untrusted community data mod
    directory or explicitly enabled store-only ZIP
    may contain only whitelisted inert data files
    is never mounted into res://
```

The second path is the default for community content.

Do not accept a community `.pck` merely because its filename or manifest looks
valid. A Godot resource pack can contain scripts, scenes, resources, native
extensions, and files that override existing `res://` paths. Once mounted, that
content has crossed the engine resource boundary.

## Trusted official packs

Runtime verification order:

```text
bounded detached manifest read
→ JSON/manifest validation
→ game-version compatibility
→ archive SHA-256
→ detached public-key signature
→ dependency / entitlement policy
→ ProjectSettings.load_resource_pack()
```

Only `NucleusContentPackLoader` owns the final engine mount call.

A signed manifest contains:

```text
schema_version
pack_id
display_name
version
kind
minimum_game_version
maximum_game_version
dependencies
entitlement_id
resource_prefix
archive_sha256
```

The detached signature signs the **exact manifest bytes**. The manifest in turn
contains the PCK SHA-256, binding metadata and archive together.

Only the public key belongs in the game. The private signing key is release
infrastructure and must never be committed, exported, stored in a `.tres`, or
printed to logs.

## Pack kinds

```text
PATCH
    trusted official replacement pack
    may replace existing res:// paths
    must mount during early bootstrap

DLC
    additive official content
    replace_files = false
    owns res://content/<pack_id>/

TRUSTED_MOD
    executable/trusted Godot resource pack
    disabled by policy by default
    owns res://content/<pack_id>/
```

`NucleusContentPackManager` is the normal runtime owner for DLC and trusted
packs. It deliberately rejects `PATCH`.

Patches need to mount before affected resources are preloaded. A consuming game
should call `NucleusContentPackVerifier.verify()` and
`NucleusContentPackLoader.mount_verified_patch()` from a small project-owned
autoload `_init()` when patching is actually required.

## Namespaces

Additive packs declare exactly:

```text
res://content/<pack_id>/
```

This avoids accidental collisions with the base project and gives every pack a
stable authored namespace.

Nucleus can validate the declared namespace before mount. It cannot inspect
arbitrary PCK contents with a public safe pre-mount API, which is one reason
official PCKs remain trusted artifacts rather than community input.

## Dependencies and load order

`NucleusContentPackManager.mount_batch()` verifies descriptors first, then mounts
dependency-ready packs in deterministic pack-id order.

Dependencies are pack IDs. A dependency must already be mounted or be part of
the same batch.

Circular/unresolved dependency graphs fail instead of guessing an order.

## Entitlements

Entitlement is separate from integrity.

```text
signature/hash
    proves that this is an approved artifact

entitlement
    proves that the current user may consume it
```

The manager accepts a game/provider-owned `Callable` through:

```gdscript
content_pack_manager.set_entitlement_checker(
    func(entitlement_id: StringName) -> bool:
        return my_store_provider.owns(entitlement_id)
)
```

Content Packs does not depend directly on Steam, Epic, consoles, Google Play, or
another optional provider.

## Process lifetime

Godot exposes resource-pack mounting but no equivalent public runtime unmount.

Therefore:

```text
enable / disable / reorder official resource packs
    persist desired configuration
    restart process
    mount desired set during next boot
```

Removing a record from a registry must never be presented as unloading resources.

## Community data mods

`NucleusDataModValidator` and `NucleusDataModPack` are intentionally not
ResourceLoader wrappers.

Default allowed extensions:

```text
json
csv
txt
```

Default blocked classes include scripts, scenes, `.tres/.res`, GDExtension,
native libraries, PCK/ZIP nesting, WebAssembly, executables, and common scripting
formats.

The validator also enforces:

```text
relative paths only
no path traversal
no hidden path segments
no symlinks for directory mods
maximum file count
maximum per-file size
maximum total size
manifest schema/version
```

ZIP community mods are disabled by default. If a game explicitly enables them,
Nucleus accepts only **store-only** entries (`compression level == 0`) so a
compressed zip bomb is not expanded by the data-mod reader.

No ZIP is extracted to disk.

## Data-mod API

A validated `NucleusDataModPack` exposes only:

```text
list_files()
has_file()
read_bytes()
read_text()
read_json()
```

It does not expose an API that mounts the package or calls:

```text
load()
preload()
ResourceLoader
GDExtensionManager
OS.execute()
```

The game must still validate the **meaning** of parsed data. Package safety does
not make arbitrary economy values, spawn rates, URLs, shader source, or other
domain data trustworthy.

## Trusted executable mods

`TRUSTED_MOD` exists for projects that deliberately support code-capable mods.

It is disabled by default:

```gdscript
policy.allow_trusted_mod_packs = false
```

Enabling it means the project has explicitly chosen to trust those signed packs.
It is not the community-mod default.

Store/platform rules may also prohibit downloaded executable content. Distribution
policy remains a product responsibility.

## Signing tool

Release pipeline:

```bash
godot --headless --path . \
  --script res://scripts/content_packs/sign_pack.gd -- \
  --pack /secure/frozen_north.pck \
  --manifest /secure/frozen_north.json \
  --key /secure/content.key \
  --signature /secure/frozen_north.sig
```

The tool:

1. hashes the PCK;
2. writes the hash into the manifest;
3. validates the final manifest;
4. serializes the exact manifest bytes;
5. signs the manifest SHA-256 with the private key;
6. writes a detached binary signature.

Keep the private key outside the project/repository.

## Extension rule

Add storefront download/install logic through a provider adapter.

Add game-specific schema parsing after `NucleusDataModPack`.

Do not weaken the untrusted-data boundary merely to make a mod format easier to
author. Introduce a new explicit trust mode instead.
