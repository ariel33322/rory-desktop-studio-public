import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[1] / "scripts/studio-shortcut.py"
spec = importlib.util.spec_from_file_location("studio_shortcut", MODULE)
shortcut = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shortcut)
CONFIG = '''local mainMod = "SUPER"
hl.bind("ALT + F4", hl.dsp.window.close())
-- Studio
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd([[qs ipc -p "$HOME/rory-hyprland/shell.qml" call rory toggleAudioEditor]]))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("dolphin"))
'''


class ShortcutTests(unittest.TestCase):
    def test_status_and_only_studio_line_changes(self):
        self.assertEqual(shortcut.current_shortcut(CONFIG), "SUPER + P")
        result, label = shortcut.plan(CONFIG, "CTRL + ALT + S", [])
        self.assertEqual(label, "CTRL + ALT + S")
        self.assertEqual(shortcut.current_shortcut(result), label)
        self.assertEqual(result.replace('"CTRL + ALT + S"', 'mainMod .. " + P"'), CONFIG)

    def test_conflicts_and_existing_own_binding(self):
        with self.assertRaisesRegex(ValueError, "otra acción"):
            shortcut.plan(CONFIG, "SUPER + E", [{"modmask":64,"key":"E","dispatcher":"exec","arg":"dolphin"}])
        own = {"modmask":64,"key":"P","dispatcher":"exec","arg":"qs ipc call rory toggleAudioEditor"}
        shortcut.plan(CONFIG,"SUPER + P",[own])

    def test_reject_injection_and_ambiguous_bindings(self):
        for value in ['SUPER + P; reboot', 'SUPER + $(id)', 'SUPER + SUPER + P', 'P', 'SUPER + F99']:
            with self.assertRaises(ValueError):
                shortcut.shortcut(value)
        with self.assertRaises(ValueError):
            shortcut.locate(CONFIG + CONFIG)
        with self.assertRaises(ValueError):
            shortcut.locate('hl.bind("SUPER + E", hl.dsp.exec_cmd("dolphin"))')

    def test_apply_backups_and_preserves_other_shortcuts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "home"
            config = home / ".config/hypr/hyprland.lua"
            config.parent.mkdir(parents=True)
            config.write_text(CONFIG)
            fake_script = root / "project/scripts/studio-shortcut.py"
            fake_script.parent.mkdir(parents=True)
            responses = [subprocess.CompletedProcess([],0,"[]",""), subprocess.CompletedProcess([],0,"ok","")]
            output = io.StringIO()
            with patch.object(shortcut.Path,"home",return_value=home), patch.object(shortcut,"__file__",str(fake_script)), patch("sys.argv",["studio-shortcut.py","--shortcut","CTRL + ALT + S","--apply"]), patch.object(shortcut.subprocess,"run",side_effect=responses) as run, contextlib.redirect_stdout(output):
                shortcut.main()
            data=json.loads(output.getvalue())
            self.assertTrue(data["ok"])
            self.assertTrue(data["applied"])
            self.assertEqual(Path(data["backup"]).read_text(),CONFIG)
            expected,_=shortcut.plan(CONFIG,"CTRL + ALT + S",[])
            self.assertEqual(config.read_text(),expected)
            self.assertEqual(run.call_args_list[-1].args[0],["hyprctl","reload"])

    def test_conflict_does_not_write_or_reload(self):
        with tempfile.TemporaryDirectory() as directory:
            home=Path(directory)
            config=home/".config/hypr/hyprland.lua"
            config.parent.mkdir(parents=True)
            config.write_text(CONFIG)
            binds=json.dumps([{"modmask":64,"key":"E","dispatcher":"exec","arg":"dolphin"}])
            with patch.object(shortcut.Path,"home",return_value=home), patch("sys.argv",["studio-shortcut.py","--shortcut","SUPER + E","--apply"]), patch.object(shortcut.subprocess,"run",return_value=subprocess.CompletedProcess([],0,binds,"")) as run, contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit):
                shortcut.main()
            self.assertEqual(config.read_text(),CONFIG)
            self.assertEqual(run.call_count,1)


if __name__ == "__main__":
    unittest.main()
