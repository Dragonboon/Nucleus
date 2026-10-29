#!/usr/bin/env python3
"""Build a reproducible, Git-tracked Nucleus Godot addon release package."""

from __future__ import annotations

import argparse
import configparser
import hashlib
import json
import os
import re
import subprocess
import sys
import zipfile
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = REPOSITORY_ROOT / "dist" / "releases"
EXCLUDED_PARTS = {
	".ci",
	".git",
	".godot",
	"__pycache__",
	"build",
	"dist",
}
SEMVER_RE = re.compile(
	r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
	r"(?:-"
	r"(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)"
	r"(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*"
	r")?"
	r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)
FIXED_ZIP_TIME = (1980, 1, 1, 0, 0, 0)


def run_git(*args: str) -> str:
	result = subprocess.run(
		["git", *args],
		cwd=REPOSITORY_ROOT,
		check=True,
		capture_output=True,
		text=True,
	)
	return result.stdout


def validate_version(version: str) -> None:
	if not SEMVER_RE.fullmatch(version):
		raise SystemExit(
			f"VERSION '{version}' is not valid Semantic Versioning."
		)


def validate_repository() -> None:
	checks = (
		"scripts/ci/static_checks.py",
		"scripts/ci/documentation_audit.py",
		"scripts/ci/productization_audit.py",
	)

	for relative in checks:
		subprocess.run(
			[sys.executable, str(REPOSITORY_ROOT / relative)],
			cwd=REPOSITORY_ROOT,
			check=True,
		)


def tracked_files() -> list[Path]:
	raw = subprocess.check_output(
		["git", "ls-files", "-z"],
		cwd=REPOSITORY_ROOT,
	)
	paths: list[Path] = []

	for encoded in raw.split(b"\0"):
		if not encoded:
			continue

		relative = Path(os.fsdecode(encoded))

		if (len(relative.parts) < 3 or relative.parts[0] != "addons"
				or relative.parts[1] not in {"nucleus", "nucleus_localization"}):
			continue

		if any(part in EXCLUDED_PARTS for part in relative.parts):
			continue

		full_path = REPOSITORY_ROOT / relative

		if full_path.is_file():
			paths.append(relative)

	return sorted(paths, key=lambda path: path.as_posix())


def sha256_bytes(data: bytes) -> str:
	return hashlib.sha256(data).hexdigest()


def zip_info(
	archive_path: str,
	source: Path | None = None,
) -> zipfile.ZipInfo:
	info = zipfile.ZipInfo(archive_path, FIXED_ZIP_TIME)
	info.compress_type = zipfile.ZIP_DEFLATED
	mode = 0o644

	if source is not None and os.access(source, os.X_OK):
		mode = 0o755

	info.external_attr = (mode & 0xFFFF) << 16
	return info


def build_manifest(
	version: str,
	commit: str,
	dirty: bool,
	paths: list[Path],
) -> dict:
	file_entries = []

	for relative in paths:
		data = (REPOSITORY_ROOT / relative).read_bytes()
		file_entries.append(
			{
				"path": relative.as_posix(),
				"sha256": sha256_bytes(data),
				"size": len(data),
			}
		)

	return {
		"name": "Nucleus",
		"version": version,
		"source_commit": commit,
		"dirty": dirty,
		"godot": {
			"reference": "4.7.2-stable",
			"target_line": "4.7.x",
		},
		"file_count": len(file_entries),
		"files": file_entries,
	}


def create_package(
	output_dir: Path,
	allow_dirty: bool,
	skip_validation: bool,
) -> tuple[Path, Path]:
	version = (REPOSITORY_ROOT / "VERSION").read_text(
		encoding="utf-8"
	).strip()
	validate_version(version)
	addon = REPOSITORY_ROOT / "addons/nucleus"
	metadata = configparser.ConfigParser()
	metadata.read(addon / "plugin.cfg", encoding="utf-8")
	plugin_version = metadata.get("plugin", "version").strip('"')
	if (addon / "VERSION").read_text(encoding="utf-8").strip() != version or (
		plugin_version != version
	):
		raise SystemExit("Root VERSION, addon VERSION and plugin.cfg must match.")
	if (addon / "LICENSE").read_bytes() != (REPOSITORY_ROOT / "LICENSE").read_bytes():
		raise SystemExit("The addon must ship the repository's complete LICENSE.")

	try:
		commit = run_git("rev-parse", "HEAD").strip()
		status = run_git("status", "--porcelain").strip()
	except (OSError, subprocess.CalledProcessError) as exc:
		raise SystemExit(f"Git repository inspection failed: {exc}") from exc

	dirty = bool(status)

	if dirty and not allow_dirty:
		raise SystemExit(
			"Refusing to package a dirty working tree. "
			"Commit/stash changes or pass --allow-dirty for local testing."
		)

	if not skip_validation:
		validate_repository()

	paths = tracked_files()
	manifest = build_manifest(
		version,
		commit,
		dirty,
		paths,
	)
	manifest_bytes = (
		json.dumps(
			manifest,
			indent=2,
			sort_keys=True,
		)
		+ "\n"
	).encode("utf-8")

	output_dir.mkdir(parents=True, exist_ok=True)
	package_name = f"Nucleus-{version}.zip"
	package_path = output_dir / package_name
	prefix = "addons/nucleus"

	with zipfile.ZipFile(
		package_path,
		mode="w",
		compression=zipfile.ZIP_DEFLATED,
		compresslevel=9,
	) as archive:
		for relative in paths:
			source = REPOSITORY_ROOT / relative
			data = source.read_bytes()
			info = zip_info(
				relative.as_posix(),
				source,
			)
			archive.writestr(info, data)

		manifest_info = zip_info(
			f"{prefix}/RELEASE_MANIFEST.json"
		)
		archive.writestr(
			manifest_info,
			manifest_bytes,
		)

	package_hash = hashlib.sha256(package_path.read_bytes()).hexdigest()
	checksum_path = output_dir / f"{package_name}.sha256"
	checksum_path.write_text(
		f"{package_hash}  {package_name}\n",
		encoding="utf-8",
		newline="\n",
	)

	return package_path, checksum_path


def main() -> int:
	parser = argparse.ArgumentParser()
	parser.add_argument(
		"--output-dir",
		type=Path,
		default=DEFAULT_OUTPUT,
	)
	parser.add_argument(
		"--allow-dirty",
		action="store_true",
		help="Allow local test packages from a dirty tree.",
	)
	parser.add_argument(
		"--skip-validation",
		action="store_true",
		help="Skip Python audits when the caller already ran them.",
	)
	args = parser.parse_args()

	output_dir = args.output_dir

	if not output_dir.is_absolute():
		output_dir = REPOSITORY_ROOT / output_dir

	package_path, checksum_path = create_package(
		output_dir.resolve(),
		args.allow_dirty,
		args.skip_validation,
	)

	print(f"Nucleus release package: {package_path}")
	print(f"SHA-256 file: {checksum_path}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
