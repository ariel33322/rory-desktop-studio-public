#!/usr/bin/env python3
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import select
import signal
import socket
import subprocess
import sys
import tempfile
import time
from datetime import datetime

MOUNT = Path(os.environ.get("HYPR_CAPTURE_MOUNT", "/mnt/captures"))
OUTPUT = MOUNT / os.environ.get("HYPR_RECORDING_DIR", "Recordings")
MONITOR = os.environ.get("HYPR_RECORDING_MONITOR")


def notify(title, message, error=False):
    print(f"{title}: {message}", file=sys.stderr)
    try:
        subprocess.run(
            ["notify-send", "-a", "Grabación de pantalla",
             "-u", "critical" if error else "normal", "--", title, message],
            check=False, timeout=3,
        )
    except (OSError, subprocess.TimeoutExpired):
        pass


def open_output():
    mount = subprocess.run(
        ["findmnt", "-rn", "-M", str(MOUNT), "-o", "ID,VFS-OPTIONS"],
        capture_output=True, text=True, check=False,
    )
    fields = mount.stdout.strip().split()
    if mount.returncode or len(fields) != 2:
        raise RuntimeError(f"El HDD no está montado en {MOUNT}.")
    mount_id, options = fields
    if "rw" not in options.split(","):
        raise RuntimeError(f"El HDD está montado en solo lectura ({MOUNT}).")
    try:
        fd = os.open(OUTPUT, os.O_RDONLY | os.O_DIRECTORY)
    except OSError as exc:
        raise RuntimeError(f"No se puede abrir la carpeta {OUTPUT}: {exc.strerror}") from exc
    try:
        info = Path(f"/proc/self/fdinfo/{fd}").read_text()
        if not re.search(rf"^mnt_id:\s+{mount_id}$", info, re.MULTILINE):
            raise RuntimeError(f"La carpeta de grabación no está en el HDD: {OUTPUT}")
        return fd
    except Exception:
        os.close(fd)
        raise


def control_requested(control, timeout=0.1):
    if select.select([control], [], [], timeout)[0]:
        with control.accept()[0]:
            return True
    return False


def hypr_json(command):
    result = subprocess.run(
        ["hyprctl", "-j", command], capture_output=True, text=True, timeout=3,
    )
    if result.returncode:
        raise RuntimeError(f"Hyprland no respondió a {command}: {result.stderr.strip()}")
    return json.loads(result.stdout)


def capture_args(mode, control, cancelled):
    if mode == "screen":
        monitor = MONITOR or next((m["name"] for m in hypr_json("monitors") if m.get("focused")), None)
        if monitor is None:
            raise RuntimeError("No se encontró un monitor enfocado para grabar.")
        return ["-w", monitor]
    if mode == "window":
        window = hypr_json("activewindow")
        if not window.get("at") or not window.get("size"):
            raise RuntimeError("No hay una ventana activa para grabar.")
        x, y = window["at"]
        width, height = window["size"]
    else:
        with subprocess.Popen(
            ["slurp"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        ) as picker:
            while picker.poll() is None:
                if cancelled() or control_requested(control):
                    picker.terminate()
                    return None
            selection, errors = picker.communicate()
            if picker.returncode and errors.strip():
                raise RuntimeError(f"El selector de área falló: {errors.strip()}")
            if picker.returncode or not selection.strip():
                return None
            match = re.fullmatch(r"(-?\d+),(-?\d+) (\d+)x(\d+)", selection.strip())
            if match is None:
                raise RuntimeError("Slurp devolvió una región inválida.")
            x, y, width, height = map(int, match.groups())

    monitors = hypr_json("monitors")
    monitor = next((m for m in monitors if (
        m["id"] == window.get("monitor") if mode == "window" else (m["name"] == MONITOR if MONITOR else m.get("focused"))
    )), None)
    if monitor is None:
        raise RuntimeError("No se encontró el monitor del área de captura.")
    mw, mh = monitor["width"], monitor["height"]
    if monitor.get("transform", 0) % 2:
        mw, mh = mh, mw
    left, top = monitor["x"], monitor["y"]
    right = left + round(mw / monitor["scale"])
    bottom = top + round(mh / monitor["scale"])
    x2, y2 = min(x + width, right), min(y + height, bottom)
    x, y = max(x, left), max(y, top)
    width, height = (x2 - x) // 2 * 2, (y2 - y) // 2 * 2
    if min(width, height) < 2:
        raise RuntimeError("El área seleccionada no tiene una región visible para grabar.")
    return ["-w", "region", "-region", f"{width}x{height}+{x}+{y}"]


def reserve_output(directory):
    stamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    for number in range(1000):
        suffix = f"-{number:03d}" if number else ""
        name = f"Grabacion-{stamp}{suffix}.mp4"
        try:
            fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600, dir_fd=directory)
        except FileExistsError:
            continue
        except OSError as exc:
            raise RuntimeError(f"No se puede escribir en {OUTPUT}: {exc.strerror}") from exc
        os.close(fd)
        return name
    raise RuntimeError("No se pudo reservar un nombre único para la grabación.")


