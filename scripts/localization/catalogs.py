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
    subprocess.run(args, check=True)


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
    if not args.template.is_file():
        parser.error("Template does not exist")
    if args.command == "init" and args.output.exists():
        parser.error("Refusing to replace an existing translation; use update")
    if args.command == "update" and not args.output.is_file():
        parser.error("Translation does not exist; use init")
    with tempfile.TemporaryDirectory(dir=args.output.parent) as directory:
        temporary = Path(directory) / "catalog.po"
        if args.command == "init":
            run(["msginit", "--no-translator", "--input", str(args.template),
                 "--locale", args.locale, "--output-file", str(temporary)])
        else:
            run(["msgmerge", "--previous", str(args.output), str(args.template),
                 "--output-file", str(temporary)])
        run(["msgfmt", "--check-format", "-o", os.devnull, str(temporary)])
        if args.output.exists():
            backup = args.output.with_suffix(args.output.suffix + ".bak")
            if backup.exists():
                parser.error(f"Move the previous backup first: {backup}")
            shutil.copy2(args.output, backup)
        os.replace(temporary, args.output)


if __name__ == "__main__":
    main()
