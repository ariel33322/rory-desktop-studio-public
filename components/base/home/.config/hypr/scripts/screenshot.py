import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path


MOUNT = Path(os.environ["HYPR_CAPTURE_MOUNT"]) if os.environ.get("HYPR_CAPTURE_MOUNT") else None
DESTINATION = (MOUNT or Path.home() / "Pictures") / os.environ.get("HYPR_SCREENSHOT_DIR", "Screenshots")


def open_destination():
    if MOUNT is None:
        DESTINATION.mkdir(mode=0o700, parents=True, exist_ok=True)
    elif not MOUNT.is_mount():
        raise RuntimeError(f"El HDD no está montado en {MOUNT}")
    if not DESTINATION.is_dir():
        raise RuntimeError(f"No existe la carpeta {DESTINATION}")
    if os.statvfs(DESTINATION).f_flag & os.ST_RDONLY or not os.access(DESTINATION, os.W_OK | os.X_OK):
        raise RuntimeError(f"La carpeta no es escribible: {DESTINATION}")

    # Keep the mounted directory open through capture and clipboard transfer.
    fd = os.open(DESTINATION, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        if MOUNT is not None and (not MOUNT.is_mount() or os.fstat(fd).st_dev != MOUNT.stat().st_dev):
            raise RuntimeError(f"La carpeta no está en el HDD montado: {DESTINATION}")
    except BaseException:
        os.close(fd)
        raise
    return fd


def report_error(message):
    print(f"Captura: {message}", file=sys.stderr)
    if shutil.which("notify-send"):
        subprocess.run(["notify-send", "--urgency=critical", "--", "Error de captura", message],
                       check=False)


def capture_geometry(mode):
    if mode == "region":
        selection = subprocess.run(["slurp"], capture_output=True, text=True)
        if selection.stderr and selection.returncode:
            print(selection.stderr.rstrip(), file=sys.stderr)
        return selection.stdout.strip() if selection.returncode == 0 else ""

    if mode == "window":
        window = json.loads(subprocess.check_output(["hyprctl", "-j", "activewindow"], text=True))
        if not window.get("at") or not window.get("size"):
            return ""
        x, y = window["at"]
        width, height = window["size"]
        return f"{x},{y} {width}x{height}" if width > 0 and height > 0 else ""

    return None


def save_capture(mode, directory):
    geometry = capture_geometry(mode)
    if geometry == "":
        return

    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    command = ["grim", "-t", "png"]
    if geometry is not None:
        command.extend(["-g", geometry])

    with tempfile.NamedTemporaryFile(prefix=f"Captura_{timestamp}_", suffix=".png",
                                     dir=directory, delete=False) as output:
        path = Path(output.name)
        try:
            subprocess.run([*command, "-"], stdout=output, check=True)
        except BaseException:
            path.unlink(missing_ok=True)
            raise

        if not shutil.which("wl-copy"):
            raise RuntimeError(
                f"Se guardó {DESTINATION / path.name}, pero falta wl-copy (paquete wl-clipboard)."
            )

        output.seek(0)
        try:
            subprocess.run(["wl-copy", "--type", "image/png"], stdin=output, check=True)
        except (OSError, subprocess.CalledProcessError) as error:
            raise RuntimeError(
                f"Se guardó {DESTINATION / path.name}, pero falló wl-copy: {error}"
            ) from error


def main(mode):
    fd = open_destination()
    try:
        save_capture(mode, Path(f"/proc/self/fd/{fd}"))
    finally:
        os.close(fd)


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in {"region", "screen", "window"}:
        sys.exit("Uso: screenshot.py {region|screen|window}")
    try:
        main(sys.argv[1])
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        report_error(str(error))
        sys.exit(1)
