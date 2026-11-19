# Escritorio Hyprland para Manjaro

Configuración Lua modular para Hyprland 0.56.2. **Versión experimental.** Puedes restaurar cada componente por separado. Falta validar por completo el arranque y el comportamiento en una sesión Wayland real.

El código original de Rory Desktop Studio y Crimson Noir se distribuye bajo MIT. Consulta los [avisos de licencia](LICENCIAS.md) y el [inventario de recursos excluidos](AUDITORIA.md).

## Dependencias

El equipo de referencia usa Hyprland 0.56.2-4, Quickshell 0.3.1-1, Qt Declarative 6.11.2-2, Python 3.14.7-1 y GPU Screen Recorder 6.1.3-1. En Manjaro instala versiones compatibles desde los repositorios que correspondan a tu sistema.

| Componente | Dependencias |
|---|---|
| Base y capturas | `hyprland`, `python`, `grim`, `slurp`, `wl-clipboard`, `libnotify`, `util-linux`, `brightnessctl` y `wireplumber`. Para los lanzadores, Ghostty, Dolphin y Brave o tus alternativas. |
| Grabación | `gpu-screen-recorder`, PipeWire con `pipewire-pulse` y un controlador VA-API que codifique H.264 por hardware. Comprueba `gpu-screen-recorder --help` y `--list-capture-options`. |
| Infinite Desktop | `python-evdev`, `jq` y acceso a los dispositivos de entrada. En el equipo de referencia se concede mediante el grupo `input`, que también permite leer eventos de teclado. Inicia sesión de nuevo tras cambiar la pertenencia al grupo. |
| Rory Desktop Studio | `quickshell`, `qt6-declarative`, `cava`, `pipewire` y `python`. Para las integraciones que uses, `networkmanager`, BlueZ, `power-profiles-daemon` y `easyeffects`. |
| Crimson Noir | `quickshell`, `qt6-declarative`, `xdg-utils`, `xdg-user-dirs` y temas de iconos instalados. La tablet auxiliar usa `playerctl`. |
| Skwd-wall | Wall, Deck y Paper **v1.0.0-beta.29**, Vulkan y el controlador de tu GPU. En el equipo Intel se usa `vulkan-intel`. Se incluye una unidad para systemd de usuario. |

Instala `rsync` si vas a usar los ejemplos de copia. La salida, versiones y atajos activos se pueden revisar con `hyprctl -j monitors`, `pacman -Q` y `hyprctl binds` desde la sesión gráfica.

## Copiar y configurar

Cada directorio `components/<componente>/home/` contiene rutas relativas a tu directorio personal. Antes de copiar, respalda los destinos que ya existan. En el directorio de este proyecto, previsualiza cada componente y luego repite el comando sin `-n` cuando apruebes la lista:

```sh
component=base
rsync -ani --no-perms --omit-dir-times "components/$component/home/" "$HOME/"
```

La base carga los módulos opcionales instalados bajo `~/.config/hypr/`. Si ya tienes otra configuración Lua, conserva tu archivo principal. Copia lo necesario desde el componente y añade una llamada al módulo correspondiente o copia solamente los `hl.bind` que quieras. Comprueba conflictos con `hyprctl binds`. Ajusta los atajos en el módulo que los define y recarga con `hyprctl reload`. Abre una sesión nueva para comprobar los ganchos de inicio.

