#!/usr/bin/env python3
"""Exercise physical 2D/3D pruning, restoration and verified updates in real Godot."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('engine')
    parser.add_argument('archive', type=Path)
    args = parser.parse_args()
    engine = str(Path(args.engine).resolve())
    with tempfile.TemporaryDirectory(prefix='nucleus-management-') as folder:
        host = Path(folder)
        with zipfile.ZipFile(args.archive) as archive:
            archive.extractall(host)
        probe = host / 'management_probe.gd'
        probe.write_bytes((ROOT / 'tests/tools/addon_management_check.gd').read_bytes())
        autoload = (ROOT / 'project.godot').read_text().split('[autoload]\n', 1)[1].split('\n[', 1)[0]
        (host/'project.godot').write_text('''config_version=5
[application]
config/name="Nucleus management fixture"
[autoload]
''' + autoload + '''
[rendering]
renderer/rendering_method="gl_compatibility"
[editor_plugins]
enabled=PackedStringArray("res://addons/nucleus/plugin.cfg")
''')
        (host/'host_owned.txt').write_text('keep me')
        incoming = host/'incoming'
        incoming.mkdir()
        (incoming/'.gdignore').write_text('')
        source = host/'addons/nucleus'
        manifest = json.loads((source/'addon_manifest.json').read_text())
        files = {p: (source/p).read_bytes() for p in manifest['files']}
        files['VERSION'] = b'0.39.1-test.1\n'
        files['plugin.cfg'] = files['plugin.cfg'].replace(
            manifest['version'].encode(), b'0.39.1-test.1')
        manifest['version'] = '0.39.1-test.1'
        for name, data in files.items():
            manifest['files'][name]['size'] = len(data)
            manifest['files'][name]['sha256'] = hashlib.sha256(data).hexdigest()
        manifest_bytes = (json.dumps(manifest, indent=2)+'\n').encode()
        files['addon_manifest.json'] = manifest_bytes
        (host/'incoming_manifest.json').write_bytes(manifest_bytes)
        prefix = 'Nucleus-' + '1'*40 + '/addons/nucleus/'

        def write_archive(name: str, variant: str = '') -> None:
            with zipfile.ZipFile(host/name, 'w', zipfile.ZIP_DEFLATED) as archive:
                for path, data in files.items():
                    if variant == 'missing' and path == 'plugin.gd':
                        continue
                    if variant == 'corrupt' and path == 'plugin.gd':
                        data = b'!' + data[1:]
                    archive.writestr(prefix + path, data)
                if variant == 'traversal':
                    archive.writestr('../escape.gd', 'extends Node\n')

        write_archive('incoming.zip')
        for variant in ('traversal', 'corrupt', 'missing'):
            write_archive(variant+'.zip', variant)
        for variant in ('symlink', 'duplicate'):
            shutil.copy2(host/'incoming.zip', host/(variant+'.zip'))
            with zipfile.ZipFile(host/(variant+'.zip'), 'a') as archive:
                if variant == 'symlink':
                    entry = zipfile.ZipInfo(prefix+'linked.gd')
                    entry.create_system = 3
                    entry.external_attr = (0o120777 << 16)
                    archive.writestr(entry, '../../escape')
                else:
                    archive.writestr(prefix+'PLUGIN.GD', files['plugin.gd'])
        shutil.copy2(host/'incoming.zip', host/'oversized.zip')
        data = bytearray((host/'oversized.zip').read_bytes())
        central = data.index(b'PK\x01\x02')
        struct.pack_into('<I', data, central+24, 9*1024*1024)
        (host/'oversized.zip').write_bytes(data)
        checked = str(ROOT/'scripts/ci/run_godot_checked.py')

        def run(*flags: str) -> None:
            subprocess.run(['python3', checked, engine, '--headless', '--path', str(host),
                            *flags], check=True, timeout=240)

        run('--import')
        run('--script', 'res://management_probe.gd', '--', 'profiles')
        run('--script', 'res://management_probe.gd', '--', 'updates')
        # Physically prune each dimension again, then clean-import and load every
        # retained script/resource with no stale Godot class or UID cache.
        script = probe.read_text()
        for profile in ('2d', '3d'):
            probe.write_text(script.replace('elif phase == "updates":',
                'elif phase == "prune":\n\t\t_check(_manager.apply_profile("'+profile+
                '").error.is_empty(), "Profile applies.")\n\telif phase == "updates":'))
            run('--script', 'res://management_probe.gd', '--', 'prune')
            shutil.rmtree(host/'.godot', ignore_errors=True)
            run('--import')
            loader = host/'load_retained.gd'
            loader.write_text('''extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://addons/nucleus/addon_manifest.json"))
	for path: String in data.profiles["'''+profile+'''"]:
		if path.get_extension() in ["gd", "tres", "tscn", "gdshader"]:
			assert(load("res://addons/nucleus/" + path) != null, path)
	print("Retained '''+profile+''' resources load: PASS")
	quit()
''')
            run('--script', 'res://load_retained.gd')
            loader.unlink()
            run('--script', 'res://management_probe.gd', '--', 'full')
        assert (host/'host_owned.txt').read_text() == 'keep me'
        print('Nucleus dimensional profiles and staged updates: PASS')


if __name__ == '__main__':
    main()
