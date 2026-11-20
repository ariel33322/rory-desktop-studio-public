#!/usr/bin/env python3

import fcntl
import json
import os
from pathlib import Path
import sys
from tempfile import NamedTemporaryFile
from time import sleep

from hypr_ipc import (batch, hyprctl_json, is_canvas_window,
                      move_window_exact_lua, resize_window_exact_lua,
                      window_float_lua)

RUNTIME_DIR = Path(os.environ["XDG_RUNTIME_DIR"])
LOCK_FILE = RUNTIME_DIR / "rory-floating-tile.lock"
STATE_FILE = RUNTIME_DIR / "rory-floating-tile.json"


def load_state():
    try:
        with open(STATE_FILE) as file:
            return json.load(file)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_state(state):
    with NamedTemporaryFile(mode="w", dir=os.path.dirname(STATE_FILE), delete=False) as file:
        try:
            json.dump(state, file, indent=2)
            file.close()
            os.replace(file.name, STATE_FILE)
        finally:
            if os.path.exists(file.name):
                os.unlink(file.name)


def apply_batch(expressions):
    if expressions:
        result = batch(expressions)
        if result.returncode or result.stdout.replace(b"ok", b"").strip():
            message = (result.stderr or result.stdout).decode(errors="replace").strip()
            raise SystemExit(f"Error de Hyprland: {message}")


def set_window_mode(windows, floating):
    apply_batch([
        window_float_lua(window["address"], floating)
        for window in windows
        if bool(window.get("floating")) != floating
    ])


def geometry_of(window):
    x, y = window["at"]
    width, height = window["size"]
    return {"x": x, "y": y, "w": width, "h": height,
            "class": window.get("class"), "pid": window.get("pid")}


def saved_geometry(window, positions):
    pos = positions.get(window["address"])
    if pos and pos.get("class") == window.get("class"):
        if "pid" not in pos or pos["pid"] == window.get("pid"):
            return pos
    return None


def place(address, x, y, width, height):
    return [
        resize_window_exact_lua(width, height, address),
        move_window_exact_lua(x, y, address),
    ]


def restore_geometry(windows, positions):
    expressions = []
    for window in windows:
        pos = saved_geometry(window, positions)
        if pos:
            expressions.extend(place(window["address"], pos["x"], pos["y"], pos["w"], pos["h"]))
    apply_batch(expressions)


def zoom_workspace(workspace_id, windows, state, direction, cursor_x, cursor_y):
    entry = state.get(str(workspace_id), {})
    if entry.get("mode") != "floating":
        return
    scale = entry.get("scale", 1.0)
    factor = 1.12 if direction == "in" else 1 / 1.12
    target = max(0.2, min(1.0, scale * factor))
    if abs(target - scale) < 0.000001:
        return

    ratio = target / scale
    originals = entry.setdefault("unzoomed", {})
    expressions = []
    for window in windows:
        if not window.get("floating") or window.get("fullscreen") or window.get("hidden"):
            continue
        address = window["address"]
        original = saved_geometry(window, originals)
        if original is None:
            original = originals[address] = geometry_of(window)
        x, y = window["at"]
        expressions.extend(place(
            address, round(cursor_x + (x - cursor_x) * ratio),
            round(cursor_y + (y - cursor_y) * ratio),
            max(60, round(original["w"] * target)),
            max(40, round(original["h"] * target)),
        ))

    save_state(state)
    apply_batch(expressions)
    entry["scale"] = target
    save_state(state)


def toggle_workspace(workspace_id, windows, state):
    key = str(workspace_id)
    previous = state.get(key, {})
    floating = previous.get("mode") != "floating"
    positions = previous.get("positions", previous)  # Compatibilidad con el estado anterior.

    if floating:
        set_window_mode(windows, True)
        restore_geometry(windows, positions)
        state[key] = {"mode": "floating", "positions": {}, "scale": 1.0}
    else:
        floated = [window for window in windows if window.get("floating")]
        originals = previous.get("unzoomed", {})
        restore_geometry(floated, originals)
        positions = {
            window["address"]: saved_geometry(window, originals) or geometry_of(window)
            for window in floated
        }
        set_window_mode(windows, False)
        state[key] = {"mode": "tiled", "positions": positions}

    save_state(state)


def apply_opened_window(address, workspace_id):
    for delay in (0, 0.05, 0.1):
        if delay:
            sleep(delay)
        with open(LOCK_FILE, "a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            state = load_state()
            entry = state.get(str(workspace_id), {})
            mode = entry.get("mode")
            if mode not in ("floating", "tiled"):
                return
            for window in hyprctl_json(["clients"]) or []:
                if window["address"] != address or not window.get("mapped", True):
                    continue
                if is_canvas_window(window, workspace_id):
                    set_window_mode([window], mode == "floating")
                    scale = entry.get("scale", 1.0)
                    if mode == "floating" and scale < 1.0 and not window.get("fullscreen"):
                        address = window["address"]
                        originals = entry.setdefault("unzoomed", {})
                        if saved_geometry(window, originals) is None:
                            original = originals[address] = geometry_of(window)
                            save_state(state)
                            apply_batch(place(
                                address, original["x"], original["y"],
                                max(60, round(original["w"] * scale)),
                                max(40, round(original["h"] * scale)),
                            ))
                return
    print(f"Ventana nueva {address} ausente de la lista de clientes.", file=sys.stderr)


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "--window":
        apply_opened_window(sys.argv[2], int(sys.argv[3]))
        return

    with open(LOCK_FILE, "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = load_state()
        workspace = hyprctl_json(["activeworkspace"])
        if not workspace:
            raise SystemExit("No se pudo consultar el escritorio activo.")
        if workspace.get("name", "").startswith("special"):
            return
        workspace_id = workspace["id"]
        clients = hyprctl_json(["clients"])
        if clients is None:
            raise SystemExit("No se pudieron consultar las ventanas.")
        windows = [window for window in clients if is_canvas_window(window, workspace_id)]
        if len(sys.argv) == 6 and sys.argv[1] == "--zoom":
            direction, expected_workspace, x, y = sys.argv[2:]
            if workspace_id == int(expected_workspace):
                zoom_workspace(workspace_id, windows, state, direction, float(x), float(y))
        else:
            toggle_workspace(workspace_id, windows, state)


if __name__ == "__main__":
    main()
