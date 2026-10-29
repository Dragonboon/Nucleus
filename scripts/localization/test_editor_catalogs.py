"""Real-gettext regressions for the editor bridge and shared safe writer."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
BRIDGE = ROOT / "addons/nucleus/editor/localization/tools/editor_catalogs.py"


@unittest.skipUnless(all(shutil.which(x) for x in ("msginit", "msgmerge", "msgfmt", "msgcmp")),
                     "GNU gettext required")
class EditorCatalogTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.folder = Path(self.directory.name)
        self.po = self.folder / "es with spaces.po"
        shutil.copy2(ROOT / "addons/nucleus/core/localization/translations/es.po", self.po)
        self.pot = self.folder / "messages.pot"
        # A real gettext-generated template preserves native format/context metadata.
        subprocess.run(["msgattrib", "--clear-fuzzy", str(self.po), "-o", str(self.pot)], check=True)

    def bridge(self, command, *args):
        report = self.folder / "report.json"
        subprocess.run([sys.executable, str(BRIDGE), "--report", str(report), command, *map(str, args)],
                       check=True, capture_output=True)
        return json.loads(report.read_text())

    def test_status_counts_and_format_errors(self):
        result = self.bridge("status", "--template", self.pot, self.po)
        self.assertTrue(result["ok"])
        self.assertEqual(result["catalogs"][0]["translated"], 12)
        self.assertFalse(result["catalogs"][0]["needs_update"])
        self.po.write_text(self.po.read_text().replace("{device} está listo.", "Está listo."))
        result = self.bridge("status", self.po)
        self.assertFalse(result["ok"])
        self.assertIn(str(self.po), result["catalogs"][0]["diagnostics"])

    def test_update_preserves_bytes_and_refuses_existing_backup(self):
        before = self.po.read_bytes()
        self.pot.write_text(self.pot.read_text() + '\nmsgid "New message"\nmsgstr ""\n')
        self.assertTrue(self.bridge("status", "--template", self.pot, self.po)["catalogs"][0]["needs_update"])
        result = self.bridge("update", "--template", self.pot, "--output", self.po)
        self.assertTrue(result["ok"])
        self.assertEqual(Path(str(self.po) + ".bak").read_bytes(), before)
        after = self.po.read_bytes()
        self.assertFalse(self.bridge("update", "--template", self.pot, "--output", self.po)["ok"])
        self.assertEqual(self.po.read_bytes(), after)
        self.assertIn("Automático", self.po.read_text())

    def test_creation_never_overwrites_and_reports_missing_files(self):
        before = self.po.read_bytes()
        self.assertFalse(self.bridge("init", "--template", self.pot, "--output", self.po,
                                     "--locale", "es")["ok"])
        self.assertEqual(self.po.read_bytes(), before)
        fresh = self.folder / "fr.po"
        self.assertTrue(self.bridge("init", "--template", self.pot, "--output", fresh,
                                    "--locale", "fr")["ok"])
        self.assertTrue(fresh.is_file())
        self.assertFalse(self.bridge("status", self.folder / "missing.po")["ok"])
        self.assertFalse(self.bridge("status", "--template", self.folder / "missing.pot", self.po)["ok"])

    def test_missing_gettext_is_actionable(self):
        report = self.folder / "missing-tools.json"
        subprocess.run([sys.executable, str(BRIDGE), "--report", str(report), "doctor"],
                       env=dict(os.environ, PATH=""), check=True)
        result = json.loads(report.read_text())
        self.assertFalse(result["ok"])
        self.assertIn("GNU gettext", result["diagnostics"])

    def test_review_and_untranslated_are_distinct(self):
        with self.po.open("a") as file:
            file.write('\n#, fuzzy\nmsgid "Review me"\nmsgstr "Revísame"\n')
            file.write('\nmsgid "Pending"\nmsgstr ""\n')
        row = self.bridge("status", self.po)["catalogs"][0]
        self.assertEqual(row["fuzzy"], 1)
        self.assertEqual(row["untranslated"], 1)
        self.assertEqual(row["translated"], 12)


if __name__ == "__main__":
    unittest.main()
