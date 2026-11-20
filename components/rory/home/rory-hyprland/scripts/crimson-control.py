#!/usr/bin/env python3
"""Local adapters for Crimson Center; no system settings are changed by probing."""
import contextlib
import fcntl
import json
import os
from pathlib import Path
import re
import select
import shutil
import subprocess
import sys
import tempfile
import time

MAX_FLASH_SECONDS = 120


def runtime():
    base = Path(os.environ["XDG_RUNTIME_DIR"])
    path = base / "rory-crimson"
    path.mkdir(mode=0o700, exist_ok=True)
    if path.is_symlink() or path.stat().st_uid != os.getuid() or path.stat().st_mode & 0o077:
        raise RuntimeError("Directorio de recuperación inseguro")
    return path


def atomic_json(path, data):
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as file:
        scratch = Path(file.name)
        try:
            json.dump(data, file)
            file.flush()
            os.fsync(file.fileno())
            scratch.replace(path)
        finally:
            scratch.unlink(missing_ok=True)


@contextlib.contextmanager
def locked(name):
    with (runtime() / name).open("a") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield


def backlight(output, require_connected=True):
    if not re.fullmatch(r"(eDP|LVDS|DSI)-[0-9]+", output):
        return None
    connectors = [p.resolve() for p in Path("/sys/class/drm").glob("card*-" + output)
                  if not require_connected or (p / "status").read_text().strip() == "connected"]
    candidates = [p for p in Path("/sys/class/backlight").glob("*")
                  if (p / "device").resolve() in connectors]
    return candidates[0] if len(connectors) == 1 and len(candidates) == 1 else None


def read_level(device, name):
    return int((device / name).read_text())


def drive_level(device, value, method):
    if method == "sysfs":
        (device / "brightness").write_text(str(value))
    elif method == "brightnessctl":
        command("brightnessctl", "-q", "-c", "backlight", "-d", device.name, "set", str(value))
    elif method == "logind":
        command("busctl", "--system", "call", "org.freedesktop.login1",
                "/org/freedesktop/login1/session/self", "org.freedesktop.login1.Session",
                "SetBrightness", "ssu", "backlight", device.name, str(value))
    else:
        raise RuntimeError("Método de brillo no disponible")
    if read_level(device, "brightness") != value:
        raise RuntimeError("El controlador no confirmó el brillo solicitado")


def write_methods(device):
    if os.access(device / "brightness", os.W_OK):
        yield "sysfs"
    if shutil.which("brightnessctl"):
        yield "brightnessctl"
    if shutil.which("busctl"):
        yield "logind"


def verify_writer(device):
    errors = []
    for method in write_methods(device):
        try:
            if method == "sysfs":
                # Verify that opening for writing really works, without changing the level.
                os.close(os.open(device / "brightness", os.O_WRONLY | os.O_CLOEXEC))
            else:
                # Prove session authorization without requesting a different brightness.
                drive_level(device, read_level(device, "brightness"), method)
            return method
        except (OSError, RuntimeError, subprocess.SubprocessError) as error:
            if str(error) not in errors:
                errors.append(str(error))
    raise RuntimeError("La sesión no pudo escribir el brillo" + (": " + "; ".join(errors) if errors else ""))


def write_level(device, value, method=None):
    drive_level(device, value, method or verify_writer(device))


def light_status(output, check=False):
    device = backlight(output)
    if device is None:
        return {"level": -1, "method": "", "reason": "Este monitor no tiene una retroiluminación interna identificada"}
    level = read_level(device, "brightness") / max(1, read_level(device, "max_brightness"))
    status = {"level": level}
    if check:
        try:
            with locked("flash.lock"):
                if (runtime() / "flash.json").exists():
                    raise RuntimeError("Hay una restauración de brillo pendiente")
                status.update(method=verify_writer(device), reason="")
        except (OSError, RuntimeError) as error:
            status.update(method="", reason=str(error) or "El brillo está temporalmente ocupado")
    return status


