"""Offline mutation tests for discovery, selection, contracts and measurement validation."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import subprocess
import sys

MODULE = Path(__file__).resolve().parents[2] / 'tools/development/nucleus_dev.py'
spec = importlib.util.spec_from_file_location('nucleus_dev', MODULE)
dev = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dev)


class DevelopmentTools(unittest.TestCase):
    def test_surface_ignores_bodies_and_tracks_multiline_exports(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            addon = root / 'addons/nucleus'
            addon.mkdir(parents=True)
            (addon/'sample.gd').write_text('''class_name NucleusSample
extends Node
signal completed(value: String)
@export_enum(
    "first", "second"
)
var choice: String = "first"
@export_group("Details")
var internal_value = 1
func execute(
    value: String = "# (not a comment)"
) -> Error:
    return OK
func _private() -> void:
    pass
class Inner:
    func other() -> void:
        pass
''')
            members = dev.surface(root)['classes']['NucleusSample']['members']
            self.assertIn('export:choice', members)
            self.assertIn('method:execute', members)
            self.assertIn('# (not a comment)', members['method:execute'])
            self.assertNotIn('export:internal_value', members)
            self.assertNotIn('method:_private', members)
            self.assertNotIn('method:other', members)

    def test_contract_addition_removal_signature_and_move(self):
        before = {'classes': {'NucleusA': {'path': 'a.gd', 'members': {'method:run': 'func run()'}}}}
        after = {'classes': {'NucleusA': {'path': 'b.gd', 'members': {'method:run': 'func run(x: int)',
                                                                  'signal:done': 'signal done'}}}}
        kinds = {c['kind'] for c in dev.compare(before, after)}
        self.assertEqual(kinds, {'moved_class', 'changed_member', 'added_member'})
        self.assertEqual(dev.compare(after, {'classes': {}})[0]['kind'], 'removed_class')

    def test_context_uses_existing_routes_and_real_source(self):
        output = dev.context(dev.ROOT, 'NucleusAdventureSession')
        self.assertTrue(output['capabilities'])
        self.assertTrue(any('NucleusAdventureSession' in c['classes'] for c in output['capabilities']))
        for capability in output['capabilities']:
            self.assertTrue((dev.ROOT/capability['owner_path']).is_dir())
            for path in capability['guides'] + capability['referencing_tests']:
                self.assertTrue((dev.ROOT/path).is_file())

    def test_selection_includes_reverse_dependencies_and_falls_back(self):
        selected = dev.plan(dev.ROOT, ['addons/nucleus/components/ui/interaction/nucleus_screen_hotspot.gd'])
        self.assertIn('tests/headless/image_screen_test.gd', selected['suites'])
        self.assertIn('tests/headless/adventure_session_test.gd', selected['suites'])
        self.assertIn('tests/smoke/point_click_smoke.tscn', selected['smokes'])
        for path in ('unknown.py', 'unknown.json', 'addons/nucleus/removed.gd', 'addons/nucleus/core/input/cursor.gd'):
            self.assertTrue(dev.plan(dev.ROOT, [path])['full_fallback'])
        self.assertFalse(dev.plan(dev.ROOT, ['AGENTS.md'])['runtime'])

    def test_failed_validation_stops_execution(self):
        with mock.patch.object(sys, 'argv', ['nucleus_dev', 'plan', '--run']), \
             mock.patch.object(dev, 'changed_paths', return_value=['AGENTS.md']), \
             mock.patch.object(dev.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'check')) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                dev.main()
            self.assertEqual(run.call_count, 1)

    def test_no_measurement_claim_without_real_paired_data(self):
        with self.assertRaises(ValueError):
            dev.evaluate({'records': []})
        sample = dict(minutes=12, corrections=2, regressions=0, invented_apis=0,
                      scope_violations=0, first_pass=False)
        candidate = dict(sample, minutes=6, corrections=0, first_pass=True)
        data = {'records': [{'task': 'task', 'baseline': sample, 'candidate': candidate}]}
        self.assertEqual(dev.evaluate(data)['median_paired_speed_ratio'], 2)
        for value in (float('nan'), -1, True):
            with self.assertRaises(ValueError):
                dev.evaluate({'records': [{'task': 'task', 'baseline': dict(sample, minutes=value),
                                           'candidate': candidate}]})


if __name__ == '__main__':
    unittest.main()
