#!/usr/bin/env python3
"""Conservative copy-of-template pruning, with dry-run by default.

Removes only unambiguously dimension-tagged paths plus their .uid companions.
Never guesses that untagged files are unused. Blocks any removal referenced by
retained project content. This is a safe baseline, not a complete dependency
solver for dynamically loaded resources or external plugins.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

TEXT_EXTENSIONS = {".gd", ".tscn", ".tres", ".cfg", ".godot", ".json", ".md", ".py"}
SOURCE_ROOTS = ("components", "modules", "examples", "tests")
SKIP = {".git", ".godot", ".venv", "__pycache__", "build", "dist"}
DIMENSION = re.compile(r"(?:^|[_/-])(2d|3d)(?:[_/.-]|$)", re.I)


def collect(root: Path) -> list[Path]:
    return sorted(
        p for p in root.rglob("*")
        if p.is_file() and not any(part in SKIP for part in p.relative_to(root).parts)
    )


def candidates(files: list[Path], root: Path, profile: str) -> set[Path]:
    selected: set[Path] = set()
    for file in files:
        rel = file.relative_to(root).as_posix()
        if rel.startswith("addons/"):
            if profile == "addons":
                selected.add(file)
            continue
        if profile == "addons":
            continue
        if rel.startswith(SOURCE_ROOTS) and DIMENSION.search(rel):
            if profile in rel.lower().replace("-", "_").split("/") or (
                re.search(rf"(?:^|[_/-]){profile}(?:[_/.-]|$)", rel, re.I)
            ):
                selected.add(file)
    for file in list(selected):
        companion = file.with_name(file.name + ".uid")
        if companion.exists():
            selected.add(companion)
    return selected


def safe_relative(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def referenced_by(root: Path, file: Path, retained: list[Path]) -> list[str]:
    rel = safe_relative(root, file)
    exact = "res://" + rel
    # Godot also resolves script resource UIDs, so protect references to those.
    uid_path = file if file.suffix == ".uid" else Path(str(file) + ".uid")
    uid = uid_path.read_text(encoding="utf-8").strip() if uid_path.exists() else ""
    needles = [exact]
    if uid.startswith("uid://"):
        needles.append(uid)
    found: list[str] = []
    for other in retained:
        if other.suffix not in TEXT_EXTENSIONS:
            continue
        try:
            content = other.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        if any(needle in content for needle in needles):
            found.append(safe_relative(root, other))
    return found


def evaluate(root: Path, profile: str) -> dict:
    files = collect(root)
    removals = candidates(files, root, profile)
    blocked: dict[str, list[str]] = {}
    # Closure: if a retained source references a candidate, retain it and its
    # companion. Repeat because a newly retained candidate may reference others.
    while True:
        retained = [f for f in files if f not in removals]
        newly_blocked: dict[Path, list[str]] = {}
        for file in sorted(removals):
            if file.suffix == ".uid":
                continue
            refs = referenced_by(root, file, retained)
            if refs:
                newly_blocked[file] = refs
        if not newly_blocked:
            break
        for file, refs in newly_blocked.items():
            removals.discard(file)
            removals.discard(Path(str(file) + ".uid"))
            blocked[safe_relative(root, file)] = refs
    # Do not remove a UID if its source is not removed.
    removals = {
        f for f in removals
        if f.suffix != ".uid" or f.with_suffix("").exists()
        and f.with_suffix("") in removals
    }
    return {
        "profile": profile,
        "root": str(root),
        "delete": [safe_relative(root, f) for f in sorted(removals)],
        "blocked": blocked,
        "mode": "dry-run",
        "note": "Conservative pruning: untagged and dynamic dependencies need manual review.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", choices=("2d", "3d", "addons"))
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--apply", action="store_true", help="Actually delete candidates")
    parser.add_argument("--allow-blocked", action="store_true",
                        help="Keep referenced candidates, prune safe remainder")
    parser.add_argument("--report", type=Path, help="Optional JSON report")
    args = parser.parse_args()
    root = args.root.resolve()
    if not (root / "project.godot").is_file():
        parser.error("Not a Godot project: project.godot is missing")
    report = evaluate(root, args.profile)
    if args.apply and report["blocked"] and not args.allow_blocked:
        report["mode"] = "blocked: no deletion performed"
    elif args.apply:
        report["mode"] = "applied"
        for relative in report["delete"]:
            path = root / relative
            if path.is_symlink():
                continue
            path.unlink()
        for directory in sorted(root.rglob("*"), reverse=True):
            if directory.is_dir() and not directory.is_symlink():
                try:
                    directory.rmdir()
                except OSError:
                    pass
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 2 if report["mode"].startswith("blocked") else 0


if __name__ == "__main__":
    raise SystemExit(main())