def restore_flash():
    journal = runtime() / "flash.json"
    if not journal.exists():
        return
    previous = json.loads(journal.read_text())
    device = backlight(previous["output"], require_connected=False)
    if device is None or device.name != previous["device"]:
        raise RuntimeError("Vuelve a conectar el monitor y ejecuta recover-flash")
    for attempt in range(3):
        try:
            write_level(device, previous["value"], previous.get("method"))
            journal.unlink()
            return
        except (OSError, RuntimeError, subprocess.SubprocessError):
            if attempt == 2:
                raise
            time.sleep(.15)


def flash_guard(output, pipe):
    # The detached guardian owns the lock and journal. Only the GUI client
    # owns the writer; its exit (including SIGKILL) closes the lease.
    with locked("flash.lock"):
        restore_flash()
        device = backlight(output)
        try:
            method = verify_writer(device) if device is not None else ""
        except RuntimeError:
            method = ""
        if method:
            previous = read_level(device, "brightness")
            maximum = read_level(device, "max_brightness")
            if previous != maximum:
                atomic_json(runtime() / "flash.json",
                            {"output": output, "device": device.name, "value": previous, "method": method})
                try:
                    write_level(device, maximum, method)
                except Exception:
                    restore_flash()
                    raise
        try:
            print("READY", flush=True)
            select.select([pipe], [], [], MAX_FLASH_SECONDS)
        finally:
            restore_flash()


def flash_client(output):
    reader, writer = os.pipe()
    try:
        with subprocess.Popen(
            [sys.executable, __file__, "flash-guard", output, str(reader)],
            pass_fds=(reader,), start_new_session=True, stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, text=True
        ) as guardian:
            os.close(reader)
            reader = None
            try:
                if not select.select([guardian.stdout], [], [], 4)[0] or guardian.stdout.readline().strip() != "READY":
                    raise RuntimeError("No se pudo iniciar la protección del brillo")
                print("READY", flush=True)
                deadline = time.monotonic() + MAX_FLASH_SECONDS
                while guardian.poll() is None and time.monotonic() < deadline:
                    if select.select([sys.stdin], [], [], .25)[0]:
                        # STOP and EOF both end the lease.
                        break
            finally:
                os.close(writer)
                writer = None
    finally:
        if reader is not None:
            os.close(reader)
        if writer is not None:
            os.close(writer)


def command(*args, timeout=2):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"{args[0]} no respondió")
    return result.stdout.strip()


def optional(*args):
    if not shutil.which(args[0]):
        return None
    try:
        return command(*args, timeout=1.4)
    except (RuntimeError, OSError, subprocess.SubprocessError):
        return None


def radio_list():
    raw = optional("rfkill", "--json")
    if raw is None or not os.access("/dev/rfkill", os.W_OK):
        return []
    return [r for r in json.loads(raw).get("rfkilldevices", [])
            if r.get("type") in ("wlan", "bluetooth", "wwan") and re.fullmatch(r"[0-9]+", str(r.get("id")))]


def airplane():
    path = runtime() / "airplane.json"
    with locked("airplane.lock"):
        radios = radio_list()
        if not radios:
            raise RuntimeError("No hay radios modificables mediante rfkill")
        if path.exists():
            restore = json.loads(path.read_text())
            for radio in radios:
                identifier = str(radio["id"])
                if restore.get(identifier) == [radio.get("type"), radio.get("device"), "unblocked"]:
                    command("rfkill", "unblock", identifier)
            path.unlink()
        else:
            atomic_json(path, {str(r["id"]): [r.get("type"), r.get("device"), r.get("soft")] for r in radios})
            for radio in radios:
                command("rfkill", "block", str(radio["id"]))


def screen_script(name):
    return Path.home() / ".config" / "hypr" / name


def recording_active():
    base = Path(os.environ["XDG_RUNTIME_DIR"]) / "hypr-screen-record"
    try:
        with (base / "lock").open("rb") as handle:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except FileNotFoundError:
        return "idle"
    except BlockingIOError:
        return "active" if (base / "recorder.sock").is_socket() else "starting"
    return "idle"


def record():
    # The original controller remains the sole owner of the capture and lock.
    error_path = runtime() / "record-error.json"
    with tempfile.TemporaryFile(mode="w+t", dir=runtime()) as log:
        result = subprocess.run([sys.executable, str(screen_script("screen-record.py")), "screen"],
                                stdout=log, stderr=log)
        if result.returncode:
            log.seek(0)
            messages = log.read().splitlines()
            error = next((m for m in reversed(messages) if m.startswith("Error de grabación")), "Error de grabación")
            atomic_json(error_path, error)
        elif recording_active() == "idle":
            error_path.unlink(missing_ok=True)