def record(mode, control, runtime, lock_fd):
    interrupted = False

    def interrupt(_signum, _frame):
        nonlocal interrupted
        interrupted = True

    for sig in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
        signal.signal(sig, interrupt)

    directory = open_output()
    name = None
    try:
        # Comprobar permisos antes de abrir Slurp, incluso si el montaje es rw.
        if not os.access(f"/proc/self/fd/{directory}", os.W_OK | os.X_OK):
            raise RuntimeError(f"La carpeta de grabación no es escribible: {OUTPUT}")
        capture = capture_args(mode, control, lambda: interrupted)
        if capture is None or interrupted or control_requested(control, 0):
            return
        name = reserve_output(directory)
        ipc = runtime / "recorder.sock"
        ipc.unlink(missing_ok=True)
        command = [
            "gpu-screen-recorder", *capture, "-c", "mp4", "-f", "60", "-fm", "cfr",
            "-k", "h264", "-encoder", "gpu", "-fallback-cpu-encoding", "no",
            "-q", "high", "-tune", "performance", "-a", "default_output", "-ac", "aac",
            "-v", "no", "-ipc", str(ipc), "-o", f"/proc/self/fd/{directory}/{name}",
        ]
        with tempfile.TemporaryFile(dir=runtime) as log:
            with subprocess.Popen(
                command, stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                pass_fds=(directory, lock_fd), start_new_session=True,
            ) as recorder:
                stopping = announced = signalled = False
                while recorder.poll() is None:
                    stopping = control_requested(control) or interrupted or stopping
                    if ipc.exists():
                        if stopping and not signalled:
                            recorder.send_signal(signal.SIGINT)
                            signalled = True
                        elif not stopping and not announced:
                            notify("Grabación iniciada", name)
                            announced = True
            if recorder.returncode or os.stat(name, dir_fd=directory).st_size == 0:
                log.seek(max(0, log.seek(0, os.SEEK_END) - 1500))
                detail = log.read().decode(errors="replace").strip()
                raise RuntimeError(f"El grabador no guardó un MP4 correctamente. {detail or 'Sin detalles del grabador.'}")
        notify("Grabación guardada", str(OUTPUT / name))
    finally:
        if name is not None:
            try:
                if os.stat(name, dir_fd=directory).st_size == 0:
                    os.unlink(name, dir_fd=directory)
            except FileNotFoundError:
                pass
        os.close(directory)


def toggle(mode):
    runtime = Path(os.environ["XDG_RUNTIME_DIR"]) / "hypr-screen-record"
    runtime.mkdir(mode=0o700, exist_ok=True)
    address = runtime / "control.sock"
    with (runtime / "lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            # El controlador puede estar entre la adquisición del bloqueo y listen().
            for _ in range(20):
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
                    client.settimeout(0.2)
                    try:
                        client.connect(str(address))
                        return
                    except (FileNotFoundError, ConnectionRefusedError, TimeoutError):
                        time.sleep(0.05)
            ipc = runtime / "recorder.sock"
            if ipc.exists():
                subprocess.run(["gsr-cli", "-ipc", str(ipc), "stop"], check=True)
                return
            raise RuntimeError("El controlador está ocupado. Intenta de nuevo.")

        address.unlink(missing_ok=True)
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as control:
                control.bind(str(address))
                control.listen()
                record(mode, control, runtime, lock.fileno())
        finally:
            address.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("screen", "window", "region"))
    args = parser.parse_args()
    try:
        toggle(args.mode)
    except (RuntimeError, OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        notify("Error de grabación", str(exc), error=True)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
