# Protecting a Released Godot Game

> [!IMPORTANT]
> Nucleus does **not** ship DRM, guarantee theft prevention, or activate protection when you start a project. It offers a **release checklist and optional preflight**. The consuming game owns its distribution, signing identity, encryption keys, platform integration, and legal strategy.

A stolen game may be copied, renamed, resold, or repackaged with malware. The practical goal is to **increase the effort to repackage it, prove which release is authentic, and prepare a fast response**. A legitimate player should still be able to enjoy the game with reasonable offline support.

## Choose your route

| I need to... | Start here | What this achieves |
| --- | --- | --- |
| Publish a first PC game | [Basic release](#basic-release-path) | Recognizable authentic builds and preserved evidence |
| Make exported content harder to extract | [Encrypted PCK](#optional-encrypted-pck) | Raises the effort needed to copy resources; not unbreakable DRM |
| Ship on Steam | [Store checks](#store-and-online-features) | Store identity; optional validated online entitlements |
| Distribute DLC | [Signed content packs](#existing-nucleus-systems) | Verify an official extra pack before mounting it |
| Handle a stolen reupload | [Reupload response playbook](reupload_response_playbook.md) | Collect evidence and submit a platform complaint |

## Basic release path

1. **Publish an official identity.** Reserve your game's store name/page and publish a short development page linking the official developer or publisher. Record a public release date.
2. **Track authorship and rights.** Keep dated source control, build records, author and third-party asset licenses, and explicit permission for each licensed asset. The MIT license of the Nucleus *addon* does not confer ownership over a game's art or brand.
3. **Export release builds, not editable project folders.** Use Godot's normal export system. Do not distribute private keys, editor caches, repository internals, or license credentials.
4. **Sign executables where appropriate.** On Windows, use Godot's native export code signing and a certificate that identifies the legitimate publisher; verify the **final** `.exe`. On macOS, plan Developer ID signing and notarization.
5. **Keep hashes and provenance privately.** Record the source commit, game version, platform, build timestamp, SHA-256 of final distributed files, and official store URLs. A hash alone is not proof of authorship; preserve an independently verifiable release trail.
6. **Test on a clean device.** Verify installation, launch, updates, gamepad controls if applicable, offline play, anti-virus warnings, and multiplayer as designed.
7. **Set up a takedown folder.** Use the [reupload response playbook](reupload_response_playbook.md) before you need it.

### Optional local preflight

A game created from Nucleus can run:

```bash
python3 scripts/ci/audit_game_exports.py \
  --project . --preset "My Windows Release" --profile standard
```

For an intentionally hardened desktop release:

```bash
python3 scripts/ci/audit_game_exports.py \
  --project . --profile hardened --strict
```

Use `--json` for a machine-readable report. `--strict` fails on warnings as well as errors. The tool **reads only `export_presets.cfg`**, never opens `.godot/export_credentials.cfg`, never signs a binary, and never exports a game. A clean report is **not evidence** that the resulting executable is signed or its PCK unreadable.

> [!TIP]
> Nucleus's own CI smoke presets are intentionally unsigned and unencrypted. Do **not** add this strict game-release gate to Nucleus's source-template CI: its purpose and distribution model differ from those of a shipping game.

## Optional encrypted PCK

Godot has native AES-256 PCK export encryption, but it has a non-obvious prerequisite: **the game's release export templates must be compiled with the same 256-bit key**. Prebuilt official templates do not provide the corresponding decryption key and cannot be used for a functioning encrypted build.

### Setup

1. Decide which resources actually need encryption. Prefer gameplay scripts/scenes and commercially sensitive assets; assess loading and patching costs.
2. Generate a random per-game key **outside your repository**. Example: `openssl rand -hex 32`. Keep it in a secret manager, not in a `.gd`, `.tres`, script, ZIP, or Git commit.
3. Build custom release export templates for **each supported target** using `SCRIPT_AES256_ENCRYPTION_KEY`, following the matching Godot engine documentation. Pin the engine and templates as a reproducible toolchain.
4. In **Project > Export > your preset**, select the compatible **Custom Template / Release** build.
5. In **Encryption**, enable **Encrypt exported PCK**, configure the **include filters**, and enable index/directory encryption if appropriate. **Empty include filters select no protected resources**.
6. For command-line export, provide the same key securely with `GODOT_SCRIPT_ENCRYPTION_KEY`, which is distinct from the variable used while building templates.
7. Export from a clean build environment and test that the result launches and reads encrypted resources. Inspect the exported artifact rather than trusting a checkbox or this repository's tests.
8. Rotate and rebuild the templates when a secret is exposed; expect to rebuild/reissue encrypted packages as part of that response.

> [!CAUTION]
> The decryption key is necessarily recoverable in principle from an executable that can decrypt resources. Encryption **raises reverse-engineering cost**; it cannot prevent a motivated adversary from copying, instrumenting, or rebuilding the game. Nucleus must never supply a common static key shared by every game.

**Desktop only is not a universal rule:** supported encryption paths and asset packaging differ among Android, iOS, Web, and desktop targets. Validate every target individually; never copy desktop export settings blindly to the web.

## Native signing: important distinction

**Executable code signing** proves the publisher certificate used to sign and detects modification relative to that signature. It does not hide scripts or assets and does not stop a third party from producing a differently signed counterfeit.

On Windows, set up a signing tool in **Editor Settings > Export > Windows**, then enable code signing in the Windows export preset. Keep certificate materials in secure build infrastructure and verify the **signed output** (e.g., Windows `Get-AuthenticodeSignature` or `signtool verify`). Avoid assuming embedded PCK and signing are compatible for the exact engine/export configuration without an end-to-end test.

On macOS, follow the platform's Developer ID signing and notarization flow; an ad-hoc signature is not equivalent to a trusted publisher identity.

## Store and online features

Use `addons/nucleus/modules/platform_services` as an optional lifecycle/capability boundary, then let the **game's adapter** integrate Steam or another store SDK. Do not add a Steam-only dependency to Core or gate the entire game behind `NucleusPlatformUser.user_id`.

For online **privileged** operations (dedicated servers, purchases, competitive leaderboards, DLC entitlement), authenticate a platform-issued ticket on a **trusted server**, enforce its intended audience/app, and authorize the specific action. The client-supplied account ID is **not proof** of ownership. Decide offline policy explicitly; support local/solo play where possible.

Steam's own documentation explains that its basic DRM wrapper prevents only casual copying and is not a complete anti-piracy solution. Always-online authentication is therefore a *product and infrastructure choice*, not a default Nucleus defense.

## Existing Nucleus systems

| Existing feature | Reuse | Do not confuse with |
| --- | --- | --- |
| `addons/nucleus/core/save/security/` | Encrypted/authenticated save data | Exported game-content protection |
| `addons/nucleus/modules/content_packs/` | Public-key-verified official DLC/patch manifests | Encryption of the game's main PCK |
| `addons/nucleus/modules/platform_services/` | Optional provider identity, capability discovery | Proof of store ownership without validated tickets |
| `scripts/package_release.py` | Provenance/checksum manifest for **Nucleus addon source ZIP** | Signing/verifying a commercial game's binary release |

## Before launch

- [ ] Every shipped asset has an owner or a valid license and corresponding record.
- [ ] Official developer/publisher identity and store links are published.
- [ ] Final executables are signed/verified on the platforms that support publisher identity.
- [ ] If using PCK encryption: custom templates, key, filters, launch, patch/update flow tested.
- [ ] No private keys, API credentials, or game-source folders are included in the export.
- [ ] Release hash manifest, source commit, and evidence folder retained outside the public build.
- [ ] Optional server entitlements are verified by a trusted backend, not by a client claim.
- [ ] Offline accessibility and platform compatibility are tested.
- [ ] A reupload incident owner and complaint procedure are assigned.

## Two use cases

**Solo survival game released on Steam:** sign its Windows executable, publish a public developer identity, preserve the original build hashes; optionally encrypt assets with custom templates. Do not require permanent connectivity solely to deter file copying.

**Multiplayer game with official DLC:** use an optional platform provider, authenticate ownership on the dedicated server, and mount signed official DLC using existing Nucleus Content Packs. Keep the game-specific entitlement and offline policies outside the Nucleus core.

## Further reading

- [Technical boundary and integration roadmap](../architecture/game_distribution_security.md)
- [Reupload response playbook](reupload_response_playbook.md)
- [Godot 4.7: PCK encryption and custom templates](https://docs.godotengine.org/en/4.7/engine_details/development/compiling/compiling_with_script_encryption_key.html)
- [Godot 4.7: Windows signing](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_windows.html)
- [Godot 4.7: export credentials and presets](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html)
- [Godot 4.7: macOS signing/notarization](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_macos.html)
- [Steam: DRM wrapper limitations](https://partner.steamgames.com/doc/features/drm)
- [Steam: authentication and ownership](https://partner.steamgames.com/doc/features/auth)

**Source inspiration:** Yasen, *The Clone Wars: Defending Godot Games From Reupload Scams*, GodotCon slide deck supplied by the project owner (technology pp. 6-10; authorship and watermarking pp. 11-15; store/community presence pp. 16-21). The exact implementation and Nucleus ownership decisions above are additional engineering analysis, not claims made by the talk.
