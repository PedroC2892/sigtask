#!/usr/bin/env python3
"""Self-check for kde/patch_contextmenu.py against the installed Plasma task manager.

Run: python3 tests/test_patch.py
"""
import glob
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "kde"))
from patch_contextmenu import MARKER, patch  # noqa: E402

candidates = glob.glob("/usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/ui/ContextMenu.qml")
if not candidates:
    print("skip: Plasma task manager not installed")
    sys.exit(0)

original = open(candidates[0], encoding="utf-8").read()
patched = patch(original)

assert MARKER in patched
assert patched.count(MARKER) == 1
assert "import org.kde.plasma.plasma5support as Plasma5Support" in patched
assert patch(patched) == patched, "not idempotent"
assert patched.count("{") == patched.count("}"), "unbalanced braces"

try:
    patch("import QtQuick\n")
except SystemExit:
    pass
else:
    raise AssertionError("unknown layout must be rejected")

print("ok")
