# Auditoría de la distribución preliminar

El alcance reúne el árbol modular público existente y el código activo autorizado de Rory. El origen privado, su historial, la instalación activa y los respaldos previos quedan fuera del árbol público.

## Inventario y estado

| Módulo | Comprobación y estado |
|---|---|
| RoryBar, Crimson y barras modulares | Lógica, rutas, perfiles y componentes aprobados offscreen. Pendiente de validación en una sesión Wayland real en el árbol público. |
| Sakura y recursos | Recursos originales de la variante pública. Carga y 30 ciclos de emisión/cancelación aprobados offscreen. Falta validar composición y estilo en Wayland. |
| Reloj, visualizadores y perfiles | Pruebas de configuración y persistencia aprobadas. Falta ejercicio de ratón, audio en vivo y cambio real de fondos en esta distribución. |
| Notificaciones, batería y multimedia | Pruebas de interfaz y rutas aprobadas con datos de prueba. D‑Bus, UPower, MPRIS y KDE Connect reales pendientes. |
| Red, Bluetooth, volumen, brillo y grabación | Se conserva el código de integración. Depende de hardware y servicios. Pendiente de validar sobre el escritorio. |
| Capturas y grabación base | Se conservaron scripts y se habilita la integración de captura por consentimiento. Pendiente de captura real. |
| Crimson Noir | Incluido con sus componentes y licencia. La interfaz y la integración manual de Super solo quedan pendientes de prueba real. |
| Infinite Desktop | Incluido con scripts y módulo Lua. Activación manual tras revisar conflictos. Pendiente de prueba real. |
| Skwd-wall, Deck y Paper | Integración y plantilla incluidas. Binarios externos verificables con SHA‑256. Importación de los paquetes reales y arranque pendientes. |
| Instalador y fondo de atajos | Instalación completa de archivos, personalizada, cancelación, actualización, reparación, restauración y desinstalación probadas en destinos temporales. Conflictos, reversión tras fallo y generación dinámica probados mediante datos de prueba. Aplicación del fondo, su restauración visual y arranque automático reales pendientes. |

## Superficies y dependencias

- La sesión de referencia tiene Hyprland 0.56.2, Quickshell 0.3.1, Qt 6.11 y Python 3.14 en Manjaro. Arch y CachyOS son candidatos. No se ha comprobado la instalación en ellos.
- Los archivos de entrada QML, módulos JS, helpers Python/Shell, temas, capas, perfiles de código, ejemplos Lua y unidad de usuario se incluyen en sus árboles modulares.
- Servicios de sesión y hardware se detectan o utilizan al ejecutar sus módulos. Consulta [dependencias](installer/dependencies.json) y [guía manual](docs/INSTALACION-MANUAL.md).
- El instalador opera como usuario. `sudo pacman` se invoca únicamente ante una confirmación independiente. No habilita servicios, cambia permisos de dispositivos ni instala el compositor.
- La integración de atajos comprueba las combinaciones que informa Hyprland. Funciones de Super solo dependen de eventos que esa lista puede omitir y se dejan a integración manual.

## Exclusiones y revisión

Se excluyeron historiales privados, INI y asociaciones personales, credenciales, archivos de sesión, cachés, copias de respaldo, recursos gráficos de procedencia no autorizada y medios personales o de terceros. Los SVG preexistentes en `assets/` continúan excluidos. La nueva ornamentación de distribución utiliza trazados propios. Los paquetes, bibliotecas y fuentes de Skwd-wall permanecen externos. No se publican capturas sin autorización.

La auditoría automatizada comprueba rutas personales, extensiones sensibles y patrones de claves y tokens. Las coincidencias de ejemplo o de implementación se revisan por contexto. El control se complementa con revisión del índice y de las licencias por componente.

Infinite Desktop usa `python-evdev` para el modo que lee dispositivos de entrada.
Su estado temporal queda bajo `XDG_RUNTIME_DIR`. El instalador no otorga acceso a
dispositivos ni cambia grupos. La navegación y sus permisos se deben validar en
la sesión del usuario.

Repite la revisión del índice con `python3 installer/audit-index.py`. Para una
prueba de instalación sin archivos locales adicionales, exporta ese índice con
`git checkout-index --prefix="$directorio_temporal/" -a` y ejecuta
`python3 -m unittest discover -s tests` en la copia resultante.
