import fcntl
import importlib.util
import json
import multiprocessing
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "crimson-control.py"
spec = importlib.util.spec_from_file_location("crimson_control", SCRIPT)
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)


class FlashTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        env = patch.dict(os.environ, {"XDG_RUNTIME_DIR": str(self.root)})
        env.start()
        self.addCleanup(env.stop)

    def wait_until(self, condition):
        deadline = time.monotonic() + 4
        while time.monotonic() < deadline:
            if condition():
                return
            time.sleep(.015)
        self.fail("Timed out waiting for restoration")

    def test_guard_restores_backlight_when_lease_is_closed(self):
        fake = self.root / "panel"
        fake.mkdir()
        (fake / "brightness").write_text("24")
        (fake / "max_brightness").write_text("100")
        reader, writer = os.pipe()
        self.addCleanup(os.close, reader)

        def guard():
            os.close(writer)
            control.flash_guard("eDP-1", reader)

        with patch.object(control, "backlight", return_value=fake):
            guardian = multiprocessing.get_context("fork").Process(target=guard)
            guardian.start()
            try:
                self.wait_until(lambda: (fake / "brightness").read_text() == "100")
                self.assertEqual(json.loads((control.runtime() / "flash.json").read_text())["value"], 24)
                with self.assertRaises(BlockingIOError):
                    with control.locked("flash.lock"):
                        pass
            finally:
                os.close(writer)
                guardian.join(5)
                if guardian.is_alive():
                    guardian.terminate()
                    guardian.join()
            self.assertEqual(guardian.exitcode, 0)
            self.assertEqual((fake / "brightness").read_text(), "24")
            self.assertFalse((control.runtime() / "flash.json").exists())

    def test_guard_releases_lock_when_gui_client_is_killed(self):
        # DP never maps to an internal backlight. No real hardware is written.
        client = subprocess.Popen([sys.executable, SCRIPT, "flash", "DP-999"],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        with client:
            try:
                self.assertTrue(select.select([client.stdout], [], [], 5)[0])
                self.assertEqual(client.stdout.readline().strip(), "READY")
            finally:
                client.kill()
                client.wait(timeout=5)

        def unlocked():
            try:
                with control.locked("flash.lock"):
                    return True
            except BlockingIOError:
                return False

        self.wait_until(unlocked)

    def test_brightnessctl_session_is_confirmed_before_writing(self):
        panel = self.root / "intel_backlight"
        panel.mkdir()
        (panel / "brightness").write_text("90")
        (panel / "max_brightness").write_text("150")
        with patch.object(control, "backlight", return_value=panel), \
             patch.object(control, "write_methods", return_value=iter(["brightnessctl"])), \
             patch.object(control, "command", side_effect=lambda *args: (panel / "brightness").write_text(args[-1])) as command:
            self.assertEqual(control.light_status("eDP-1", check=True), dict(level=.6, method="brightnessctl", reason=""))
            self.assertEqual(command.call_args.args[-1], "90")
            control.write_level(panel, 75, "brightnessctl")
            self.assertEqual(control.light_status("eDP-1")["level"], .5)

    def test_denied_backlight_remains_readable_without_claiming_a_writer(self):
        panel = self.root / "intel_backlight"
        panel.mkdir()
        (panel / "brightness").write_text("90")
        (panel / "max_brightness").write_text("150")
        with patch.object(control, "backlight", return_value=panel), \
             patch.object(control, "write_methods", return_value=iter(["brightnessctl", "logind"])), \
             patch.object(control, "command", side_effect=RuntimeError("Bus no disponible")):
            status = control.light_status("eDP-1", check=True)
            self.assertEqual(status["level"], .6)
            self.assertEqual(status["method"], "")
            self.assertIn("Bus no disponible", status["reason"])

    def test_recording_status_uses_existing_lock(self):
        directory = self.root / "hypr-screen-record"
        directory.mkdir()
        lock = directory / "lock"
        self.assertEqual(control.recording_active(), "idle")
        with lock.open("a") as handle:
            fcntl.flock(handle, fcntl.LOCK_EX)
            self.assertEqual(control.recording_active(), "starting")
        self.assertEqual(control.recording_active(), "idle")


if __name__ == "__main__":
    unittest.main()
