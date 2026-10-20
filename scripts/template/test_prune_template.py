#!/usr/bin/env python3
"""Targeted source-only tests for conservative template pruning."""
import tempfile
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prune_template import evaluate


class PruningTests(unittest.TestCase):
    def test_dimensions_and_references(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "project.godot").write_text("[application]\n", encoding="utf-8")
            (root / "modules" / "characters").mkdir(parents=True)
            (root / "modules" / "characters" / "visual_3d.gd").write_text(
                "extends Node3D\n", encoding="utf-8"
            )
            (root / "modules" / "characters" / "visual_2d.gd").write_text(
                "extends Node2D\n", encoding="utf-8"
            )
            report = evaluate(root, "3d")
            self.assertIn("modules/characters/visual_3d.gd", report["delete"])
            self.assertNotIn("modules/characters/visual_2d.gd", report["delete"])
            (root / "project.godot").write_text(
                'main_scene="res://modules/characters/visual_3d.gd"\n',
                encoding="utf-8"
            )
            report = evaluate(root, "3d")
            self.assertFalse(report["delete"])
            self.assertIn("modules/characters/visual_3d.gd", report["blocked"])

    def test_addons_are_separate(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "project.godot").touch()
            addon = root / "addons" / "example"
            addon.mkdir(parents=True)
            (addon / "plugin.cfg").write_text("[plugin]\n", encoding="utf-8")
            report = evaluate(root, "addons")
            self.assertEqual(report["delete"], ["addons/example/plugin.cfg"])


if __name__ == "__main__":
    unittest.main()
