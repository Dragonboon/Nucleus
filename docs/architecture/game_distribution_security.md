# Game Distribution Security: Ownership and Integration Plan

## Purpose and current status

**Status: proposed, opt-in; not an implemented end-to-end DRM system.**

Reference inspection: `sempitern0/Nucleus`, `main` at commit `0f0295895bd3d452ccd1c39c2ab00fb7087d4da4`, version `0.32.0-dev.1`, `project.godot` targeting Godot `4.7`, CI pin `4.7.2-stable` (2026-10-10). This snapshot contains:

- Six Core Autoloads with intentionally bounded responsibilities.
- `NucleusSaveSecurity` / `NucleusSaveIntegrity` for save encryption and integrity.
- A public-key verification boundary for official `addons/nucleus/modules/content_packs` content.
- An optional `addons/nucleus/modules/platform_services` adapter contract; no built-in Steam SDK or ownership verifier.
- Reproducible addon package hashes and Linux/Windows/Web *smoke* exports; no game-release signing/encryption pipeline.
- No checked-in production game's `export_presets.cfg`; CI generates smoke presets in an isolated temporary copy.

**Do not modify `NucleusSave` to protect PCK exports.** Save security solves a different trust problem. **Do not add another default Autoload, generic DRM manager, or shared encryption secret.**

## Threat model

| Threat | Relevant controls | Residual risk |
| --- | --- | --- |
| Low-effort download, reupload, name/icon swap | Official storefront presence, executable signing, documented author/provenance | An impostor can publish a different signed program |
| Automated PCK extraction and asset re-use | Optional custom encrypted export templates; selective encryption | Decryption key is present in the shipped binary |
| Malware/ad injection into counterfeit | Valid publisher signature, trusted distribution URLs, incident evidence | User may install a re-signed malicious build |
| Fake DLC and hostile resource packs | Existing Nucleus signed official Content Packs; explicit mod trust policy | A compromised publisher private key or executable bypass remains possible |
| Fake platform user ID and unpaid privileged service | Store ticket validation on a trusted backend, explicit authorization | Compromised endpoints and account abuse still require server defenses |
| Stolen textures/audio and ownership dispute | Licenses, original files and commits, optional watermarking, takedown playbook | Watermarks can be removed or transform-sensitive |

**Non-goals:** anti-cheat, kernel-level anti-tamper, copy-proof asset encryption, always-online-by-default, automatic legal ownership proof, guaranteed detection of counterfeit store listings, platform-specific SDK code in Core, and restrictions on legitimate MIT reuse of the Nucleus addon.

## Architecture

```text
Godot 4.7 engine-native release facilities
  ├── exporter / encrypted PCK (optional custom engine templates)
  ├── Windows executable signing / macOS signing + notarization
  └── native resource/archive export
                  │
                  ▼
Consuming game's release pipeline (owns the policy)
  ├── export presets + secret store + cert / template toolchain
  ├── optional audit_game_exports.py (read-only preflight)
  ├── artifact verification + provenance records
  ├── official distribution / store identity
  └── response playbook / rights evidence
                  │
                  ▼
Optional existing Nucleus boundaries
  ├── Content Packs: trusted official DLC signatures
  └── Platform Services: provider-neutral lifecycle only
                  │
                  ▼
Game-owned integrations (when needed)
  ├── store SDK adapter
  ├── trusted backend: identity + entitlement validation
  └── watermarking build step / community and legal response
```

**Ownership:** Godot owns native export primitives; Nucleus owns discoverable advice, opt-in preflight tooling and reusable signed-content/provider boundaries; the shipping game owns its certificates, keys, store accounts, server contracts and release policy.

## Proposed adoption in small slices

| Slice | Proposed change | Owner | Acceptance |
| --- | --- | --- | --- |
| 0. Documentation | Quickstart, architecture, reupload playbook | Nucleus `docs/` | A new user can select a protection strategy without reading Godot internals |
| 1. Optional preflight | `scripts/ci/audit_game_exports.py` + isolated Python tests | Nucleus developer tooling | No secrets read/disclosed; expected findings on sample presets; no change to baseline CI |
| 2. Secure release recipes | Example workflow for *consuming game* (not Nucleus addon) | Individual game repository | Windows signed build verifies; a custom-template PCK build starts and opens encrypted resources |
| 3. Platform extension | Game-owned Steam/other SDK adapter, optional backend | Individual game repository | Fake client identity/ticket denied server-side; legitimate offline play policy exercised |
| 4. Forensic extras | Optional image/audio watermarking and independent provenance signatures | Per-game build pipeline | Detection precision tested on resized/reencoded assets; evidence is not public-secret dependent |

