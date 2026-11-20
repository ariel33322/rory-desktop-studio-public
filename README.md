# Rory Desktop Studio

Rory Desktop Studio reúne una barra para Hyprland, editores visuales y herramientas de escritorio para Wayland. Esta rama prepara una **distribución preliminar**. La instalación por usuario se probó con un directorio personal vacío en Manjaro. La validación de una sesión Wayland de la copia pública, Arch y CachyOS sigue pendiente.

## Componentes

| Componente | Incluye |
|---|---|
| Rory | RoryBar, Crimson Control Center, batería, notificaciones, Sakura Pink, reloj individualizable, visualizadores radiales y lineales, perfiles y vinculación a fondos, barras modulares y Super+P. |
| Base | Herramientas de captura y grabación y un ejemplo de Hyprland Lua. |
| Crimson Noir | Shell, dock, tablet auxiliar y el módulo opcional de Super solo. |
| Infinite Desktop | Navegación, disposición flotante, zoom y configuración de ejemplo. |
| Skwd-wall | Lanzador, unidad de usuario, configuración inicial y procedencia de los paquetes oficiales opcionales. |

Los recursos originales de la distribución están en `components/rory/home/rory-hyprland/art/`. Las imágenes y los fondos personales se eligen después de instalar. Las capturas de esta variante quedan pendientes de una sesión real y de autorización para compartirlas.

## Instalación

Punto de referencia comprobado en Manjaro con Hyprland 0.56.2, Quickshell 0.3.1, Qt Declarative 6.11 y Python 3.14. Python 3.11 o posterior es necesario para el instalador. Consulta el [manifiesto de dependencias](installer/dependencies.json) y la [auditoría](AUDITORIA.md) antes de usar otra distribución.

```sh
python3 install.py diagnostico
python3 install.py
```

El menú ofrece instalación completa o personalizada, actualización, reparación, restauración y desinstalación. Las operaciones muestran el plan y solicitan confirmación. La instalación completa copia todos los módulos de la distribución y deja los binarios externos de Skwd-wall opcionales. Para importar sus paquetes, descarga los tres archivos x86_64 de la [release oficial](https://github.com/liixini/skwd-wall/releases/tag/v1.0.0-beta.29) y especifica su directorio. El instalador verifica sus hashes antes de extraerlos.

```sh
python3 install.py completa --skwd-paquetes /ruta/a/paquetes
python3 install.py personalizada --componentes rory base
```

El diagnóstico identifica el gestor de paquetes y muestra requisitos y utilidades opcionales. En Manjaro y otros sistemas con Pacman, `--paquetes` permite proponer e instalar dependencias obligatorias seleccionadas después de una confirmación propia. Instala y configura Hyprland por separado. Los servicios de red, Bluetooth, audio, batería y notificaciones dependen de tu sesión y de tu hardware.

### Inicio y atajos

```sh
qs -n -d -p "$HOME/rory-hyprland/shell.qml"
qs ipc -p "$HOME/rory-hyprland/shell.qml" call rory openStudio
```

`--atajos` y `--inicio-automatico` son optativos. La integración usa un módulo Lua administrado y conserva una copia del archivo principal. Revisa las colisiones con `hyprctl -j binds`. Con una colisión, la operación se detiene antes de modificar la configuración. Super+P abre Studio. Archivos con cambios externos y destinos preexistentes requieren revisión. El instalador no recarga Hyprland, inicia servicios ni adopta instalaciones existentes. Crimson Noir con Super solo e Infinite Desktop con sus eventos de ventana conservan módulos manuales para evitar interceptar teclas existentes. [Guía manual](docs/INSTALACION-MANUAL.md)

### Fondo de atajos

```sh
python3 shortcut-wallpaper.py aplicar
python3 shortcut-wallpaper.py conservar
python3 shortcut-wallpaper.py restaurar
```

El SVG negro se genera con los enlaces de Rory que Hyprland informa como activos. El fondo nativo guarda y restaura su imagen anterior. Si Deck gestiona el fondo o Rory se inicia con `RORY_EXTERNAL_WALLPAPER=1`, el cambio se rechaza. La guía se limita a atajos identificables en la lista de Hyprland. Los eventos como Super solo pueden quedar fuera.

### Mantenimiento

```sh
python3 install.py actualizar
python3 install.py reparar
python3 install.py restaurar
python3 install.py desinstalar
```

Los respaldos y el manifiesto viven en `~/.local/state/rory-desktop-studio/`. La restauración revierte la operación más reciente tras comprobar los hashes y el estado de los archivos. La desinstalación retira archivos administrados y conserva los perfiles, preferencias y medios del usuario. Se conservan las carpetas para que esos datos sigan accesibles. Si editaste archivos administrados, guarda tu copia y revisa el mensaje antes de reparar.

### Solución de problemas

- Si Studio no abre, inicia la instancia manualmente y consulta `qs log -p "$HOME/rory-hyprland/shell.qml"`. Comprueba Super+P con `hyprctl -j binds`.
- Si faltan barras de audio, comprueba CAVA y PipeWire. Para captura y grabación, comprueba las herramientas del manifiesto y tu portal o GPU.
- El centro de notificaciones puede recibir por D‑Bus si habilitas su receptor y el nombre está libre. Si ya tienes daemon, conserva su interfaz de historial. La lista de Rory vive en memoria.
- El brillo depende de una interfaz compatible con permisos normales. El instalador no modifica udev ni permisos del sistema.
- Si Skwd-wall no abre tras importar los paquetes, comprueba `systemctl --user status rory-skwd-deck.service` y la biblioteca de fondos. Para configurar la unidad y el despliegue consulta la guía manual.

[Auditoría de publicación](AUDITORIA.md) · [Licencias](LICENCIAS.md)
