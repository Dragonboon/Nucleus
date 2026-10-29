# Content Packs Quickstart

Use this guide when a game needs downloadable DLC, official patch PCKs, or a safe
community mod folder.

For the full trust contract, read:

```text
docs/modules/content_packs.md
```

## Choose the correct path first

```text
Official DLC / patch from your release pipeline?
    → trusted signed resource pack

Community-created content?
    → data-only mod

Need community scripts/code?
    → not the default path; explicit trusted-mod policy required
```

Do not auto-discover and mount arbitrary `.pck` files from a mods directory.

## Official DLC: minimum setup

Add a `NucleusContentPackManager` to the scene/service that owns downloaded
content:

```text
GameSession
└── ContentPackManager
```

Use:

```text
res://addons/nucleus/modules/content_packs/content_pack_manager.tscn
```

Create a policy resource in the Inspector and set:

```text
public_key_path
    res://game/security/content_signing.pub

game_version
    blank to use application/config/version

allow_trusted_mod_packs
    false
```

The public key is safe to ship. The private key is not.

## Create a DLC manifest

Example `frozen_north.json`:

```json
{
  "schema_version": 1,
  "pack_id": "frozen_north",
  "display_name": "Frozen North",
  "version": "1.0.0",
  "kind": "dlc",
  "minimum_game_version": "0.4.0",
  "maximum_game_version": "",
  "dependencies": [],
  "entitlement_id": "dlc.frozen_north",
  "resource_prefix": "res://content/frozen_north/",
  "archive_sha256": ""
}
```

`archive_sha256` is filled by the signing tool.

Author DLC resources under:

```text
res://content/frozen_north/
```

## Sign the pack

Outside source control, keep an RSA private key and run:

```bash
godot --headless --path . \
  --script res://scripts/content_packs/sign_pack.gd -- \
  --pack /secure/frozen_north.pck \
  --manifest /secure/frozen_north.json \
  --key /secure/content.key \
  --signature /secure/frozen_north.sig
```

Ship:

```text
frozen_north.pck
frozen_north.json
frozen_north.sig
```

Do not ship `content.key`.

## Mount the DLC

```gdscript
var error := content_pack_manager.mount_official(
    dlc_pck_path,
    dlc_manifest_path,
    dlc_signature_path,
)

if error != OK:
    push_error("DLC mount failed: %s" % error_string(error))
```

The manager verifies before the PCK reaches Godot's resource filesystem.

## Add store ownership

If the manifest declares `entitlement_id`, provide a checker:

```gdscript
content_pack_manager.set_entitlement_checker(
    func(entitlement_id: StringName) -> bool:
        return platform_provider.owns_entitlement(entitlement_id)
)
```

The actual provider API is game-owned. Nucleus keeps integrity and storefront
ownership separate.

## Official patches

Do **not** use the runtime manager for patches.

A patch that replaces base `res://` files needs an early game-owned autoload:

```gdscript
extends Node


func _init() -> void:
    var verification := NucleusContentPackVerifier.verify(
        patch_path,
        manifest_path,
        signature_path,
        PUBLIC_KEY,
        GAME_VERSION,
    )

    if verification.error == OK:
        NucleusContentPackLoader.mount_verified_patch(verification)
```

The early `_init()` matters because later scenes may already have preloaded the
resource you intended to replace.

## Community data mod

Recommended folder:

```text
user://mods/better_fishing/
├── manifest.json
└── data/
    └── fish.json
```

Manifest:

```json
{
  "schema_version": 1,
  "mod_id": "better_fishing",
  "display_name": "Better Fishing",
  "version": "1.0.0"
}
```

Validate it:

```gdscript
var result := NucleusDataModValidator.validate_directory(
    "user://mods/better_fishing"
)

if result.error != OK:
    push_warning(result.message)
    return

var mod: NucleusDataModPack = result.pack
var fish_data: Variant = mod.read_json("data/fish.json")
```

At this point `fish_data` is still untrusted game data. Validate its schema and
ranges before creating gameplay state from it.

## ZIP mods

ZIP support is deliberately opt-in:

```gdscript
var policy := NucleusDataModPolicy.new()
policy.allow_store_only_zip = true

var result := NucleusDataModValidator.validate_zip(
    "user://mods/better_fishing.zip",
    policy,
)
```

Entries must be stored without compression.

If authors need ordinary compressed ZIP distribution, unpack it in a separate
installer/tooling step into the directory format instead of weakening the
runtime trust boundary.

## Next

Build both paths step by step in:

```text
docs/guides/tutorials/content_packs.md
```
