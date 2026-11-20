import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


installer = load("rory_installer", "install.py")
wallpaper = load("rory_wallpaper", "shortcut-wallpaper.py")


class DistributionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="rory-install-test-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)

    def cli(self, *args, response=""):
        return subprocess.run([sys.executable, str(ROOT / "install.py"), *args],
                              env=dict(os.environ, HOME=str(self.home)), input=response,
                              text=True, capture_output=True, timeout=30)

    def verify_cli(self, *args, response=""):
        result = self.cli(*args, response=response)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def test_clean_complete_cancel_update_repair_remove_restore(self):
        self.verify_cli("completa", response="n\n")
        self.assertFalse((self.home / "rory-hyprland").exists())
        self.verify_cli("completa", "--confirmar")
        rory = self.home / "rory-hyprland"
        self.assertTrue((rory / "RoryNotificationSource.qml").is_file())
        self.assertTrue((self.home / "crimson-noir/shell.qml").is_file())
        self.assertTrue((self.home / "Infinite-Desktop/bin/infinite_desktop_core.py").is_file())
        self.assertFalse((self.home / installer.MAIN).exists())
        preference = rory / ".studio-settings.ini"
        preference.write_text("[Personal]\nvalue=preservar\n")
        self.verify_cli("actualizar", "--confirmar")
        code = rory / "shell.qml"
        code.write_text("editable")
        self.assertNotEqual(self.cli("actualizar", "--confirmar").returncode, 0)
        self.verify_cli("reparar", "--confirmar")
        self.assertIn("ShellRoot", code.read_text())
        self.verify_cli("desinstalar", "--confirmar")
        self.assertFalse(code.exists())
        self.assertIn("preservar", preference.read_text())
        self.verify_cli("restaurar", "--confirmar")
        self.assertTrue(code.is_file())

    def test_conflicts_and_atomic_failure(self):
        with installer.Installation(self.home).lock:
            pass
        instance = installer.Installation(self.home)
        self.addCleanup(instance.lock.close)
        file = "existing"
        instance.write(file, (b"preservar", 0o600))
        original = instance.write
        def fail(name, payload):
            if name == "failure":
                raise OSError("fallo de prueba")
            return original(name, payload)
        with patch.object(instance, "write", side_effect=fail), self.assertRaises(OSError):
            instance.transact({file: (b"nuevo", 0o600), "failure": (b"x", 0o600)})
        self.assertEqual((self.home / file).read_bytes(), b"preservar")
        with patch.object(installer, "active_binds", return_value=[{"modmask": 64, "key": "P"}]):
            with self.assertRaises(ValueError):
                installer.lua_integration(["rory"], True, False, False)

    def test_integration_uses_backup_and_restores_main(self):
        instance = installer.Installation(self.home)
        self.addCleanup(instance.lock.close)
        original = (b"-- configuracion local\n", 0o600)
        instance.write(installer.MAIN, original)
        with patch.object(installer, "active_binds", return_value=[]):
            instance.transact(instance.plan(["rory"], (True, True)))
        self.assertIn(b"SUPER + P", instance.read(installer.MODULE)[0])
        self.assertIn(b"hyprland.start", instance.read(installer.MODULE)[0])
        self.assertTrue(instance.read(installer.MAIN)[0].startswith(original[0]))
        instance.old = {}
        instance.transact(instance.restoration())
        self.assertEqual(instance.read(installer.MAIN), original)
        self.assertIsNone(instance.read(installer.MODULE))

    def test_personalized_and_missing_dependency(self):
        self.verify_cli("personalizada", "--componentes", "base", "--confirmar")
        self.assertFalse((self.home / "rory-hyprland").exists())
        self.assertTrue((self.home / ".config/hypr/scripts/screenshot.py").is_file())
        with patch.object(installer.shutil, "which", return_value=None), self.assertRaises(ValueError):
            installer.preflight(["rory"], False)

    def test_wallpaper_only_uses_discovered_bindings(self):
        data = [{"key": "K", "modmask": 64, "dispatcher": "exec", "arg": "qs call rory toggleStudio"},
                {"key": "Q", "modmask": 64, "dispatcher": "exec", "arg": "unrelated"}]
        image = wallpaper.render(wallpaper.active_shortcuts(data))
        self.assertIn("Super + K", image)
        self.assertNotIn("Super + P", image)
        self.assertNotIn("Super + Q", image)


if __name__ == "__main__":
    unittest.main()
