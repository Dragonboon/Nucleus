import contextlib
import io
import sys
import unittest
from run_godot_checked import run


class CheckedGodotTests(unittest.TestCase):
    def execute(self, source):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return run([sys.executable, "-c", source])

    def test_script_error_with_successful_exit_fails(self):
        self.assertEqual(self.execute("print('SCRIPT ERROR: fixture')"), 1)

    def test_shader_error_with_successful_exit_fails(self):
        self.assertEqual(self.execute("print('SHADER ERROR: fixture')"), 1)

    def test_engine_failure_is_preserved(self):
        self.assertEqual(self.execute("raise SystemExit(7)"), 7)

    def test_success_and_expected_diagnostics_pass(self):
        self.assertEqual(self.execute("print('ERROR: expected negative fixture')"), 0)
