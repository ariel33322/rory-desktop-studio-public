#!/usr/bin/env python3
"""Generate and optionally apply a black guide from Rory's active Hyprland binds."""
import argparse
import html
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

BIND_TYPES = (
    ("call rory toggleStudio", "Abrir o cerrar Rory Desktop Studio"),
    ("call rory toggleAudioEditor", "Abrir el editor de audio o Studio según sus ajustes"),
    ("rory-deck-native/control", "Abrir el selector Skwd-wall"),
    ("screenshot.py\" region", "Capturar una región"),
    ("screenshot.py\" window", "Capturar la ventana activa"),
    ("screenshot.py\" screen", "Capturar la pantalla"),
    ('screen-record.py" screen', "Iniciar o detener grabación del monitor"),
    ('screen-record.py" window', "Iniciar o detener grabación de ventana"),
    ('screen-record.py" region', "Iniciar o detener grabación de región"),
    ("navigate_windows.py", "Navegar entre ventanas"),
    ("floating_tile_toggle.py", "Alternar la disposición flotante"),
)


def active_shortcuts(bindings):
    rows = []
    for row in bindings:
        argument = str(row.get("arg", ""))
        description = next((label for fragment, label in BIND_TYPES
                            if fragment in argument and row.get("dispatcher") == "exec"), None)
        key = str(row.get("key", "")).strip()
        mask = row.get("modmask", 0)
        if not description or not re.fullmatch(r"[a-zA-Z0-9_:-]{1,25}", key) or not isinstance(mask, int) or mask & ~77:
            continue
        zones = [name for bit, name in [(64, "Super"), (4, "Ctrl"), (8, "Alt"), (1, "Shift")] if mask & bit]
        entry = (" + ".join([*zones, key]), description)
        if entry not in rows:
            rows.append(entry)
    if not rows:
        raise ValueError("Hyprland no informa de atajos activos de Rory reconocidos")
    return rows


def render(rows):
    height = max(1080, 220 + len(rows) * 65)
    content = []
    for index, (keys, name) in enumerate(rows):
        y = 205 + 65 * index
        content.append(f'<text x="170" y="{y}" fill="#ff9dc3">{html.escape(keys)}</text>'
                       f'<text x="520" y="{y}" fill="#ead9e2">{html.escape(name)}</text>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 {height}">'
            '<rect width="100%" height="100%" fill="black"/>'
            '<text x="170" y="125" fill="#f7c7da" font-size="49" font-family="sans-serif">Atajos activos de Rory</text>'
            '<g font-family="sans-serif" font-size="29">' + "".join(content) + "</g></svg>\n")


def ipc(*args):
    shell = Path.home() / "rory-hyprland/shell.qml"
    result = subprocess.check_output(["qs", "ipc", "-p", str(shell), "call", "rory", *map(str, args)],
                                     text=True, timeout=8)
    if "RORY_WALLPAPER_OK" not in result:
        raise ValueError(result.strip() or "Rory no confirmó el cambio de fondo")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("accion", choices=["aplicar", "conservar", "restaurar"], nargs="?")
    action = parser.parse_args().accion
    try:
        action = action or input("Fondo de atajos: aplicar, conservar o restaurar [conservar]: ").strip() or "conservar"
        if action == "conservar":
            return
        if action == "restaurar":
            ipc("restoreShortcutWallpaper")
            return
        if action != "aplicar":
            raise ValueError("Acción desconocida")
        data = subprocess.check_output(["hyprctl", "-j", "binds"], text=True, timeout=5)
        image = render(active_shortcuts(json.loads(data)))
        folder = Path.home() / ".local/state/rory-desktop-studio"
        folder.mkdir(parents=True, mode=0o700, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode="w", dir=folder, encoding="utf-8", delete=False) as temp:
            temp.write(image)
        target = folder / "shortcut-wallpaper.svg"
        os.replace(temp.name, target)
        ipc("applyShortcutWallpaper", target)
    except (OSError, EOFError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(1, f"Rory: {error}\n")


if __name__ == "__main__":
    main()
