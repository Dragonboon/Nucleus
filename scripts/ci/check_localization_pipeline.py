#!/usr/bin/env python3
"""Exercise optional editor registration/extraction and real gettext in an isolated copy."""
from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("godot", type=Path)
    args = parser.parse_args()
    engine = str(args.godot.resolve())
    root = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix="nucleus-localization-") as directory:
        project = Path(directory) / "project"
        shutil.copytree(root, project, ignore=shutil.ignore_patterns(".git", ".godot", ".ci", "build"))
        subprocess.run(["msgfmt", str(root / "tests/fixtures/localization/es.po"),
                        "-o", str(project / "tests/fixtures/localization/es.mo")], check=True)
        settings = project / "project.godot"
        settings.write_text(settings.read_text() + '\n[editor_plugins]\n\nenabled=PackedStringArray("res://addons/nucleus_localization/plugin.cfg")\n')
        checked = str(root / "scripts/ci/run_godot_checked.py")
        subprocess.run(["python3", checked, engine, "--headless", "--path", str(project), "--import"],
                       check=True, timeout=120)
        settings.write_text(settings.read_text().replace(
            '"res://addons/nucleus_localization/plugin.cfg")',
            '"res://addons/nucleus_localization/plugin.cfg", "res://tests/tools/plugin.cfg")'))
        subprocess.run(["python3", checked, engine, "--headless", "--editor", "--path", str(project)],
                       check=True, timeout=120)
        manager = str(root / "scripts/localization/catalogs.py")
        template = str(project / "messages.pot")
        output = str(project / "es.po")
        subprocess.run(["python3", manager, "init", template, output, "--locale", "es"], check=True)
        # Start from real translated content; update must preserve translations and back up bytes.
        shutil.copy2(root / "core/localization/translations/es.po", output)
        before = Path(output).read_bytes()
        subprocess.run(["python3", manager, "update", template, output], check=True)
        assert Path(output + ".bak").read_bytes() == before
        assert 'Automático' in Path(output).read_text()
        subprocess.run(["python3", manager, "check", output], check=True)
        # Gettext must reject translated placeholders that no longer match the source.
        invalid = project / "bad.po"
        invalid.write_text(Path(output).read_text().replace("{device} está listo.", "Está listo."))
        rejected = subprocess.run(["python3", manager, "check", str(invalid)], capture_output=True)
        assert rejected.returncode != 0, "Broken placeholder unexpectedly accepted"
        print("Nucleus localization isolated editor/gettext pipeline: PASS")


if __name__ == "__main__":
    main()
