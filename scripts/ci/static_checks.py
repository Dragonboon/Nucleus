#!/usr/bin/env python3
"""Dependency-free repository checks for Nucleus source conventions."""

from __future__ import annotations

import argparse
import re
from collections import Counter
from pathlib import Path

from console_report import ConsoleReport, add_console_arguments

TEXT_SUFFIXES = {
	".cfg",
	".gd",
	".gdshader",
	".json",
	".md",
	".py",
	".sh",
	".tscn",
	".tres",
	".uid",
	".yaml",
	".yml",
}
SKIP_DIRS = {".ci", ".git", ".godot", "build", "dist"}
CLASS_NAME_RE = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)\s*$")
UID_RE = re.compile(r"^uid://[a-z0-9]+$")

# Only reusable Nucleus-owned source requires the public Nucleus prefix.
# Consuming projects may define game-owned scripts under game/ (or other
# project-specific folders) without renaming their public classes.
NUCLEUS_SOURCE_DIRS = frozenset({"core", "components", "modules"})

TEST_ROOT = Path("tests/headless")
TEST_CASE_PATH = TEST_ROOT / "test_case.gd"
TEST_MANIFEST_PATH = TEST_ROOT / "test_manifest.gd"
TEST_CASE_EXTENDS = 'extends "res://tests/headless/test_case.gd"'
TEST_RUN_RE = re.compile(r"(?m)^func run\(\) -> Dictionary:\s*$")
TEST_FUNC_RE = re.compile(r"(?m)^func ([A-Za-z_][A-Za-z0-9_]*)\s*\(")
EXPECT_CALL_RE = re.compile(r"(?<![\w.])(expect_[A-Za-z0-9_]+)\s*\(")
LEGACY_TEST_HELPER_RE = re.compile(r"(?<![\w.])(check|result)\s*\(")
MANIFEST_SUITE_RE = re.compile(
	r'preload\("(res://tests/headless/[^"]+_test\.gd)"\)'
)

NUCLEUS_OWNED_API_RULES = (
	(
		re.compile(r"\bInput\.mouse_mode\s*="),
		frozenset({"addons/nucleus/core/input/cursor.gd"}),
		"use NucleusCursor instead of assigning Input.mouse_mode directly",
	),
	(
		re.compile(r"\bDisplayServer\.window_set_mode\s*\("),
		frozenset({"addons/nucleus/core/settings/appliers/display_settings_applier.gd"}),
		"use NucleusSettings; display window mode is owned by its applier",
	),
	(
		re.compile(r"\bDisplayServer\.window_set_vsync_mode\s*\("),
		frozenset({"addons/nucleus/core/settings/appliers/display_settings_applier.gd"}),
		"use NucleusSettings; VSync is owned by its display applier",
	),
	(
		re.compile(r"\bEngine\.max_fps\s*="),
		frozenset({"addons/nucleus/core/settings/appliers/display_settings_applier.gd"}),
		"use NucleusSettings; the frame limit is owned by its display applier",
	),
	(
		re.compile(r"\bProjectSettings\.load_resource_pack\s*\("),
		frozenset({"addons/nucleus/modules/content_packs/content_pack_loader.gd"}),
		"use the verified Content Packs loader before mounting resource packs",
	),
	(
		re.compile(r"\bInput\.vibrate_handheld\s*\("),
		frozenset({"addons/nucleus/core/input/haptics.gd"}),
		"use NucleusHaptics so vibration settings apply across devices",
	),
	(
		re.compile(r"\bDisplayServer\.screen_set_orientation\s*\("),
		frozenset({"addons/nucleus/modules/mobile/orientation_policy.gd"}),
		"use NucleusMobileOrientationPolicy for reusable orientation policy",
	),
	(
		re.compile(r"\bOS\.request_permissions?\s*\("),
		frozenset({"addons/nucleus/modules/mobile/mobile_permissions.gd"}),
		"use NucleusMobilePermissions at the user-visible permission boundary",
	),
)


def iter_text_files(root: Path):
	for path in root.rglob("*"):
		if not path.is_file() or path.suffix.lower() not in TEXT_SUFFIXES:
			continue
		if any(part in SKIP_DIRS for part in path.parts):
			continue
		yield path


def _is_test_path(relative: str) -> bool:
	return relative.startswith("tests/") or "/tests/" in relative


def check_file(path: Path, repository_root: Path) -> list[str]:
	errors: list[str] = []
	relative = path.relative_to(repository_root).as_posix()
	raw = path.read_bytes()

	if b"\r\n" in raw or b"\r" in raw:
		errors.append(f"{relative}: use LF line endings")

	if raw and not raw.endswith(b"\n"):
		errors.append(f"{relative}: missing final newline")

	try:
		text = raw.decode("utf-8")
	except UnicodeDecodeError:
		return [f"{relative}: file is not valid UTF-8"]

	lines = text.splitlines()

	for number, line in enumerate(lines, start=1):
		if line.rstrip() != line:
			errors.append(f"{relative}:{number}: trailing whitespace")

		if path.suffix == ".gd" and len(line) > 100:
			errors.append(
				f"{relative}:{number}: GDScript line exceeds 100 columns"
			)

	if path.suffix == ".gd":
		is_nucleus_source = relative.removeprefix("addons/nucleus/").split("/", 1)[0] in NUCLEUS_SOURCE_DIRS
		for number, line in enumerate(lines, start=1):
			if line.startswith(" "):
				errors.append(
					f"{relative}:{number}: GDScript indentation must use tabs"
				)

			match = CLASS_NAME_RE.match(line)
			if match and is_nucleus_source and not match.group(1).startswith("Nucleus"):
				errors.append(
					f"{relative}:{number}: public class_name must use Nucleus prefix"
				)

		if not _is_test_path(relative):
			for pattern, allowed_paths, guidance in NUCLEUS_OWNED_API_RULES:
				if relative in allowed_paths:
					continue

				for match in pattern.finditer(text):
					number = text.count("\n", 0, match.start()) + 1
					errors.append(
						f"{relative}:{number}: Nucleus-owned API bypass; {guidance}"
					)

	return errors


