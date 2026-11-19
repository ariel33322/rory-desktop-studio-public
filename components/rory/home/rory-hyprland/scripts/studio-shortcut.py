#!/usr/bin/env python3
"""Inspect/configure only Rory Studio's existing Hyprland Lua binding.

--apply is an explicit UI action. Other bindings and dispatchers are preserved.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

MODIFIERS = {"SHIFT": 1, "CTRL": 4, "ALT": 8, "SUPER": 64}
BINDING = re.compile(
    r'^(\s*hl\.bind\()(.+?)(,\s*hl\.dsp\.exec_cmd\(\[\[[^\n]*call rory (?:toggleAudioEditor|toggleStudio)[^\n]*\]\]\)\)\s*)$'
)


def shortcut(value):
    parts = [part.strip().upper() for part in value.split("+")]
    if len(parts) < 2 or not re.fullmatch(r"(?:[A-Z0-9]|F(?:[1-9]|1[0-2]))", parts[-1]):
        raise ValueError("Usa modificadores y una tecla: SUPER + P, CTRL + ALT + S…")
    if len(set(parts[:-1])) != len(parts[:-1]) or any(part not in MODIFIERS for part in parts[:-1]):
        raise ValueError("Modificadores permitidos: SUPER, CTRL, ALT y SHIFT")
    mask = sum(MODIFIERS[part] for part in parts[:-1])
    return " + ".join(parts), mask, parts[-1]


def locate(text):
    lines = text.splitlines(keepends=True)
    matches = [(index, BINDING.fullmatch(line.rstrip("\r\n"))) for index, line in enumerate(lines)]
    matches = [(index, match) for index, match in matches if match]
    if len(matches) != 1:
        raise ValueError("No hay un único enlace Lua reconocible de Studio; no se modificó Hyprland")
    return lines, *matches[0]


def current_shortcut(text):
    _, _, match = locate(text)
    expression = match.group(2).strip()
    literal = re.fullmatch(r'"([A-Za-z0-9 +]+)"', expression)
    if literal:
        return shortcut(literal.group(1))[0]
    relative = re.fullmatch(r'mainMod\s*\.\.\s*"([A-Za-z0-9 +]+)"', expression)
    main_mod = re.search(r'^\s*local\s+mainMod\s*=\s*"([A-Za-z +]+)"', text, re.MULTILINE)
    if relative and main_mod:
        return shortcut(main_mod.group(1) + relative.group(1))[0]
    raise ValueError("El enlace de Studio usa una expresión dinámica; no se modificó")


def plan(text, desired, bindings):
    label, mask, key = shortcut(desired)
    lines, index, match = locate(text)
    for binding in bindings:
        if binding.get("modmask") != mask or str(binding.get("key", "")).upper() != key:
            continue
        argument = str(binding.get("arg", ""))
        if binding.get("dispatcher") == "exec" and re.search(r'call rory (?:toggleAudioEditor|toggleStudio)\b', argument):
            continue
        raise ValueError("Ese atajo ya pertenece a otra acción de Hyprland; elige otra combinación")
    newline = "\r\n" if lines[index].endswith("\r\n") else "\n" if lines[index].endswith("\n") else ""
    lines[index] = match.group(1) + '"' + label + '"' + match.group(3) + newline
    return "".join(lines), label


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--shortcut", default="SUPER + P")
    parser.add_argument("--status", action="store_true")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    config = Path.home() / ".config/hypr/hyprland.lua"
    try:
        text = config.read_text()
        if args.status:
            print(json.dumps({"ok": True, "shortcut": current_shortcut(text), "message": "Atajo actual de Studio"}))
            return
        result = subprocess.run(["hyprctl", "-j", "binds"], check=True, capture_output=True, text=True, timeout=5)
        bindings = json.loads(result.stdout)
        if not isinstance(bindings, list):
            raise ValueError("Hyprland no devolvió una lista válida de atajos")
        updated, label = plan(text, args.shortcut, bindings)
        backup = ""
        if args.apply and updated != text:
            if config.is_symlink():
                raise ValueError("La configuración es un enlace simbólico; conserva el enlace y cambia el atajo manualmente")
            backup_dir = Path(__file__).resolve().parent.parent / ".backups"
            backup_dir.mkdir(exist_ok=True)
            target = backup_dir / ("hypr-studio-shortcut-" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f") + ".lua")
            shutil.copy2(config, target)
            backup = str(target)
            descriptor, temporary = tempfile.mkstemp(prefix=".rory-shortcut-", dir=config.parent)
            try:
                with os.fdopen(descriptor, "w") as stream:
                    stream.write(updated)
                shutil.copymode(config, temporary)
                # Refuse to overwrite concurrent edits made after the inspection.
                if config.read_text() != text:
                    raise ValueError("Hyprland cambió durante la operación; vuelve a intentarlo")
                os.replace(temporary, config)
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)
            reload_result = subprocess.run(["hyprctl", "reload"], capture_output=True, text=True, timeout=5)
            if reload_result.returncode:
                raise ValueError("Atajo guardado con respaldo; Hyprland no pudo recargarlo. Revisa su configuración")
        print(json.dumps({"ok": True, "applied": args.apply, "shortcut": label, "backup": backup,
                          "message": "Atajo de Studio aplicado" if args.apply else "Combinación disponible para Studio"}))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(json.dumps({"ok": False, "message": str(error)}))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
