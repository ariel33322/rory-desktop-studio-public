"""Wiring contracts for native windows unavailable to the offscreen harness."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NativeRouteTests(unittest.TestCase):
    def test_wallpaper_conflicts_use_a_prompt_not_editor_navigation(self):
        shell = (ROOT / "shell.qml").read_text()
        self.assertIn("StudioWallpaperPrompt {", shell)
        self.assertNotRegex(shell, r"onAttentionRequired\s*:\s*studio\.open")
        prompt = (ROOT / "StudioWallpaperPrompt.qml").read_text()
        self.assertIn("StudioAssociationNotice {", prompt)
        self.assertNotRegex(prompt, r"studio\.(?:open|home)\(")

    def test_all_workspaces_remain_reachable_from_native_editors(self):
        editor = (ROOT / "VisualizerEditor.qml").read_text()
        for component in ["StudioProfileBar", "AudioLayersPanel", "StudioAudioPanel", "StudioWallpaperWorkspace"]:
            self.assertRegex(editor, rf"\b{component}\s*\{{")
        launcher = (ROOT / "StudioLauncher.qml").read_text()
        self.assertIn("StudioWallpaperWorkspace {", launcher)
        self.assertIn('studio.page===\"associations\"', launcher)
        for component in ["ClockBackgroundPanel", "StudioProfileBar"]:
            self.assertIn(component + " {", (ROOT / "ClockEditor.qml").read_text())

    def test_clock_widget_lifetime_depends_only_on_outputs(self):
        shell = (ROOT / "shell.qml").read_text()
        self.assertEqual(len(re.findall(r"\bClockWidget\s*\{", shell)), 1)
        variants = re.search(r"Variants\s*\{[^{}]*\bClockWidget\s*\{", shell)
        self.assertIsNotNone(variants)
        self.assertIn("model: Quickshell.screens", variants.group())
        for name in ["ClockProfileManager.qml", "StudioAssociations.qml", "StudioProfileBar.qml"]:
            self.assertNotIn("ClockWidget", (ROOT / name).read_text())

    def test_studio_button_and_dropdown_are_the_editor_routes(self):
        bar = (ROOT / "RoryBar.qml").read_text()
        self.assertIn('text: "Studio"', bar)
        for name in ["ClockEditor.qml", "VisualizerEditor.qml", "StudioLauncher.qml"]:
            self.assertIn("StudioNavigation {", (ROOT / name).read_text())
        for name in ["VisualizerEditor.qml", "WallpaperPanel.qml"]:
            self.assertNotRegex((ROOT / name).read_text(), r'text:\s*"Editar (?:reloj|visualizador)"')

    def test_gallery_does_not_navigate_when_applying(self):
        source = (ROOT / "WallpaperPanel.qml").read_text()
        choose = source.split("function choose(url) {", 1)[1].split("function currentName()", 1)[0]
        self.assertIn("requestWallpaper(normalized)", choose)
        self.assertNotRegex(choose, r"studioController\.|editorOpen\s*=")
        associations = (ROOT / "StudioAssociationsPanel.qml").read_text()
        self.assertNotIn("requestWallpaper(", associations, "Association editing must not apply wallpaper")


if __name__ == "__main__":
    unittest.main()
