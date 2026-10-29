# Publish Nucleus as a downloadable addon

The repository is the development source; the installable product is only
`addons/nucleus/`. Do not submit it as a template or standalone project.

## Submission information

- Name: Nucleus.
- Repository: https://github.com/Dragonboon/Nucleus
- Issues: https://github.com/Dragonboon/Nucleus/issues
- License: MIT; retain the complete LICENSE inside the addon.
- Supported engine: the pinned Godot 4.7 line; reference 4.7.2-stable.
- Version: the exact root VERSION, addon VERSION and plugin.cfg version.
- Description: Modular Godot foundation for existing and new projects. Includes
  six core services, composable gameplay/UI/world components, optional modules,
  integrated localization and an editor dock for dependency-aware dimensional
  profiles, verified main updates and backup restoration.

There is no verified public listing ID in this repository yet. After approval,
replace the README's pending-distribution notice with the exact official listing
URL. Never invent an asset ID or claim availability before approval.

## Prepare and validate

1. Choose an exact commit with successful Nucleus CI and review the supported
   engine, pre-1.0 maturity and migration notes.
2. Run all release audits and the isolated installation/profile/update gates.
3. Build `python3 scripts/package_release.py` from a clean checkout. The ZIP has
   no project wrapper and contains only the installable addon plus its manifest.
4. Verify the SHA-256, inspect the archive and install it in an existing project.
5. Publish the ZIP/checksum in a versioned GitHub Release, or obtain the same
   artifacts from the Nucleus Release Package workflow.
6. Submit using the current official store's author workflow. Use a square PNG
   or JPG icon and current dock screenshots. The root SVG is source artwork;
   provide a suitable raster icon when the submission form requires one.
7. If using the legacy Asset Library's repository/commit workflow, pin the
   Download Commit to the tested revision. `.gitattributes` export rules exclude
   development files from Git-generated source archives.
8. After approval, record the real listing URL in README and installation docs.

The newer Asset Store and legacy Asset Library are separate publication channels;
legacy approval does not imply a new-store listing. Follow the current official
submission form rather than treating these metadata notes as automatic publication.

Official guidance:
https://docs.godotengine.org/en/stable/community/asset_store/what_is_asset_store.html
https://docs.godotengine.org/en/stable/community/asset_library/submitting_to_assetlib.html

## Repository versus installation

Keep AGENTS, docs, examples/labs, tests, CI, scripts, tools and root project
settings in the development checkout. They are not runtime requirements. Source
ZIP exports intentionally omit them; contributors should use git clone for the
complete development workspace. The addon retains its own README, LICENSE,
VERSION, plugin metadata and dependency/integrity inventory.