| Directorio | Restauración independiente |
|---|---|
| `base` | Copia el árbol base. Super+1–0 cambia de escritorio y Super+Shift+1–0 mueve la ventana activa. Mantiene Super+arrastre izquierdo/derecho y los atajos multimedia. Configura la unidad de capturas como se indica abajo. |
| `infinite-desktop` | Copia `home/` y carga `~/.config/hypr/infinite-desktop.lua`. Usa los scripts de `~/Infinite-Desktop/bin/`. Super+D alterna mosaico/flotante, Super+flechas navega, Super+Alt+ratón desplaza y Ctrl+rueda ajusta el zoom en flotante. |
| `rory` | La copia conserva QML, JS, scripts y el observador de Deck. Carga `~/.config/hypr/rory.lua` o inicia manualmente con `qs -n -d -p "$HOME/rory-hyprland/shell.qml"`. Super+P abre el editor de audio. El observador integra los fondos de Skwd-wall cuando Deck está presente. Las decoraciones excluidas y los perfiles privados requieren una copia propia autorizada. |
| `crimson-noir` | La copia incluye el teléfono, selector de fondos y detector Lua. Carga `~/.config/hypr/crimson-noir.lua`. Super sola alterna el teléfono al soltarla antes de 1000 ms. El dock y la tablet se guardan como QML auxiliares, sin autoinicio. El dock hace referencia a `media-info.sh` y `cava.conf`, que no se encontraron en su carpeta activa. |
| `skwd-wall` | Copia el lanzador, unidad y módulo según el apartado siguiente. El selector completo se recupera de los paquetes oficiales, y Super+W lo abre desde su módulo. Puede ejecutarse con `control picker` sin instalar Rory. |

### Skwd-wall

1. Descarga los tres paquetes x86_64 de la [release oficial v1.0.0-beta.29](https://github.com/liixini/skwd-wall/releases/tag/v1.0.0-beta.29). Comprueba sus SHA-256 con `components/skwd-wall/home/.local/share/rory-deck-native/provenance.txt`.
2. Extrae cada paquete por separado en un directorio temporal con `bsdtar -xf`. Integra sus árboles `usr/` en `~/.local/share/rory-deck-native/usr/`, conservando los enlaces de Paper, los recursos de la interfaz y los avisos de terceros.
3. Copia `config/config.example.json` a `config/config.json` dentro de ese mismo despliegue si aún no existe. Define las carpetas de fondos desde el selector o en `library.folders`. El ejemplo conserva el diseño guardado del selector, su animación y los ajustes de rendimiento. La geometría asociada al monitor y el fondo personal se configuran en el equipo receptor. Para Matugen, instala sus dependencias y aporta las plantillas de la distribución o tus propias plantillas autorizadas.
4. Ejecuta `systemctl --user daemon-reload`. En Hyprland inicia el Deck con `"$HOME/.local/share/rory-deck-native/control" start` o entra en una sesión nueva con el módulo cargado. El lanzador usa el ICD Intel cuando está disponible y admite `VK_DRIVER_FILES`. El perfil de miniaturas base es RGBA y el marcador `picker-bc` selecciona BC para el selector. Conserva ese marcador si reproduces la instalación de referencia.

### Capturas y grabación

En `~/.config/hypr/hyprland.local.lua` puedes añadir, por ejemplo:

```lua
hl.env("HYPR_CAPTURE_MOUNT", "/mnt/captures")
hl.env("HYPR_SCREENSHOT_DIR", "Screenshots")
hl.env("HYPR_RECORDING_DIR", "Recordings")
hl.env("HYPR_RECORDING_MONITOR", "eDP-1")
```

Monta el destino con escritura y crea ambas carpetas dentro de él. Sin el monitor explícito, se usa el enfocado para pantalla completa y para delimitar la selección de región. Las capturas de ventana y sus grabaciones usan la ventana activa. La grabación captura el rectángulo inicial, incluso si la ventana se mueve o queda tapada. Los scripts cancelan si el destino falla.

- **Print**, **Shift+Print**, **Super+Print** capturan región, pantalla y ventana.
- **Ctrl+Alt+R**, **Shift+Alt+Print**, **Ctrl+Shift+Print** graban monitor, región de ventana y región con Slurp. Cualquiera detiene y guarda la grabación en MP4, H.264 por GPU a 60 FPS, con audio del sistema.

Para reproducir exactamente las preferencias, rutas y decoración locales, usa el respaldo privado con su manifiesto y sumas. Verifica con `sha256sum -c SHA256SUMS`, extrae en un directorio temporal y compara antes de copiar. Los medios personales se recuperan por separado. La ejecución de esta variante queda pendiente de verificar en una sesión Wayland real.
