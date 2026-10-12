#!/usr/bin/env python3
"""Run Godot and fail on script/compiler errors even when its exit code is zero.

Usage: python scripts/ci/run_godot_checked.py <godot> <arguments...>
Ordinary engine ERROR lines remain governed by the test's explicit assertions:
some negative fixtures deliberately emit diagnostics.
"""
import subprocess
import sys

FATAL_MARKERS = ("SCRIPT ERROR:", "Parse Error:", "Compile Error:", "SHADER ERROR:")


def run(command):
    failed = False
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True, errors="replace", bufsize=1) as process:
        for line in process.stdout:
            print(line, end="", flush=True)
            failed |= any(marker in line for marker in FATAL_MARKERS)
        code = process.wait()
    if failed:
        print("Godot validation rejected script/compiler errors.", file=sys.stderr)
    return code if code else int(failed)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("Expected Godot executable and arguments.")
    sys.exit(run(sys.argv[1:]))
