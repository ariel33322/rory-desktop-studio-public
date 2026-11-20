#!/usr/bin/env python3
"""Transactional per-user installer for the public Rory distribution."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
COMPONENTS = ("rory", "base", "crimson-noir", "infinite-desktop", "skwd-wall")
MAIN = ".config/hypr/hyprland.lua"
MODULE = ".config/hypr/rory-distribution.lua"
SKWD = ".local/share/rory-deck-native/"
STATE = ".local/state/rory-desktop-studio"
HOOK = '\n-- Rory Desktop Studio (installer)\ndofile(os.getenv("HOME") .. "/' + MODULE + '")\n'
BINDINGS = {
    "base": [
        (0, "Print", "Capturar región", 'python3 "$HOME/.config/hypr/scripts/screenshot.py" region'),
        (1, "Print", "Capturar pantalla", 'python3 "$HOME/.config/hypr/scripts/screenshot.py" screen'),
        (64, "Print", "Capturar ventana", 'python3 "$HOME/.config/hypr/scripts/screenshot.py" window'),
        (12, "R", "Grabar monitor", 'python3 "$HOME/.config/hypr/screen-record.py" screen'),
        (9, "Print", "Grabar región de ventana", 'python3 "$HOME/.config/hypr/screen-record.py" window'),
        (5, "Print", "Grabar región", 'python3 "$HOME/.config/hypr/screen-record.py" region'),
    ],
    "rory": [(64, "P", "Abrir Rory Desktop Studio",
              'qs ipc -p "$HOME/rory-hyprland/shell.qml" call rory toggleStudio')],
    "skwd-wall": [(64, "W", "Abrir Skwd-wall", '"$HOME/.local/share/rory-deck-native/control" picker')],
}
AUTOSTART = {
    "rory": 'qs -n -d -p "$HOME/rory-hyprland/shell.qml"',
    "skwd-wall": '"$HOME/.local/share/rory-deck-native/control" start',
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def probe(command):
    try:
        return subprocess.check_output(command, text=True, stderr=subprocess.DEVNULL, timeout=5).strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def preflight(selected, packages):
    config = json.loads((ROOT / "installer/dependencies.json").read_text())
    distro = dict(line.strip().split("=", 1) for line in Path("/etc/os-release").read_text().splitlines()
                  if line and not line.startswith("#") and "=" in line)
    manager = next((item for item in ("pacman", "apt", "dnf", "zypper") if shutil.which(item)), None)
    print("Distribución:", distro.get("PRETTY_NAME", distro.get("ID")), "| gestor:", manager or "no detectado")
    print("Wayland:", "señal de sesión presente" if os.environ.get("WAYLAND_DISPLAY") else "sesión no detectada")
    hyprland = probe(["Hyprland", "--version"]).splitlines()
    print("Hyprland:", hyprland[0] if hyprland else "no detectado",
          "| Quickshell:", probe(["qs", "--version"]) or "no detectado")
    required = config["required_for_rory"] if "rory" in selected else {}
    missing = {package for executable, package in required.items() if not shutil.which(executable)}
    if manager == "pacman" and "rory" in selected:
        missing.update(package for package in config["packages_for_rory"] if not probe(["pacman", "-Q", package]))
    print("Dependencias obligatorias ausentes:", ", ".join(sorted(missing)) or "ninguna detectada")
    for module, dependencies in config["optional_by_module"].items():
        unavailable = [package for program, package in dependencies.items() if not shutil.which(program)]
        if unavailable:
            print(f"Opcionales ausentes ({module}): " + ", ".join(unavailable))
    if manager == "pacman":
        for module, dependencies in config["optional_package_only"].items():
            unavailable = [package for package in dependencies if not probe(["pacman", "-Q", package])]
            if unavailable:
                print(f"Paquetes opcionales ausentes ({module}): " + ", ".join(unavailable))
    if not missing:
        return
    if packages and manager == "pacman":
        allowed = missing - {"hyprland"}
        if allowed:
            command = ["sudo", "pacman", "-S", "--needed", *sorted(allowed)]
            print("Propuesta:", " ".join(command))
            if input("¿Instalar estos paquetes? [s/N] ").strip().lower() == "s":
                subprocess.run(command, check=True)
                return preflight(selected, False)
    raise ValueError("Instala los requisitos ausentes manualmente. El instalador no instala Hyprland.")


def active_binds():
    data = probe(["hyprctl", "-j", "binds"])
    if not data:
        raise ValueError("No se pudo consultar los atajos activos. Ejecuta la integración dentro de Hyprland.")
    rows = json.loads(data)
    if not isinstance(rows, list):
        raise ValueError("Respuesta inesperada de hyprctl binds")
    return rows


def lua_integration(selected, bind, autostart, previous):
    lines = ["-- Generado por Rory Desktop Studio."]
    if bind:
        rows = active_binds()
        for item in selected:
            for mask, key, _, command in BINDINGS.get(item, ()):
                clashes = [row for row in rows if row.get("modmask") == mask and
                           str(row.get("key", "")).upper() == key and
                           not (previous and row.get("dispatcher") == "exec" and row.get("arg") == command)]
                if clashes:
                    raise ValueError(f"El atajo con máscara {mask} y tecla {key} está asignado. Instala sin ese módulo o sin atajos.")
                modifiers = [name for bit, name in [(64, "SUPER"), (4, "CTRL"), (8, "ALT"), (1, "SHIFT")] if mask & bit]
                label = " + ".join([*modifiers, key])
                lines.append(f'hl.bind("{label}", hl.dsp.exec_cmd([[{command}]]))')
    if autostart:
        for item in selected:
            if item in AUTOSTART:
                lines.extend(['hl.on("hyprland.start", function()',
                              f'    hl.exec_cmd([[{AUTOSTART[item]}]])', 'end)'])
    return ("\n".join(lines) + "\n").encode()


def skwd_payloads(package_directory):
    provenance = ROOT / "components/skwd-wall/home" / SKWD / "provenance.txt"
    with tempfile.TemporaryDirectory(prefix="rory-skwd-") as temp:
        unpacked = Path(temp) / "payload"
        unpacked.mkdir()
        for line in provenance.read_text().splitlines()[1:]:
            digest, filename = line.split()
            package = Path(temp) / filename
            shutil.copyfile(package_directory / filename, package)
            with package.open("rb") as archive:
                if hashlib.file_digest(archive, "sha256").hexdigest() != digest:
                    raise ValueError(f"SHA-256 incorrecto en el paquete: {filename}")
            subprocess.run(["bsdtar", "-xf", str(package), "-C", str(unpacked),
                            "--no-same-owner", "--no-same-permissions"], check=True)
        usr = unpacked / "usr"
        if not (usr / "bin/skwd-wall-v2").is_file() or not (usr / "bin/skwd-walld").is_file():
            raise ValueError("Los paquetes no contienen Wall y Deck para el despliegue previsto")
        for file in usr.rglob("*"):
            if file.is_dir() and not file.is_symlink():
                continue
            origin = file.resolve(strict=True)
            if not origin.is_relative_to(usr) or not origin.is_file():
                raise ValueError(f"Enlace o archivo inesperado en los paquetes: {file.relative_to(usr)}")
            yield SKWD + file.relative_to(unpacked).as_posix(), (origin.read_bytes(), origin.stat().st_mode & 0o777)


class Installation:
    def __init__(self, home):
        self.home = home.resolve(strict=True)
        self.state = self.path(STATE)
        self.state.mkdir(mode=0o700, parents=True, exist_ok=True)
        self.lock = self.path(STATE + "/lock").open("a")
        fcntl.flock(self.lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        self.manifest = self.path(STATE + "/manifest.json")
        self.old = json.loads(self.manifest.read_text()) if self.manifest.is_file() else {}

    def path(self, relative):
        parts = Path(relative).parts
        if not parts or Path(relative).is_absolute() or ".." in parts:
            raise ValueError("Ruta fuera del destino de instalación")
        path = self.home
        for part in parts:
            path /= part
            if path.is_symlink():
                raise ValueError(f"El destino usa un enlace simbólico: {path}")
        return path

    def read(self, name):
        path = self.path(name)
        return (path.read_bytes(), path.stat().st_mode & 0o777) if path.exists() else None

    def write(self, name, payload):
        path = self.path(name)
        if payload is None:
            path.unlink(missing_ok=True)
            return
        path.parent.mkdir(parents=True, exist_ok=True)
        data, mode = payload
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".rory-", delete=False) as stream:
            temporary = Path(stream.name)
            try:
                stream.write(data)
                stream.close()
                temporary.chmod(mode)
                temporary.replace(path)
            finally:
                temporary.unlink(missing_ok=True)

    def plan(self, selected, integration, repair=False, skwd_packages=None):
        desired = {}
        for component in selected:
            tree = ROOT / "components" / component / "home"
            for file in tree.rglob("*"):
                if not file.is_file() or "__pycache__" in file.parts:
                    continue
                relative = file.relative_to(tree).as_posix()
                if relative.startswith(".config/hypr/") and file.suffix == ".lua":
                    relative = ".local/share/rory-desktop-studio/examples/" + file.name
                if file.name.startswith(".") and file.suffix in {".ini", ".json"}:
                    continue
                desired[relative] = (file.read_bytes(), file.stat().st_mode & 0o777)
        if "skwd-wall" in selected:
            if skwd_packages:
                desired.update(skwd_payloads(skwd_packages))
            else:
                for name, digest in self.old.get("files", {}).items():
                    if name.startswith(SKWD + "usr/"):
                        installed = self.read(name)
                        if not installed or sha(installed[0]) != digest:
                            raise ValueError("El binario de Skwd cambió o falta. Aporta los paquetes fijados para repararlo.")
                        desired[name] = installed
            if SKWD + "usr/bin/skwd-walld" not in desired:
                print("Skwd-wall: solo integración y lanzador. Aporta los paquetes con --skwd-paquetes.")
            example = desired.get(SKWD + "config/config.example.json")
            # The live Skwd configuration is created once and remains user data.
            if example and not self.path(SKWD + "config/config.json").exists():
                new_skwd_config = example
            else:
                new_skwd_config = None
        else:
            new_skwd_config = None
        baseline = self.old.get("baseline")
        if integration[0] or integration[1]:
            if not self.path(MAIN).is_file():
                raise ValueError("Hace falta una configuración existente hyprland.lua para integrar inicio o atajos")
            if baseline is None:
                original, mode = self.read(MAIN)
                original.decode("utf-8")
                if HOOK.encode() in original:
                    raise ValueError("Ya existe una integración Rory sin manifiesto")
                baseline = {"data": original.hex(), "mode": mode}
            desired[MAIN] = (bytes.fromhex(baseline["data"]) + HOOK.encode(), baseline["mode"])
            integrated = [item for item in selected if item != "skwd-wall"
                          or SKWD + "usr/bin/skwd-walld" in desired]
            desired[MODULE] = (lua_integration(integrated, *integration, MODULE in self.old.get("files", {})), 0o644)
        current = self.old.get("files", {})
        writes = {SKWD + "config/config.json": new_skwd_config} if new_skwd_config else {}
        for name in sorted(current.keys() | desired.keys()):
            actual = self.read(name)
            if name in current and actual and sha(actual[0]) != current[name] and not (repair and name != MAIN):
                raise ValueError(f"Archivo administrado modificado: {name}. Usa reparar para restaurar el código.")
            if name not in current and actual is not None and name != MAIN:
                raise ValueError(f"El destino ya existe y no pertenece al instalador: {name}")
            target = desired.get(name)
            if name == MAIN and target is None and baseline is not None:
                target = (bytes.fromhex(baseline["data"]), baseline["mode"])
            if actual != target:
                writes[name] = target
        manifest = {"components": selected, "integration": integration,
                    "baseline": baseline if MODULE in desired else None,
                    "files": {name: sha(item[0]) for name, item in desired.items()}}
        writes[str(self.manifest.relative_to(self.home))] = (json.dumps(manifest, indent=2).encode(), 0o600)
        return writes

    def transact(self, changes):
        backup_path = self.path(STATE + "/backups")
        backup_path.mkdir(mode=0o700, exist_ok=True)
        backup = Path(tempfile.mkdtemp(dir=backup_path, prefix="operacion-"))
        before = {name: self.read(name) for name in changes}
        index = {}
        for number, (name, value) in enumerate(before.items()):
            entry = {"after": sha(changes[name][0]) if changes[name] else None}
            if value is not None:
                (backup / str(number)).write_bytes(value[0])
                entry.update(file=str(number), sha=sha(value[0]), mode=value[1])
            index[name] = entry
        (backup / "index.json").write_text(json.dumps(index, indent=2))
        changed = []
        try:
            for name, value in changes.items():
                if self.read(name) != before[name]:
                    raise ValueError(f"Cambio concurrente detectado: {name}")
                self.write(name, value)
                changed.append(name)
            (backup / "completed").touch()
        except BaseException:
            for name in reversed(changed):
                self.write(name, before[name])
            raise
        print("Respaldo:", backup)

    def restoration(self):
        folder = self.path(STATE + "/backups")
        backups = sorted((item for item in folder.iterdir() if (item / "completed").is_file()),
                         key=lambda item: item.stat().st_mtime_ns) if folder.is_dir() else []
        if not backups:
            raise ValueError("No hay operaciones completadas para restaurar")
        backup = backups[-1]
        changes = {}
        for name, entry in json.loads((backup / "index.json").read_text()).items():
            current = self.read(name)
            if (sha(current[0]) if current else None) != entry["after"]:
                raise ValueError(f"El archivo cambió desde el respaldo: {name}")
            changes[name] = None
            if "file" in entry:
                data = (backup / entry["file"]).read_bytes()
                if sha(data) != entry["sha"]:
                    raise ValueError(f"SHA-256 incorrecto en el respaldo: {name}")
                changes[name] = (data, entry["mode"])
        return changes


def main():
    actions = ("completa", "personalizada", "actualizar", "reparar", "restaurar", "desinstalar", "diagnostico")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", nargs="?", choices=actions)
    parser.add_argument("--componentes", nargs="+", choices=COMPONENTS)
    parser.add_argument("--atajos", action="store_true")
    parser.add_argument("--inicio-automatico", action="store_true")
    parser.add_argument("--paquetes", action="store_true")
    parser.add_argument("--skwd-paquetes", type=Path, metavar="DIRECTORIO")
    parser.add_argument("--confirmar", action="store_true", help="Autoriza el plan de archivos; los paquetes requieren confirmación propia")
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error("Ejecuta el instalador con tu usuario normal")
    try:
        if not args.action:
            for number, action in enumerate(actions, 1):
                print(f"{number}. {action}")
            choice = input("Elige una opción o Enter para cancelar: ")
            if not choice:
                return
            if not choice.isdigit() or not 1 <= int(choice) <= len(actions):
                raise ValueError("Opción inválida")
            args.action = actions[int(choice)-1]
            if args.action in {"completa", "personalizada"}:
                args.atajos = input("¿Integrar atajos en Hyprland? [s/N] ").lower() == "s"
                args.inicio_automatico = input("¿Configurar arranque automático? [s/N] ").lower() == "s"
        if args.skwd_paquetes and not shutil.which("bsdtar"):
            raise ValueError("Hace falta bsdtar para importar paquetes de Skwd")
        if args.action == "diagnostico":
            preflight(["rory"], False)
            return
        install = Installation(Path.home())
        if args.action == "restaurar":
            changes = install.restoration()
        elif args.action == "desinstalar":
            changes = install.plan([], (False, False))
        else:
            if args.action in {"actualizar", "reparar"}:
                selected = install.old.get("components", [])
                if not selected:
                    raise ValueError("No hay una instalación administrada")
                integration = tuple(install.old["integration"])
            else:
                selected = list(COMPONENTS) if args.action == "completa" else args.componentes
                if not selected:
                    desired = input("Componentes (" + ", ".join(COMPONENTS) + "): ").split()
                    if not desired or any(item not in COMPONENTS for item in desired):
                        raise ValueError("Selección inválida")
                    selected = desired
                integration = (args.atajos, args.inicio_automatico)
            selected = list(dict.fromkeys(selected))
            preflight(selected, args.paquetes)
            changes = install.plan(selected, integration, repair=args.action == "reparar", skwd_packages=args.skwd_paquetes)
        print(f"Plan: {len(changes)} archivos; se generará un respaldo con SHA-256.")
        for name, payload in changes.items():
            print("Guardar " if payload else "Retirar ", name)
        if not args.confirmar and input("¿Aplicar el plan? [s/N] ").strip().lower() != "s":
            print("Operación cancelada.")
            return
        install.transact(changes)
        print("Operación aplicada. Las sesiones en ejecución conservan su estado hasta que las recargues.")
    except (OSError, ValueError, EOFError, subprocess.SubprocessError) as error:
        parser.exit(1, f"Rory: {error}\n")


if __name__ == "__main__":
    main()
