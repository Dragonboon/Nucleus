#!/usr/bin/env python3
"""Regression tests for human-readable CLI output and unchanged audit outcomes."""

from __future__ import annotations

import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import audit_game_exports
import build_use_case_catalog
import documentation_audit
import productization_audit
import static_checks
import use_case_audit
from console_report import ConsoleReport


class ConsoleReportTests(unittest.TestCase):
    def run_cli(self, module, *args: str, ci: bool = False) -> tuple[int, str]:
        output = io.StringIO()
        env = {"CI": "1"} if ci else {"CI": ""}
        with patch.object(sys, "argv", [module.__file__, *args]), patch.dict(os.environ, env):
            with contextlib.redirect_stdout(output):
                result = module.main()
        return result, output.getvalue()

    def test_static_scopes_allow_game_classes_and_report_counts(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "addons/nucleus/core").mkdir(parents=True)
            (root / "game").mkdir()
            suite_dir = root / "tests/headless"
            suite_dir.mkdir(parents=True)
            (root / "addons/nucleus/core/example.gd").write_text("class_name NucleusExample\nextends Node\n", encoding="utf-8")
            (root / "game/player.gd").write_text("class_name IslandsPlayer\nextends Node\n", encoding="utf-8")
            (suite_dir / "test_case.gd").write_text(
                "extends Node\nfunc expect_true() -> void:\n\tpass\nfunc finish() -> Dictionary:\n\treturn {}\n", encoding="utf-8"
            )
            (suite_dir / "test_manifest.gd").write_text(
                'const SUITES = [preload("res://tests/headless/sample_test.gd")]\n', encoding="utf-8"
            )
            (suite_dir / "sample_test.gd").write_text(
                'extends "res://tests/headless/test_case.gd"\n'
                'func run() -> Dictionary:\n\texpect_true()\n\treturn finish()\n', encoding="utf-8"
            )
            result, message = self.run_cli(static_checks, "--root", str(root), "--color", "never")
            self.assertEqual(result, 0, message)
            self.assertIn("Files inspected", message)
            self.assertIn("game scripts exempt", message)
            self.assertIn("PASS", message)
            self.assertNotIn("\x1b[", message)

            (root / "addons/nucleus/core/example.gd").write_text("class_name MyCore\nextends Node\n", encoding="utf-8")
            result, message = self.run_cli(static_checks, "--root", str(root), "--color", "never")
            self.assertEqual(result, 1)
            self.assertIn("public class_name must use Nucleus prefix", message)
            self.assertIn("FAIL", message)

            (root / "addons/nucleus/core/example.gd").write_text("class_name NucleusExample\nextends Node\n", encoding="utf-8")
            (root / "game/player.gd").write_text(
                "class_name IslandsPlayer\nextends Node\nfunc _ready():\n\tInput.mouse_mode = Input.MOUSE_MODE_VISIBLE\n", encoding="utf-8"
            )
            result, message = self.run_cli(static_checks, "--root", str(root), "--color", "never")
            self.assertEqual(result, 1)
            self.assertIn("Nucleus-owned API bypass", message)

    def test_documentation_coverage_and_missing_mapping(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "addons/nucleus/core/input").mkdir(parents=True)
            (root / "docs").mkdir()
            (root / "docs/input.md").write_text("# Input\n", encoding="utf-8")
            manifest = root / "docs/documentation_coverage.json"
            manifest.write_text(json.dumps({"coverage": {"addons/nucleus/core/input": ["docs/input.md"]}}), encoding="utf-8")
            code, message = self.run_cli(documentation_audit, "--root", str(root))
            self.assertEqual(code, 0, message)
            self.assertIn("1/1 (100%)", message)
            (root / "addons/nucleus/core/save").mkdir()
            code, message = self.run_cli(documentation_audit, "--root", str(root))
            self.assertEqual(code, 1)
            self.assertIn("unmapped subsystem: addons/nucleus/core/save", message)
            self.assertIn("1/2 (50%)", message)

    def test_productization_checks_not_weakened(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for relative in productization_audit.REQUIRED_FILES:
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("placeholder\n", encoding="utf-8")
            (root / "VERSION").write_text("1.2.3\n", encoding="utf-8")
            (root / "LICENSE").write_text(
                "MIT License\nPermission is hereby granted, free of charge\n", encoding="utf-8"
            )
            (root / "README.md").write_text(
                "\n".join(productization_audit.README_TOKENS) + "\n", encoding="utf-8"
            )
            (root / "project.godot").write_text('features=PackedStringArray("4.7")\n', encoding="utf-8")
            (root / "docs/policies/godot_compatibility.md").write_text("4.7.2-stable\n", encoding="utf-8")
            code, message = self.run_cli(productization_audit, "--root", str(root))
            self.assertEqual(code, 0, message)
            self.assertIn("12/12 (100%)", message)
            (root / "README.md").write_text("# Missing routes\n", encoding="utf-8")
            code, message = self.run_cli(productization_audit, "--root", str(root))
            self.assertEqual(code, 1)
            self.assertIn("README.md: missing product contract link", message)

    def test_use_case_audit_with_catalog_read_only(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for relative in use_case_audit.REQUIRED_GUIDES:
                page = root / relative
                page.parent.mkdir(parents=True, exist_ok=True)
                page.write_text("# Guide\n", encoding="utf-8")
            cases = []
            for domain in sorted(use_case_audit.REQUIRED_DOMAINS):
                cases.append({"domain": domain, "need": f"Example {domain}",
                              "nucleus_role": "NucleusContract", "guide": use_case_audit.REQUIRED_GUIDES[0],
                              "game_owns": "Game policy"})
            registry = root / "docs/use_case_registry.json"
            registry.write_text(json.dumps({"schema_version": 1, "cases": cases}), encoding="utf-8")
            output = root / "docs/guides/use_case_catalog.md"
            output.write_text(build_use_case_catalog.render({"cases": cases}), encoding="utf-8")
            code, message = self.run_cli(use_case_audit, "--root", str(root))
            self.assertEqual(code, 0, message)
            self.assertIn("5/5 (100%)", message)
            code, message = self.run_cli(build_use_case_catalog, "--root", str(root), "--check")
            self.assertEqual(code, 0, message)
            content = output.read_bytes()
            output.write_text("outdated\n", encoding="utf-8")
            code, message = self.run_cli(build_use_case_catalog, "--root", str(root), "--check")
            self.assertEqual(code, 1)
            self.assertEqual(output.read_bytes(), b"outdated\n")
            self.assertIn("OUT OF DATE", message)
            code, message = self.run_cli(build_use_case_catalog, "--root", str(root))
            self.assertEqual(code, 0, message)
            self.assertEqual(output.read_bytes(), content)

    def test_json_output_is_pure_and_secrets_are_redacted(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            secret = "secret-must-not-appear-123"
            (root / "export_presets.cfg").write_text(
                '[preset.0]\nname="Windows"\nplatform="Windows Desktop"\n'
                f'script_encryption_key="{secret}"\n[preset.0.options]\n', encoding="utf-8"
            )
            buffer = io.StringIO()
            with contextlib.redirect_stdout(buffer):
                code = audit_game_exports.main(["--project", str(root), "--json", "--color", "always"])
            self.assertEqual(code, 1)
            output = buffer.getvalue()
            self.assertNotIn(secret, output)
            self.assertNotIn("\x1b[", output)
            document = json.loads(output)
            self.assertEqual(document["counts"]["error"], 1)
            self.assertEqual(document["findings"][0]["code"], "POSSIBLE_SECRET_IN_PRESET")

    def test_ci_is_concise_but_verbose_overrides(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            code, text = self.run_cli(documentation_audit, "--root", str(root), ci=True)
            self.assertEqual(code, 1)
            self.assertIn("Documentation coverage: FAIL", text)
            self.assertNotIn("Files inspected", text)
            code, text = self.run_cli(documentation_audit, "--root", str(root), "--verbose", ci=True)
            self.assertEqual(code, 1)
            self.assertIn("NUCLEUS", text)


if __name__ == "__main__":
    unittest.main()
