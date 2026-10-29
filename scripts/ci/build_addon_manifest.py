#!/usr/bin/env python3
"""Build the addon inventory and dependency-closed dimensional profiles."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / 'addons/nucleus'
OUTPUT = ADDON / 'addon_manifest.json'
TEXT = {'.gd', '.tscn', '.tres', '.gdshader', '.gdshaderinc', '.cfg', '.json', '.py'}
THREE_D_TREES = ('modules/terrain/', 'components/world/buoyancy/',
                 'components/world/ocean/', 'components/world/vegetation/')


def build() -> dict:
    paths = sorted(p for p in ADDON.rglob('*') if p.is_file() and p != OUTPUT
                   and '__pycache__' not in p.parts and p.suffix not in {'.import', '.pyc'})
    texts = {p.relative_to(ADDON).as_posix(): p.read_text(encoding='utf-8')
             for p in paths if p.suffix in TEXT}
    classes = {}
    for name, text in texts.items():
        match = re.search(r'(?m)^class_name\s+(Nucleus\w+)', text)
        if match:
            classes[match[1]] = name
    files = {}
    for p in paths:
        name = p.relative_to(ADDON).as_posix()
        text = texts.get(name, '')
        dimension = 'shared'
        if not name.startswith(('core/', 'editor/')):
            header = re.search(r'(?m)^class_name\s+(\w+)', text)
            identity = name + ' ' + (header[1] if header else '')
            if re.search(r'(?:_3d\b|3D\b)', identity) or name.startswith(THREE_D_TREES):
                dimension = '3d'
            elif re.search(r'(?:_2d\b|2D\b)', identity):
                dimension = '2d'
            elif re.search(r'(?m)^extends\s+\w+3D\b|shader_type\s+spatial', text):
                dimension = '3d'
            elif re.search(r'(?m)^extends\s+\w+2D\b', text):
                dimension = '2d'
        deps = {classes[s] for s in re.findall(r'\bNucleus\w+\b', text) if s in classes}
        deps |= set(re.findall(r'res://addons/nucleus/([^\s"\')]+)', text))
        deps.discard(name)
        deps = {d for d in deps if (ADDON / d).is_file() and d != 'addon_manifest.json'}
        if (ADDON / (name + '.uid')).is_file():
            deps.add(name + '.uid')
        if name.endswith('.uid') and name[:-4] in texts:
            deps.add(name[:-4])
        files[name] = dict(sha256=hashlib.sha256(p.read_bytes()).hexdigest(), size=p.stat().st_size,
                           dimension=dimension, dependencies=sorted(deps))
    for name, entry in files.items():
        if name.endswith('.uid') and name[:-4] in files:
            entry['dimension'] = files[name[:-4]]['dimension']
    profiles = {'full': sorted(files)}
    for profile, excluded in [('2d', '3d'), ('3d', '2d')]:
        selected = {n for n, e in files.items() if e['dimension'] != excluded}
        while True:
            remove = {n for n in selected if not set(files[n]['dependencies']) <= selected}
            if not remove:
                break
            selected -= remove
        mandatory = {n for n in files if n.startswith(('core/', 'editor/')) or n.startswith('plugin.')}
        if not mandatory <= selected:
            raise ValueError(f'{profile} loses core/editor dependencies: {sorted(mandatory-selected)}')
        profiles[profile] = sorted(selected)
    return dict(schema=1, version=(ADDON/'VERSION').read_text().strip(), godot='4.7',
                repository='Dragonboon/Nucleus', files=files, profiles=profiles)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = build()
    text = json.dumps(data, indent=2, ensure_ascii=False) + '\n'
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text() != text:
            raise SystemExit('Stale addon_manifest.json: run scripts/ci/build_addon_manifest.py')
    else:
        OUTPUT.write_text(text)
    print('Nucleus addon manifest:', {k: len(v) for k, v in data['profiles'].items()})


if __name__ == '__main__':
    main()
