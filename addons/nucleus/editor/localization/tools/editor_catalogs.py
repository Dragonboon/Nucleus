#!/usr/bin/env python3
"""JSON bridge for the optional editor panel; gettext remains the PO authority."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

TOOLS = ("msginit", "msgmerge", "msgfmt", "msgcmp")


def execute(args: list[str]) -> subprocess.CompletedProcess:
    environment = dict(os.environ, LC_ALL="C", LANG="C")
    return subprocess.run(args, capture_output=True, text=True, errors="replace",
                          timeout=30, env=environment)


def inspect_catalog(path: str, template: str = "") -> dict:
    result = execute(["msgfmt", "--check", "--check-format", "--statistics",
                      "-o", os.devnull, path])
    diagnostic = result.stdout + result.stderr
    counts = {}
    for key, phrase in (("translated", "translated message"), ("fuzzy", "fuzzy translation"),
                        ("untranslated", "untranslated message")):
        match = re.search(r"(?<!\w)(\d+) " + phrase, diagnostic)
        counts[key] = int(match.group(1)) if match else 0
    drift = None
    if template and result.returncode == 0:
        comparison = execute(["msgcmp", "--use-fuzzy", "--use-untranslated",
                              "--no-fuzzy-matching", path, template])
        drift = comparison.returncode != 0
        diagnostic += comparison.stdout + comparison.stderr
    return dict(path=path, ok=result.returncode == 0, needs_update=drift,
                diagnostics=diagnostic.strip(), **counts)


def manage(command: str, template: Path, output: Path, locale: str = "") -> dict:
    # Same conservative contracts as the existing CLI; no shell and no PO parser.
    from catalogs import run_catalog_operation
    run_catalog_operation(command, template, output, locale)
    return dict(ok=True, path=str(output), diagnostics="Catalog saved. " +
                ("Previous bytes preserved in .po.bak." if command == "update" else "Review translations."))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("command", choices=("doctor", "status", "init", "update"))
    parser.add_argument("--template", default="")
    parser.add_argument("--output", default="")
    parser.add_argument("--locale", default="")
    parser.add_argument("paths", nargs="*")
    args = parser.parse_intermixed_args()
    result = {"ok": False}
    try:
        missing = [tool for tool in TOOLS if not shutil.which(tool)]
        if missing:
            raise RuntimeError("Install GNU gettext and add its bin directory to PATH: " + ", ".join(missing))
        if args.command == "doctor":
            result = {"ok": True, "diagnostics": "Python and GNU gettext are available."}
        elif args.command == "status":
            if args.template and not Path(args.template).is_file():
                raise ValueError("Template not found: " + args.template)
            rows = [inspect_catalog(path, args.template) for path in args.paths]
            result = {"ok": all(row["ok"] for row in rows), "catalogs": rows}
        else:
            result = manage(args.command, Path(args.template), Path(args.output), args.locale)
    except (Exception, SystemExit) as error:
        result = {"ok": False, "diagnostics": str(error)}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    # Panel only consumes a complete report; subprocess output is never executable.
    temporary = args.report.with_suffix(".tmp")
    temporary.write_text(json.dumps(result, ensure_ascii=False), encoding="utf-8")
    os.replace(temporary, args.report)


if __name__ == "__main__":
    main()
