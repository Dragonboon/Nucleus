#!/usr/bin/env python3
"""Verify every top-level Nucleus subsystem is mapped to documentation."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from console_report import ConsoleReport, add_console_arguments


def discover_directories(root: Path, relative: str) -> set[str]:
	base = root / relative
	if not base.is_dir():
		return set()
	return {
		path.relative_to(root).as_posix()
		for path in base.iterdir()
		if path.is_dir()
	}


def main() -> int:
	parser = argparse.ArgumentParser()
	parser.add_argument("--root", type=Path, default=Path.cwd())
	add_console_arguments(parser)
	args = parser.parse_args()
	root = args.root.resolve()
	report = ConsoleReport("Documentation coverage", args)

	manifest_path = root / "docs" / "documentation_coverage.json"
	if not manifest_path.is_file():
		report.metric("Manifest", "MISSING")
		return report.finish(["missing docs/documentation_coverage.json"])

	try:
		manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
		coverage: dict[str, list[str]] = manifest.get("coverage", {})
	except (OSError, UnicodeError, ValueError, AttributeError, TypeError) as exc:
		return report.finish([f"docs/documentation_coverage.json: unable to load ({exc})"])

	discovered: set[str] = set()
	discovered |= discover_directories(root, "addons/nucleus/core")
	discovered |= discover_directories(root, "addons/nucleus/modules")
	discovered |= discover_directories(root, "addons/nucleus/components/gameplay")
	discovered |= discover_directories(root, "addons/nucleus/components/ui")
	discovered |= discover_directories(root, "addons/nucleus/components/world")

	errors: list[str] = []
	mapped = set(coverage)

	for subsystem in sorted(discovered - mapped):
		errors.append(f"unmapped subsystem: {subsystem}")

	for subsystem in sorted(mapped - discovered):
		errors.append(f"manifest references missing subsystem: {subsystem}")

	target_count = 0
	for subsystem, documents in sorted(coverage.items()):
		if not documents:
			errors.append(f"{subsystem}: no documentation targets")
			continue

		for document in documents:
			target_count += 1
			if not (root / document).is_file():
				errors.append(f"{subsystem}: missing documentation file {document}")

	report.metric("Discovered", f"{len(discovered)} top-level subsystems")
	report.fraction("Coverage", len(discovered & mapped), len(discovered))
	report.metric("Manifest", f"{len(mapped)} mapped subsystems")
	report.metric("Documentation links", f"{target_count} declared targets verified")
	report.metric("Unmapped", str(len(discovered - mapped)))
	report.metric("Stale mappings", str(len(mapped - discovered)))
	report.hint("Update docs/documentation_coverage.json when adding a subsystem.")
	return report.finish(errors)


if __name__ == "__main__":
	raise SystemExit(main())