def check_uid_contract(repository_root: Path) -> list[str]:
	errors: list[str] = []
	seen: dict[str, str] = {}

	for path in sorted(repository_root.rglob("*.uid")):
		relative = path.relative_to(repository_root).as_posix()

		if any(part in SKIP_DIRS for part in path.parts):
			continue

		try:
			value = path.read_text(encoding="utf-8").strip()
		except (OSError, UnicodeDecodeError) as exc:
			errors.append(f"{relative}: unable to read UID ({exc})")
			continue

		if not UID_RE.fullmatch(value):
			errors.append(f"{relative}: invalid Godot UID '{value}'")
			continue

		if value in seen:
			errors.append(
				f"{relative}: duplicate Godot UID {value}; "
				f"already used by {seen[value]}"
			)
			continue

		seen[value] = relative

	return errors


def check_test_contract(repository_root: Path) -> list[str]:
	errors: list[str] = []
	test_root = repository_root / TEST_ROOT
	test_case_path = repository_root / TEST_CASE_PATH
	manifest_path = repository_root / TEST_MANIFEST_PATH

	if not test_case_path.is_file():
		return [f"{TEST_CASE_PATH.as_posix()}: missing test base"]

	if not manifest_path.is_file():
		return [f"{TEST_MANIFEST_PATH.as_posix()}: missing suite manifest"]

	test_case_text = test_case_path.read_text(encoding="utf-8")
	available_helpers = set(TEST_FUNC_RE.findall(test_case_text))

	if "finish" not in available_helpers:
		errors.append(
			f"{TEST_CASE_PATH.as_posix()}: test base must define finish()"
		)

	manifest_text = manifest_path.read_text(encoding="utf-8")
	manifest_suites = set(MANIFEST_SUITE_RE.findall(manifest_text))
	discovered_suites: set[str] = set()

	for suite_path in sorted(test_root.glob("*_test.gd")):
		relative = suite_path.relative_to(repository_root).as_posix()
		resource_path = "res://" + relative
		discovered_suites.add(resource_path)
		text = suite_path.read_text(encoding="utf-8")

		if TEST_CASE_EXTENDS not in text:
			errors.append(
				f"{relative}: test suite must extend tests/headless/test_case.gd"
			)

		if not TEST_RUN_RE.search(text):
			errors.append(
				f"{relative}: test suite must define run() -> Dictionary"
			)

		if "return finish()" not in text:
			errors.append(
				f"{relative}: test suite must return finish()"
			)

		for helper in sorted(set(EXPECT_CALL_RE.findall(text))):
			if helper not in available_helpers:
				errors.append(
					f"{relative}: unknown test helper {helper}()"
				)

		for legacy_helper in sorted(set(LEGACY_TEST_HELPER_RE.findall(text))):
			errors.append(
				f"{relative}: unsupported test helper {legacy_helper}(); "
				"use expect_*() and finish()"
			)

	for resource_path in sorted(discovered_suites - manifest_suites):
		errors.append(
			f"{TEST_MANIFEST_PATH.as_posix()}: missing suite {resource_path}"
		)

	for resource_path in sorted(manifest_suites - discovered_suites):
		errors.append(
			f"{TEST_MANIFEST_PATH.as_posix()}: references missing suite "
			f"{resource_path}"
		)

	return errors


def main() -> int:
	parser = argparse.ArgumentParser()
	parser.add_argument(
		"--root",
		type=Path,
		default=Path.cwd(),
		help="Repository root; defaults to the current working directory.",
	)
	add_console_arguments(parser)
	args = parser.parse_args()
	repository_root = args.root.resolve()
	report = ConsoleReport("Static repository checks", args)

	files = list(iter_text_files(repository_root))
	errors: list[str] = []
	for path in files:
		errors.extend(check_file(path, repository_root))

	errors.extend(check_uid_contract(repository_root))
	errors.extend(check_test_contract(repository_root))

	gd_count = sum(path.suffix == ".gd" for path in files)
	owned_count = sum(
		path.suffix == ".gd"
		and path.relative_to(repository_root).as_posix().removeprefix(
			"addons/nucleus/"
		).split("/", 1)[0] in NUCLEUS_SOURCE_DIRS
		for path in files
	)
	uid_count = sum(path.suffix == ".uid" for path in files)
	test_count = len(list((repository_root / TEST_ROOT).glob("*_test.gd")))
	kinds = Counter(path.suffix for path in files)
	report.metric("Files inspected", f"{len(files)} text files / {gd_count} GDScript")
	report.metric("Top file types", ", ".join(
		f"{suffix}: {count}" for suffix, count in kinds.most_common(4)
	))
	report.metric("Public class scope", f"{owned_count} Nucleus-owned scripts; game scripts exempt")
	report.metric("API ownership", f"{len(NUCLEUS_OWNED_API_RULES)} protected engine operations")
	report.metric("Godot UIDs", f"{uid_count} UID files checked for format and uniqueness")
	report.metric("Headless suites", f"{test_count} discovered; manifest + helpers validated")
	report.hint("Run documentation_audit.py and use_case_audit.py for contract coverage.")
	return report.finish(errors)


if __name__ == "__main__":
	raise SystemExit(main())
