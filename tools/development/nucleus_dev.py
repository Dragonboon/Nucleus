#!/usr/bin/env python3
"""Offline discovery and development checks. No addon runtime dependency or model API."""
import argparse
import json
import math
from pathlib import Path
import re
import statistics
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT = 'docs/api_surface.json'


def read_json(root, path):
    return json.loads((root / path).read_text())


def declaration(lines, start):
    """Bounded lexical declaration, not a GDScript type checker or inherited API."""
    parts = []
    depth = 0
    for line in lines[start:]:
        # Tokenize quoted strings before comments/delimiters; do not count their punctuation.
        tokens = re.findall(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*|[^"\'#]+', line)
        clean = ''.join(t for t in tokens if not t.startswith('#'))
        structural = ''.join(t for t in tokens if not t.startswith(('"', "'", '#')))
        parts.append(clean.strip())
        depth += sum(structural.count(c) for c in '([') - sum(structural.count(c) for c in ')]')
        if depth <= 0:
            break
    combined = ' '.join(parts)
    tokens = re.findall(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|[^"\']+', combined)
    return ''.join(t if t.startswith(('"', "'")) else re.sub(r'\s+', ' ', t)
                   for t in tokens).rstrip(':').strip()


def surface(root, revision=None):
    result = {}
    if revision:
        revision = subprocess.check_output(['git', 'rev-parse', '--verify',
            '--end-of-options', revision + '^{commit}'], cwd=root, text=True).strip()
        paths = [root / p for p in subprocess.check_output(
            ['git', 'ls-tree', '-r', '--name-only', revision, 'addons/nucleus'],
            cwd=root, text=True).splitlines() if p.endswith('.gd')]
    else:
        paths = sorted((root / 'addons/nucleus').rglob('*.gd'))
    for path in paths:
        text = subprocess.check_output(['git', 'show', f'{revision}:{path.relative_to(root).as_posix()}'],
            cwd=root, text=True) if revision else path.read_text()
        name = re.search(r'(?m)^class_name\s+(Nucleus\w+)', text)
        if not name:
            continue
        if name[1] in result:
            raise ValueError('Duplicate public class: ' + name[1])
        members = {}
        lines = text.splitlines()
        export_start = None
        for i, line in enumerate(lines):
            if re.match(r'@export(?:\b|_)', line) and not line.startswith(
                    ('@export_group', '@export_subgroup', '@export_category')):
                export_start = i
            if line.startswith((' ', '\t')):
                continue  # Inner classes and method bodies do not declare the outer API.
            match = re.match(r'(?:static\s+)?func\s+(\w+)', line)
            kind = 'method'
            if not match:
                match = re.match(r'signal\s+(\w+)', line)
                kind = 'signal'
            if not match:
                # @export decorators may be on this line or immediately above it.
                match = re.search(r'\bvar\s+(\w+)', line) if (
                    line.startswith('@export') or (line.startswith('var ') and export_start is not None)) else None
                kind = 'export'
            if match and not match[1].startswith('_'):
                signature = declaration(lines, i)
                if kind == 'export' and export_start is not None and export_start != i:
                    signature = declaration(lines, export_start) + ' ' + signature
                export_start = None
                # An inline decorator may contain a quoted var name: use the actual var token.
                if kind == 'export':
                    actual = re.search(r'\bvar\s+(\w+)', signature)
                    if not actual:
                        continue
                    member = actual[1]
                else:
                    member = match[1]
                members[f'{kind}:{member}'] = signature
        result[name[1]] = {'path': path.relative_to(root).as_posix(), 'members': members}
    return {'schema': 1, 'scope': 'Declared public methods, signals and exports; lexical, not inherited API',
            'classes': result}


def references(root, classes):
    found = {}
    for folder in ('tests/headless', 'tests/smoke', 'examples'):
        for path in sorted((root / folder).rglob('*.gd')):
            names = set(re.findall(r'\bNucleus\w+\b', path.read_text())) & classes
            found[path.relative_to(root).as_posix()] = names
    return found


def context(root, query):
    api = surface(root)['classes']
    coverage = read_json(root, 'docs/documentation_coverage.json')['coverage']
    cases = read_json(root, 'docs/use_case_registry.json')['cases']
    inventory = read_json(root, 'addons/nucleus/addon_manifest.json')['files']
    refs = references(root, set(api))
    terms = query.casefold().split()
    rows = []
    for owner, guides in coverage.items():
        names = [n for n, data in api.items() if data['path'].startswith(owner + '/')]
        routes = [c for c in cases if c['guide'] in guides]
        haystack = json.dumps([owner, guides, names, routes]).casefold()
        score = sum(t in haystack for t in terms)
        if score:
            classes = {n: api[n] for n in names}
            paths = {v['path'] for v in classes.values()}
            dependencies = sorted({d for p in paths for d in inventory.get(
                p.removeprefix('addons/nucleus/'), {}).get('dependencies', [])})
            rows.append((score, {'owner_path': owner, 'guides': guides, 'routes': routes,
                'classes': classes, 'dependencies': dependencies,
                'referencing_tests': [p for p, ns in refs.items() if ns & set(names)
                                      and p.startswith('tests/')],
                'referencing_examples': [p for p, ns in refs.items() if ns & set(names)
                                         and p.startswith('examples/')]}))
    rows.sort(key=lambda r: (-r[0], r[1]['owner_path']))
    return {'query': query, 'evidence': 'References are discovery hints, not proof of behavior or ownership.',
            'contract': 'docs/guides/agent_development_contract.md',
            'capabilities': [r[1] for r in rows[:3]]}


def changed_paths(root, base):
    commands = [['git', 'diff', '--name-only', base], ['git', 'ls-files', '--others', '--exclude-standard']]
    return sorted({p for c in commands for p in subprocess.check_output(c, cwd=root, text=True).splitlines()})


def plan(root, paths):
    """Reverse dependency closure over the existing addon inventory; fail open to full tests."""
    api = surface(root)['classes']
    refs = references(root, set(api))
    files = read_json(root, 'addons/nucleus/addon_manifest.json')['files']
    affected = {p.removeprefix('addons/nucleus/') for p in paths if p.startswith('addons/nucleus/')}
    full = any(p in {'project.godot', 'VERSION'} or p.startswith(('tools/development/', 'scripts/',
               '.github/', 'tests/headless/test_', 'addons/nucleus/core/', 'addons/nucleus/editor/'))
               for p in paths)
    unknown = any(not (p.endswith('.md') or (p.startswith('docs/') and p.endswith('.json')))
                  and not p.startswith(('addons/nucleus/', 'tests/', 'examples/')) for p in paths)
    # Deletions/unindexed code and scene fixtures need conservative full coverage.
    full |= unknown or any(p not in files for p in affected) or any(
        p.startswith('tests/fixtures/') for p in paths)
    while True:
        dependents = {p for p, data in files.items() if set(data['dependencies']) & affected}
        extra = dependents - affected
        if not extra:
            break
        affected |= extra
    names = {n for n, data in api.items() if data['path'].removeprefix('addons/nucleus/') in affected}
    suites = sorted(p for p, ns in refs.items() if p.endswith('_test.gd') and (
        ns & names or p in paths))
    smokes = sorted(p.removesuffix('.gd') + '.tscn' for p, ns in refs.items() if
        p.startswith('tests/smoke/') and (ns & names or p in paths or p.removesuffix('.gd')+'.tscn' in paths)
        and (root / (p.removesuffix('.gd')+'.tscn')).exists())
    runtime = bool(affected) or any(p.startswith(('tests/', 'examples/')) for p in paths)
    if runtime and not suites:
        full = True
    if full:
        runtime = True
        suites = []  # Empty filter means the complete native manifest.
        smokes = sorted(str(p.relative_to(root)) for p in (root/'tests/smoke').glob('*.tscn'))
    commands = [[sys.executable, f'scripts/ci/{name}'] for name in (
        'static_checks.py', 'documentation_audit.py', 'productization_audit.py', 'use_case_audit.py')]
    commands += [[sys.executable, 'scripts/ci/build_addon_manifest.py', '--check'],
                 [sys.executable, 'scripts/ci/build_use_case_catalog.py', '--check'],
                 [sys.executable, 'tools/development/nucleus_dev.py', 'api', '--check']]
    return {'changed': paths, 'full_fallback': full, 'runtime': runtime, 'suites': suites,
            'smokes': smokes, 'commands': commands,
            'limits': 'Selection accelerates local feedback. Full CI, packaging and device gates remain required.'}


def compare(before, after):
    changes = []
    old, new = before['classes'], after['classes']
    for name in sorted(old.keys() | new.keys()):
        if name not in new:
            changes.append({'class': name, 'kind': 'removed_class'})
        elif name not in old:
            changes.append({'class': name, 'kind': 'added_class'})
        else:
            if old[name]['path'] != new[name]['path']:
                changes.append({'class': name, 'kind': 'moved_class'})
            a, b = old[name]['members'], new[name]['members']
            for member in sorted(a.keys() | b.keys()):
                if a.get(member) != b.get(member):
                    changes.append({'class': name, 'member': member, 'kind':
                                    'added_member' if member not in a else
                                    'removed_member' if member not in b else 'changed_member',
                                    'before': a.get(member), 'after': b.get(member)})
    return changes


def evaluate(data):
    required = {'minutes', 'corrections', 'regressions', 'invented_apis', 'scope_violations', 'first_pass'}
    records = data['records']
    if not records:
        raise ValueError('At least one paired measured task is required.')
    ids = set()
    for record in records:
        if not record.get('task') or record['task'] in ids:
            raise ValueError('Unique nonempty task IDs required.')
        ids.add(record['task'])
        for side in ('baseline', 'candidate'):
            sample = record[side]
            if set(sample) != required or type(sample['first_pass']) is not bool:
                raise ValueError('Incomplete measured sample.')
            for key in required - {'first_pass'}:
                value = sample[key]
                if type(value) not in (int, float) or not math.isfinite(value) or value < 0:
                    raise ValueError('Measurements must be finite and nonnegative.')
            if any(type(sample[k]) is not int for k in required - {'minutes', 'first_pass'}):
                raise ValueError('Event counts must be integers.')
            if sample['minutes'] <= 0:
                raise ValueError('Measured durations must be positive.')
    report = {'tasks': len(records), 'note': 'Observed paired samples only; no quality score or causal claim.'}
    for side in ('baseline', 'candidate'):
        samples = [r[side] for r in records]
        report[side] = {'median_minutes': statistics.median(s['minutes'] for s in samples),
                       'first_pass_rate': sum(s['first_pass'] for s in samples)/len(samples),
                       **{k: sum(s[k] for s in samples) for k in required - {'minutes', 'first_pass'}}}
    report['median_paired_speed_ratio'] = statistics.median(
        r['baseline']['minutes']/r['candidate']['minutes'] for r in records)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='mode', required=True)
    sub.add_parser('context').add_argument('query')
    api = sub.add_parser('api')
    api.add_argument('--check', action='store_true')
    diff = sub.add_parser('api-diff')
    diff.add_argument('--base', required=True)
    diff.add_argument('--decision', help='Tracked Markdown explaining compatibility/version/migration and consumer evidence')
    change = sub.add_parser('plan')
    change.add_argument('--base', default='HEAD')
    change.add_argument('--run', action='store_true')
    change.add_argument('--engine', default='godot')
    sub.add_parser('evaluate').add_argument('measurements', type=Path)
    args = parser.parse_args()
    if args.mode == 'context':
        output = context(ROOT, args.query)
    elif args.mode == 'api':
        generated = json.dumps(surface(ROOT), ensure_ascii=False, indent=2) + '\n'
        path = ROOT / SNAPSHOT
        if args.check:
            if not path.exists() or path.read_text() != generated:
                raise SystemExit('Stale public API inventory; regenerate with nucleus_dev.py api.')
        else:
            path.write_text(generated)
        output = {'api': SNAPSHOT, 'check': args.check}
    elif args.mode == 'api-diff':
        output = {'changes': compare(surface(ROOT, args.base), surface(ROOT))}
        risky = any(c['kind'] not in ('added_member', 'added_class') for c in output['changes'])
        if risky:
            tracked = subprocess.check_output(['git', 'ls-files'], cwd=ROOT, text=True).splitlines()
            if not args.decision or args.decision not in tracked or not args.decision.endswith('.md'):
                print(json.dumps(output, indent=2))
                raise SystemExit('Changed/removed API requires a tracked compatibility decision (--decision).')
            changed = subprocess.check_output(['git', 'diff', '--name-only', args.base],
                                              cwd=ROOT, text=True).splitlines()
            if args.decision not in changed:
                raise SystemExit('Compatibility decision must be updated in this change, not reused unchanged.')
            decision = (ROOT / args.decision).read_text()
            if any('## ' + title not in decision for title in
                   ('Compatibility', 'Version', 'Migration', 'Consumers')):
                raise SystemExit('Decision must cover Compatibility, Version, Migration and Consumers.')
            output['decision'] = args.decision
        output['note'] = 'Additions still require consumer/subclass review; lexical signatures are not semantic compatibility proof.'
    elif args.mode == 'evaluate':
        output = evaluate(json.loads(args.measurements.read_text()))
    else:
        output = plan(ROOT, changed_paths(ROOT, args.base))
        if args.run:
            for command in output['commands']:
                subprocess.run(command, cwd=ROOT, check=True, timeout=180)
            if output['runtime']:
                checked = [sys.executable, 'scripts/ci/run_godot_checked.py', args.engine,
                           '--headless', '--path', '.']
                subprocess.run([*checked, '--import'], cwd=ROOT, check=True, timeout=180)
                command = [*checked, 'res://tests/headless/test_runner.tscn']
                if output['suites']:
                    command += ['--', '--nucleus-suites=' + ','.join(Path(p).name for p in output['suites'])]
                subprocess.run(command, cwd=ROOT, check=True, timeout=300)
                for scene in output['smokes']:
                    subprocess.run([*checked, 'res://' + scene], cwd=ROOT, check=True, timeout=180)
    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
