#!/usr/bin/env python3
"""Validate experimental addon boundaries and manifest shape without Godot."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "addons/nucleus"
CATALOG = ROOT / "package_catalog.json"


def main() -> int:
    assert (ADDON / "plugin.cfg").is_file(), "Missing addon entry point"
    assert (ADDON / "plugin.gd").is_file(), "Missing editor plugin"
    assert (ADDON / "AGENTS.md").is_file(), "Missing addon agent rules"
    assert (ADDON / "README.md").is_file(), "Missing addon documentation"
    paths = [
        ADDON / "plugin.gd",
        *sorted((ADDON / "editor").glob("*.gd")),
    ]
    for path in paths:
        source = path.read_text(encoding="utf-8")
        assert "res://core/" not in source, f"Optional legacy core path referenced: {path}"
        assert "res://modules/" not in source, f"Hard module reference: {path}"
        assert "res://components/" not in source, f"Hard component reference: {path}"
    doc = json.loads(CATALOG.read_text(encoding="utf-8"))
    assert doc["schema"] == 1
    ids = set()
    for entry in doc["packages"]:
        ident = entry["id"]
        assert ident not in ids, f"Duplicate package ID: {ident}"
        ids.add(ident)
        assert entry["path"].startswith(("modules/", "components/"))
        assert ".." not in entry["path"] and "\\" not in entry["path"]
        assert isinstance(entry["dependencies"], list)
    for entry in doc["packages"]:
        for dep in entry["dependencies"]:
            assert dep in ids, f"Missing dependency {dep} for {entry['id']}"
    print(f"Nucleus scaffold OK: {len(paths)} scripts, {len(ids)} catalog entries.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
