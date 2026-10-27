# Nucleus addon — agent rules

- The editor plugin must parse when no optional modules are installed.
- Do not refer statically to types outside `addons/nucleus/` from the plugin.
- Never overwrite, delete or execute remote package content without validation.
- All downloaded paths must remain under a declared, allowlisted package root.
- Reject archive traversal, absolute paths and undeclared dependencies.
- Keep file changes reversible and verify SHA-256 of immutable release assets.
- Preserve `.gd.uid` files and document resource-path migrations.
- Package installation is disabled until these guarantees have tests.
- Validate plugin enable/disable and a clean empty consumer project.
