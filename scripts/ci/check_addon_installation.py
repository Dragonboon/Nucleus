#!/usr/bin/env python3
"""Exercise only packaged addons in an independent, pre-existing Godot project."""
from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("engine")
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="nucleus-host-") as folder:
        host = Path(folder)
        with zipfile.ZipFile(args.archive) as archive:
            paths = archive.namelist()
            assert all(p.startswith(("addons/nucleus/", "addons/nucleus_localization/"))
                       for p in paths), "Development files leaked into installation archive"
            assert not any(x in p.split("/") for p in paths
                           for x in (".godot", "__pycache__", "examples", "tests", "labs"))
            archive.extractall(host)
        probe = host / "addons/addon_probe"
        probe.mkdir()
        (probe / "plugin.gd").write_bytes(
            (ROOT / "tests/tools/addon_installation_check.gd").read_bytes())
        (probe / "plugin.cfg").write_text(
            '[plugin]\nname="Addon Probe"\ndescription="Test"\n'
            'author="Nucleus"\nversion="1"\nscript="plugin.gd"\n')
        (host / "host.gd").write_text('extends Node\n')
        (host / "host_main.gd").write_text('''extends Node
func _ready() -> void:
	for service: String in ["NucleusApp", "NucleusSettings", "NucleusInput",
			"NucleusAudio", "NucleusSave", "NucleusSceneFlow"]:
		assert(get_node_or_null("/root/" + service) != null, service)
	assert(get_node("/root/NucleusSettings").is_initialized())
	assert(Engine.max_fps == 71, "Host FPS limit was replaced")
	assert(is_equal_approx(AudioServer.get_bus_volume_db(0), -7.0))
	print("Nucleus independent host runtime: PASS")
	get_tree().quit()
''')
        (host / "host_main.tscn").write_text(
            '[gd_scene format=3]\n[ext_resource type="Script" '
            'path="res://host_main.gd" id="1"]\n'
            '[node name="Host" type="Node"]\nscript = ExtResource("1")\n')
        (host / "host_buses.tres").write_text(
            '[gd_resource type="AudioBusLayout" format=3]\n[resource]\n'
            'bus/0/name = &"Master"\nbus/0/volume_db = -7.0\n')
        (host / "project.godot").write_text('''config_version=5
[application]
config/name="Existing host project"
run/max_fps=71
run/main_scene="res://host_main.tscn"
[audio]
buses/default_bus_layout="res://host_buses.tres"
[application_run]
[rendering]
renderer/rendering_method="gl_compatibility"
[editor_plugins]
enabled=PackedStringArray("res://addons/addon_probe/plugin.cfg")
[custom]
keep="existing project data"
[application_dummy]
'''.replace('[application_run]\n', '').replace('[application_dummy]\n', ''))
        checked = str(ROOT / "scripts/ci/run_godot_checked.py")

        def run(*flags: str) -> None:
            subprocess.run(["python3", checked, args.engine, "--headless", "--path",
                            str(host), *flags], check=True, timeout=180)

        run("--editor")  # Real plugin activation in a host with no baseline Autoloads.
        run("--quit-after", "120")  # Six services and component imports without dev-repository dependencies.
        run("--editor")  # Persisted ownership across restart + adopt/replace cleanup.
        project = (host / "project.godot").read_text()
        for token in ('config/name="Existing host project"',
                      'run/main_scene="res://host_main.tscn"',
                      'keep="existing project data"',
                      'renderer/rendering_method="gl_compatibility"',
                      'buses/default_bus_layout="res://host_buses.tres"'):
            assert token in project, f"Host configuration changed: {token}"
        assert 'manage_project_preferences' not in project
        print("Nucleus packaged addon integration: PASS")


if __name__ == "__main__":
    main()