def power_available():
    output = optional(sys.executable, str(Path(__file__).with_name("battery-metrics.py")))
    return bool(output and json.loads(output).get("profiles") and shutil.which("powerprofilesctl"))


def probe(output):
    kde = optional("kdeconnect-cli", "--list-available", "--id-only")
    dnd = optional("dunstctl", "is-paused")
    if dnd is None:
        dnd = optional("swaync-client", "-D")
        notification = "swaync" if dnd in ("true", "false") else ""
    else:
        notification = "dunst"
    radios = radio_list()
    record_log = runtime() / "record-error.json"
    try:
        record_error = json.loads(record_log.read_text())
    except FileNotFoundError:
        record_error = ""
    return {
        "kde": sum(bool(re.fullmatch(r"[A-Za-z0-9_-]{12,}", line.strip())) for line in kde.splitlines()) if kde is not None else -1,
        "kdeApp": bool(shutil.which("kdeconnect-app")),
        "airplane": bool(radios), "airplaneOn": bool(radios) and all(r.get("soft") == "blocked" for r in radios),
        "canDnd": bool(notification), "dnd": dnd == "true",
        "settings": bool(shutil.which("systemsettings")),
        "record": screen_script("screen-record.py").is_file() and bool(shutil.which("gpu-screen-recorder")),
        "recordState": recording_active(),
        "recordError": record_error,
        "capture": screen_script("screenshot.py").is_file(),
        "power": power_available(),
    }


def action(name):
    if name == "record":
        (runtime() / "record-error.json").unlink(missing_ok=True)
        subprocess.Popen([sys.executable, __file__, "_record"], start_new_session=True,
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif name == "capture":
        command(sys.executable, str(screen_script("screenshot.py")), "region", timeout=120)
    elif name in ("settings", "kde"):
        subprocess.Popen(["systemsettings" if name == "settings" else "kdeconnect-app"], start_new_session=True,
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif name in ("dnd", "notifications"):
        if optional("dunstctl", "is-paused") is not None:
            command("dunstctl", *("set-paused", "toggle") if name == "dnd" else ("history-pop",))
        elif optional("swaync-client", "-D") in ("true", "false"):
            command("swaync-client", "-d" if name == "dnd" else "-t")
        else:
            raise RuntimeError("No se encontró un gestor compatible de notificaciones")
    elif name == "airplane":
        airplane()
    elif name == "power":
        if not power_available():
            raise RuntimeError("El gestor de perfiles no está disponible o hay un conflicto")
        current = command("powerprofilesctl", "get")
        command("powerprofilesctl", "set", "balanced" if current == "power-saver" else "power-saver")
    else:
        raise RuntimeError("Acción no reconocida")


def main(args):
    mode, *fields = args
    if mode == "probe":
        print(json.dumps(probe(fields[0])))
    elif mode == "flash-guard":
        flash_guard(fields[0], int(fields[1]))
    elif mode == "flash":
        flash_client(fields[0])
    elif mode == "recover-flash":
        with locked("flash.lock"):
            restore_flash()
    elif mode in ("brightness-check","brightness-read"):
        print(json.dumps(light_status(fields[0], check=mode=="brightness-check")))
    elif mode == "brightness":
        with locked("flash.lock"):
            if (runtime() / "flash.json").exists():
                raise RuntimeError("Hay una restauración de brillo pendiente")
            device = backlight(fields[0])
            if device is None:
                raise RuntimeError("Este monitor no ofrece retroiluminación interna")
            fraction = float(fields[1])
            if not 0 <= fraction <= 1:
                raise RuntimeError("Brillo fuera de rango")
            write_level(device, max(1, round(fraction * read_level(device, "max_brightness"))), fields[2] if len(fields)>2 else None)
            print(json.dumps(light_status(fields[0])))
    elif mode == "action":
        action(fields[0])
    elif mode == "_record":
        record()
    else:
        raise RuntimeError("Operación no reconocida")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (OSError, KeyError, IndexError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr, flush=True)
        sys.exit(1)
