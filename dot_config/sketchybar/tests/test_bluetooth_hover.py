"""Exercise the deployed Bluetooth plugin with delayed I/O (SKETCHYBAR_CONFIG overrides its root)."""

import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


CONFIG = Path(os.environ.get("SKETCHYBAR_CONFIG", Path.home() / ".config/sketchybar"))
PLUGIN = CONFIG / "plugins/bluetooth.sh"


class BluetoothHoverTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.log = self.root / "commands"
        self.ready = self.root / "query-started"
        self.release = self.root / "release-query"
        self.stub("sketchybar", '''#!/usr/bin/env python3
import os, sys
with open(os.environ["HOVER_LOG"], "a") as log:
    log.write(" ".join(sys.argv[1:]) + "\\n")
''')
        self.stub("blueutil", '''#!/usr/bin/env python3
import os, pathlib, sys, time
pathlib.Path(os.environ["HOVER_READY"]).touch()
deadline = time.monotonic() + 5
while not pathlib.Path(os.environ["HOVER_RELEASE"]).exists():
    if time.monotonic() > deadline:
        sys.exit(1)
    time.sleep(0.01)
print("1" if "--power" in sys.argv else "[]")
''')
        self.env = dict(os.environ, CONFIG_DIR=str(CONFIG), NAME="bluetooth",
                        PATH=str(self.root) + os.pathsep + os.environ["PATH"],
                        BLUEUTIL=str(self.root / "blueutil"),
                        TMPDIR=str(self.root), HOVER_LOG=str(self.log),
                        HOVER_READY=str(self.ready), HOVER_RELEASE=str(self.release))

    def stub(self, name, text):
        path = self.root / name
        path.write_text(text)
        path.chmod(0o755)

    def run_event(self, sender):
        return subprocess.run(["bash", str(PLUGIN)], env=dict(self.env, SENDER=sender),
                              capture_output=True, text=True, timeout=5)

    def visibility(self):
        return [line for line in self.log.read_text().splitlines() if "popup.drawing=" in line]

    def test_exit_during_slow_enter_cannot_reopen_tooltip(self):
        entered = subprocess.Popen(["bash", str(PLUGIN)], env=dict(self.env, SENDER="mouse.entered"),
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 3
            while not self.ready.exists() and entered.poll() is None:
                self.assertLess(time.monotonic(), deadline, "Enter neither completed nor reached Bluetooth query")
                time.sleep(0.01)
            self.assertEqual(self.run_event("mouse.exited").returncode, 0)
            self.release.touch()
            _, errors = entered.communicate(timeout=5)
            self.assertEqual(entered.returncode, 0, errors)
            self.assertTrue(self.visibility()[-1].endswith("popup.drawing=off"), self.visibility())
        finally:
            self.release.touch()
            if entered.poll() is None:
                entered.kill()
            entered.communicate()

    def test_hover_does_not_wait_for_bluetooth_queries(self):
        self.release.touch()
        self.assertEqual(self.run_event("mouse.entered").returncode, 0)
        self.assertFalse(self.ready.exists(), "Hover must display cached tooltip without querying Bluetooth")
        self.assertTrue(self.visibility()[-1].endswith("popup.drawing=on"))

    def test_background_update_never_opens_tooltip(self):
        self.release.touch()
        self.run_event("routine")
        self.assertTrue(self.ready.exists())
        self.assertEqual(self.visibility(), [])


if __name__ == "__main__":
    unittest.main()