Each slice can be independently rejected without affecting gameplay systems. No new global runtime dependencies are needed for slices 0-2.

## Native PCK implementation prerequisites

1. Use the game's exact pinned Godot engine build; official prebuilt export templates alone **cannot decrypt an encrypted PCK**.
2. Generate a **unique 32-byte key** per game and control it outside Git; avoid reusable Nucleus-wide secrets.
3. Compile matching custom release templates with `SCRIPT_AES256_ENCRYPTION_KEY`.
4. Configure `encrypt_pck=true`, a real nonempty `encryption_include_filters`, and a release template in the game's export preset.
5. Provide `GODOT_SCRIPT_ENCRYPTION_KEY` securely while exporting; Godot 4.7 manages sensitive values in `.godot/export_credentials.cfg` rather than the shareable preset file.
6. Test encrypted exported builds and the update/DLC path, inspect final artifacts, and record the result; static option inspection alone does not establish protection.

Warning: format/option support for Web/mobile differs; review the actual target's export process. Signing and encryption solve different problems.

## CI contract

Nucleus ships a **Godot addon**. Its present headless test runner and Linux/Windows/Web smoke exports must remain available on GitHub-hosted test infrastructure **without signing identities or secret encryption keys**. Do not retrofit a security-enabled production export into those smoke tests or break public PR CI.

The opt-in script should be used from an actual game's release workflow, for example:

```bash
python3 scripts/ci/audit_game_exports.py \
  --project . --preset "Windows Release" --profile hardened --json
```

The preflight emits `error`, `warning`, `info` entries; `--strict` turns warnings into a non-zero exit code. It only inspects general export-preset intent. It cannot verify certificates, launch a binary, discover secrets from a secure credential store, or prove that PCK encryption works.

### Release gate that *must* be tested by the consuming game

1. Build in a pinned toolchain with secure secrets injection (no secrets in shell logs/artifacts).
2. Export the game in release mode and smoke-test the exact final artifact.
3. Confirm signatures with platform tooling; validate signer identity and timestamp policy.
4. For encrypted builds, confirm both resource loading and extraction resistance at the expected threat level.
5. Store SHA-256 hashes and signed release provenance / dated delivery records. **A bare unsigned hash can be recomputed by an attacker.**
6. Test offline startup, installs, patching, anti-virus behavior, saves, network authentication and DLC mounting if present.
7. Check generated archives/artifacts for keys, internal source, credential files and unintended bundled tools.

## Suggested Nucleus documentation placement

- `docs/guides/game_protection_quickstart.md` — primary user-facing entry point.
- `docs/architecture/game_distribution_security.md` — contracts, roadmap, limitations.
- `docs/guides/reupload_response_playbook.md` — evidence and complaint response.
- `scripts/ci/audit_game_exports.py` and `test_audit_game_exports.py` — optional, read-only tool.

If accepted upstream, link the quickstart from `README.md` and `docs/README.md`. Avoid adding code-search/use-case registry claims suggesting any runtime DRM API exists. A future runtime component requires real cross-game demand, a stable public contract and Godot tests.

## Validation and known limits

**Review and preflight tests available in this overlay:** Python syntax and focused unit tests only. **Not performed:** Nucleus CI, Godot `4.7.2-stable` import or exported-binary signing/encryption testing. Nucleus's existing security primitives were inspected read-only; no repository changes were made.

## Sources

- Godot 4.7 [PCK encryption key](https://docs.godotengine.org/en/4.7/engine_details/development/compiling/compiling_with_script_encryption_key.html), [export projects and credentials](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html), [Windows signing](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_windows.html), [macOS signing](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_macos.html).
- Valve [Steam DRM wrapper](https://partner.steamgames.com/doc/features/drm) and [authentication/ownership](https://partner.steamgames.com/doc/features/auth).
- Nucleus existing [Content Packs](../modules/content_packs.md), [Platform Services](../modules/platform_services.md), [Releasing](../guides/releasing.md).
- GodotCon slides supplied by the project owner: *The Clone Wars: Defending Godot Games From Reupload Scams*, pp. 3-22.
