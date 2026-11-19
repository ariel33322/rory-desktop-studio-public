#!/usr/bin/env python3
"""Small client for EasyEffects 8.3's documented local socket server."""

import json
import os
import socket
import sys
import tempfile
from pathlib import Path

SERVER_NAME = "EasyEffectsServer"


def socket_paths():
    paths = []
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if runtime:
        paths.append(Path(runtime) / SERVER_NAME)
    paths.append(Path("/tmp") / SERVER_NAME)
    return list(dict.fromkeys(paths))


def request(path, command):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(0.35)
        client.connect(str(path))
        client.sendall((command + "\n").encode("utf-8"))
        if command == "get_global_bypass":
            return client.recv(1).decode("utf-8", "replace").strip()
        if not command.startswith(("get_property:", "get_last_loaded_preset:")):
            return ""
        chunks = bytearray()
        while b"\n" not in chunks:
            chunk = client.recv(4096)
            if not chunk:
                break
            chunks.extend(chunk)
    return bytes(chunks).decode("utf-8", "replace").strip()


def find_server():
    for path in socket_paths():
        try:
            request(path, "get_global_bypass")
            return path
        except (OSError, ValueError):
            continue
    return None


def get_value(path, command):
    try:
        return request(path, command)
    except (OSError, ValueError):
        return ""


def preset_directory(path):
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    if path.parent == Path(tempfile.gettempdir()):
        return Path.home() / ".var/app/com.github.wwmm.easyeffects/data/easyeffects/output"
    return data_home / "easyeffects/output"


def list_presets(path):
    directory = preset_directory(path)
    try:
        return sorted(
            ({"name": preset.stem} for preset in directory.iterdir()
             if preset.is_file() and preset.suffix == ".json"
             and 0 < len(preset.stem) <= 100 and "\n" not in preset.stem and "\r" not in preset.stem),
            key=lambda preset: preset["name"].casefold(),
        )
    except OSError:
        return []


def snapshot(path):
    bypass = get_value(path, "get_global_bypass")
    loaded = get_value(path, "get_last_loaded_preset:output")
    band_count_value = get_value(path, "get_property:output:equalizer:0:numBands")
    try:
        band_count = max(0, min(32, int(band_count_value)))
    except ValueError:
        band_count = 0

    equalizer_available = band_count > 0
    equalizer_bypass = False
    bands = []
    if equalizer_available:
        equalizer_bypass = get_value(path, "get_property:output:equalizer:0:bypass").lower() == "true"
        for index in range(band_count):
            prefix = f"get_property:output:equalizer:0:"
            channel_prefix = f"{prefix}left:"
            try:
                frequency = float(get_value(path, f"{channel_prefix}band{index}Frequency"))
                left = float(get_value(path, f"{channel_prefix}band{index}Gain"))
                right = float(get_value(path, f"{prefix}right:band{index}Gain"))
            except ValueError:
                continue
            bands.append({"index": index, "frequency": frequency, "left": left, "right": right})

    return {
        "running": True,
        "globalBypass": bypass == "1",
        "loadedPreset": loaded,
        "presets": list_presets(path),
        "equalizerAvailable": equalizer_available,
        "equalizerBypass": equalizer_bypass,
        "bands": bands,
    }


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    path = find_server()
    if action == "status":
        result = snapshot(path) if path else {
            "running": False,
            "presets": [],
            "bands": [],
            "equalizerAvailable": False,
            "globalBypass": False,
            "equalizerBypass": False,
            "loadedPreset": "",
        }
        print(json.dumps(result, separators=(",", ":")))
        return 0
    if not path:
        return 1

    if action == "show":
        request(path, "show_window")
    elif action == "global-bypass" and len(sys.argv) == 3 and sys.argv[2] in {"0", "1"}:
        request(path, f"global_bypass:{sys.argv[2]}")
    elif action == "eq-bypass" and len(sys.argv) == 3 and sys.argv[2] in {"0", "1"}:
        request(path, f"set_property:output:equalizer:0:bypass:{'false' if sys.argv[2] == '0' else 'true'}")
    elif action == "gain" and len(sys.argv) == 5:
        try:
            index = int(sys.argv[2])
            channel = sys.argv[3]
            value = float(sys.argv[4])
        except ValueError:
            return 2
        if not 0 <= index < 32 or channel not in {"left", "right"}:
            return 2
        request(path, f"set_property:output:equalizer:0:{channel}:band{index}Gain:{value:.12g}")
    elif action == "load" and len(sys.argv) == 3 and 0 < len(sys.argv[2]) <= 100 and "\n" not in sys.argv[2]:
        request(path, f"load_preset:output:{sys.argv[2]}")
    else:
        return 2
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
