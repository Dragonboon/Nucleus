# Tutorial: signed DLC and safe data mods

This tutorial builds two extensions for one fictional survival game:

```text
official DLC
    Frozen North biome delivered as a signed PCK

community mod
    Better Fishing delivered as JSON data
```

The important result is not only that both load. They cross **different trust
boundaries**.

## Part 1 — prepare the official signing key

Generate an RSA key outside the repository using your preferred release tooling.

Keep:

```text
private key
    release machine / secret store only

public key
    res://game/security/content_signing.pub
```

Nucleus runtime never needs the private key.

## Part 2 — author the DLC namespace

Create a separate DLC export project or content build that produces:

```text
res://content/frozen_north/
├── biomes/
├── creatures/
├── items/
└── entry.json
```

Avoid base-project paths such as:

```text
res://addons/nucleus/core/
res://addons/nucleus/components/
res://game/player.gd
```

for additive DLC.

## Part 3 — create the manifest

Create `frozen_north.json` next to the future PCK:

```json
{
  "schema_version": 1,
  "pack_id": "frozen_north",
  "display_name": "Frozen North",
  "version": "1.0.0",
  "kind": "dlc",
  "minimum_game_version": "0.8.0",
  "maximum_game_version": "",
  "dependencies": [],
  "entitlement_id": "dlc.frozen_north",
  "resource_prefix": "res://content/frozen_north/",
  "archive_sha256": ""
}
```

The signing step owns the final hash value.

## Part 4 — sign the exported PCK

Assume you exported:

```text
/build/frozen_north.pck
/build/frozen_north.json
```

Run:

```bash
godot --headless --path . \
  --script res://scripts/content_packs/sign_pack.gd -- \
  --pack /build/frozen_north.pck \
  --manifest /build/frozen_north.json \
  --key /secrets/content.key \
  --signature /build/frozen_north.sig
```

Now changing either the JSON bytes or the PCK bytes should invalidate runtime
verification.

## Part 5 — configure the runtime manager

Instance:

```text
res://addons/nucleus/modules/content_packs/content_pack_manager.tscn
```

Set a `NucleusContentPackPolicy`:

```text
public_key_path = res://game/security/content_signing.pub
allow_trusted_mod_packs = false
```

Then:

```gdscript
func install_frozen_north() -> void:
    var error := $ContentPackManager.mount_official(
        "user://content/frozen_north.pck",
        "user://content/frozen_north.json",
        "user://content/frozen_north.sig",
    )

    if error != OK:
        push_error(error_string(error))
        return

    var entry := load(
        "res://content/frozen_north/entry.tres"
    )
```

`load()` is acceptable **after a trusted pack was verified and mounted**.

Do not copy this `load()` pattern into the community data-mod path.

## Part 6 — wire entitlement ownership

The manager does not know your storefront.

Give it a checker:

```gdscript
func _ready() -> void:
    $ContentPackManager.set_entitlement_checker(
        _owns_entitlement
    )


func _owns_entitlement(id: StringName) -> bool:
    return my_platform_service.owns_entitlement(id)
```

For a DRM-free build you could intentionally use a local license/install policy
instead.

## Part 7 — build the community mod

Create:

```text
user://mods/better_fishing/
├── manifest.json
└── data/
    └── fish.json
```

`manifest.json`:

```json
{
  "schema_version": 1,
  "mod_id": "better_fishing",
  "display_name": "Better Fishing",
  "version": "1.0.0"
}
```

`data/fish.json`:

```json
{
  "species": [
    {
      "id": "silverfin",
      "weight": 2.0,
      "spawn_weight": 10
    }
  ]
}
```

## Part 8 — validate before reading

```gdscript
var result := NucleusDataModValidator.validate_directory(
    "user://mods/better_fishing"
)

if result.error != OK:
    push_warning(result.message)
    return

var mod: NucleusDataModPack = result.pack
var raw: Variant = mod.read_json("data/fish.json")
```

Now add **game-owned schema checks**:

```gdscript
func validate_fish_data(raw: Variant) -> bool:
    if typeof(raw) != TYPE_DICTIONARY:
        return false

    var species: Variant = raw.get("species")
    if typeof(species) != TYPE_ARRAY:
        return false

    for fish: Variant in species:
        if typeof(fish) != TYPE_DICTIONARY:
            return false

        var weight := float(fish.get("weight", -1.0))
        if weight <= 0.0 or weight > 1000.0:
            return false

    return true
```

Nucleus protects the package/code boundary. The game protects its domain model.

## Part 9 — prove malicious files are rejected

Add any of these:

```text
evil.gd
enemy.tscn
native.gdextension
library.dll
nested.pck
../escape.json
```

Validation must fail.

Also try a symbolic link inside a directory mod on a desktop OS. Directory
validation must reject it.

## Part 10 — decide whether ZIP is worth enabling

Default:

```gdscript
NucleusDataModPolicy.new().allow_store_only_zip == false
```

That is intentional.

If you need a ZIP runtime format:

```gdscript
var policy := NucleusDataModPolicy.new()
policy.allow_store_only_zip = true
```

Only uncompressed/store entries are accepted. This avoids allowing a compressed
archive to expand into an unbounded memory payload before per-file checks.

## Result

You now have:

```text
official executable content
    signed and verified before mount

community content
    inert data, never mounted, schema-validated by the game
```

That distinction is the core Content Packs contract.
