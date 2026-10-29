#!/usr/bin/env python3
"""Create, update and validate native gettext catalogues without a second PO parser."""
from __future__ import annotations
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def run(args: list[str]) -> None:
    if not shutil.which(args[0]):
        raise SystemExit(f"Missing {args[0]}; install GNU gettext (or use Poedit/Weblate).")
    completed = subprocess.run(args, timeout=30, capture_output=True, text=True)
    if completed.returncode:
        raise RuntimeError((completed.stdout + completed.stderr).strip())
    if completed.stdout:
        print(completed.stdout, end="")
    if completed.stderr:
        print(completed.stderr, end="")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    check = commands.add_parser("check")
    check.add_argument("paths", nargs="+")
    for name in ("init", "update"):
        item = commands.add_parser(name)
        item.add_argument("template", type=Path)
        item.add_argument("output", type=Path)
        if name == "init":
            item.add_argument("--locale", required=True)
    args = parser.parse_args()
    if args.command == "check":
        for path in args.paths:
            run(["msgfmt", "--check", "--check-format", "--statistics", "-o", os.devnull, path])
        return
    run_catalog_operation(args.command, args.template, args.output, getattr(args, "locale", ""))


def run_catalog_operation(command: str, template: Path, output: Path, locale: str = "") -> None:
    if command not in ("init", "update"):
        raise ValueError("Unsupported catalog operation")
    if template.suffix.lower() != ".pot" or output.suffix.lower() != ".po":
        raise ValueError("Expected a .pot template and a .po output")
    if command == "init" and (not locale or not all(c.isalnum() or c in "_@-." for c in locale)):
        raise ValueError("Specify a valid locale identifier")
    if not template.is_file():
        raise ValueError("Template does not exist")
    if command == "init" and output.exists():
        raise ValueError("Refusing to replace an existing translation; use update")
    if command == "update" and not output.is_file():
        raise ValueError("Translation does not exist; use init")
    original = output.read_bytes() if output.exists() else None
    with tempfile.TemporaryDirectory(prefix=".nucleus-l10n-", dir=output.parent) as directory:
        temporary = Path(directory) / "catalog.po"
        if command == "init":
            run(["msginit", "--no-translator", "--input", str(template),
                 "--locale", locale, "--output-file", str(temporary)])
        else:
            run(["msgmerge", "--previous", str(output), str(template),
                 "--output-file", str(temporary)])
        run(["msgfmt", "--check-format", "-o", os.devnull, str(temporary)])
        if original is None and output.exists():
            raise ValueError("Output appeared during creation; refusing to overwrite")
        if original is not None and (not output.exists() or output.read_bytes() != original):
            raise ValueError("Catalog changed during update; retry after saving external edits")
        if output.exists():
            backup = output.with_suffix(output.suffix + ".bak")
            if backup.exists():
                raise ValueError(f"Move the previous backup first: {backup}")
            with backup.open("xb") as stream:
                stream.write(original)
        os.replace(temporary, output)


if __name__ == "__main__":
    main()
