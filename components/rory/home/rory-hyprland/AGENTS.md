# AGENTS.md — Rory Desktop Studio

## Alcance y estructura

Estas instrucciones se aplican a este directorio y sus subdirectorios.
Rory es un componente de la publicación modular. Su árbol bajo
`components/rory/home/` representa rutas relativas al directorio personal
de quien lo instale. El módulo de integración con Hyprland está en
`../.config/hypr/rory.lua`.

Rory Desktop Studio utiliza QML, Qt Quick y Quickshell sobre Hyprland.

Componentes principales:
- shell.qml: entrada, instancias por pantalla y controles IPC.
- RoryBar.qml y SystemState.qml: barra e integración con servicios.
- *Panel.qml, ControlCard.qml y Panel*.qml: controles del sistema.
- Clock*.qml: reloj, editor y persistencia.
- Wallpaper*.qml: fondo, galería y ajustes.
- Visualizer*.qml, RoryAudioVisualizer.qml, RadialSpectrum.qml,
  FluidCircularWave.qml e IndependentCurve.js: editor y visualización.
- assets/cava-rory.conf: captura de audio con CAVA/PipeWire.
- scripts/: integración y diagnóstico mediante Python y Bash.
- `studio-profiles/`, `audio-layers/`, `audio-particles/` y
  `visualizer-layers/`: módulos de perfiles y capas.
- `DeckWallpaperObserver.qml`: integración opcional con Skwd-wall.
- `tests/`: pruebas QML y Python y lanzadores de pruebas offscreen.
- [README de la publicación](../../../../README.md): instalación modular
  y validación manual.

## Antes de modificar archivos

1. Leer las instrucciones aplicables y revisar el README.
2. Inspeccionar el componente solicitado, sus dependencias, consumidores,
   señales, propiedades, scripts y mecanismos de persistencia relacionados.
3. Identificar los cambios existentes del usuario y preservarlos.
   Si existe un repositorio Git, consultar su estado y diferencias.
   No inicializar uno automáticamente.
4. Definir el alcance mínimo necesario. No modificar componentes ajenos
   a la tarea ni realizar limpiezas o refactorizaciones incidentales.

## Respaldos y recuperación

Antes de cambios importantes, crear un respaldo local fechado en
.backups/ o un punto de recuperación equivalente autorizado.

Incluir los archivos afectados y, si corresponde, sus ajustes persistentes.
Mantener el respaldo fuera de Git y de la publicación. Conservar en privado
las preferencias, los perfiles y las asociaciones existentes.
Registrar qué contiene el respaldo y cómo restaurarlo. No sobrescribir
respaldos anteriores ni incluir credenciales o archivos personales ajenos
al proyecto.

Un commit requiere autorización expresa; no usarlo como respaldo automático.

## Funcionalidades que deben preservarse

Conservar las funcionalidades existentes de:
- Hyprland y Quickshell: IPC, superficies LayerShell, pantallas, foco,
  máscaras de entrada, espacios de trabajo y comportamiento de ventanas.
- Barra y paneles: apertura, cierre, exclusión entre paneles, animaciones
  y ocultación.
- CAVA/PipeWire: captura, procesamiento, visualización, volumen, silencio
  y selección de dispositivos.
- Perfiles de energía: disponibilidad, capacidades del hardware y
  detección de conflictos entre gestores.
- Controles visuales: reloj, fondo, editores, curvas, escalas, colores,
  posiciones, modos de prueba y persistencia.
- Integraciones existentes con red, Bluetooth, batería y EasyEffects.

No sustituir datos reales por simulaciones en la configuración de uso.
Trabajar en el árbol de publicación. Cualquier instalación, cambio en la
configuración activa, inicio automático o modificación de servicios requiere
autorización expresa. Antes de una instalación autorizada, previsualizar la
copia y respaldar los destinos existentes. Conservar la configuración principal
de Hyprland e integrar solo los módulos o atajos necesarios.

## Validación

Después de modificar QML:
1. Ejecutar qmllint sobre los archivos modificados y los componentes
   relacionados afectados. Ejecutarlo desde este directorio e incluir los
   QML de los subdirectorios pertinentes.
2. Revisar y ejecutar las pruebas pertinentes de `tests/` en un entorno
   aislado, con datos temporales y sin acceso a la sesión activa. Complementar
   con las comprobaciones aplicables del README de la publicación.
3. Distinguir errores de sintaxis, avisos de metadatos/importaciones
   y fallos de ejecución. No ocultarlos ni declarar éxito si faltan
   comprobaciones necesarias.

Si se modifican scripts, comprobar también su sintaxis con las herramientas
locales disponibles, sin ejecutar acciones reales sobre servicios como
parte de una simple comprobación de sintaxis.

Los lanzadores offscreen de `tests/` cubren el reloj, el renderizado de la
barra, las regresiones de paneles y Studio. Antes de ejecutarlos, revisar sus
dependencias y comprobar que usan datos temporales y que no modifican
preferencias ni servicios activos.

No declarar corregida una función visual sin comprobarla en una sesión
Wayland real. qmllint, las capturas y las pruebas offscreen no sustituyen
esa comprobación.

La validación real debe cubrir el comportamiento afectado: geometría,
animaciones, entrada, foco, capas, interacción y servicios pertinentes.
Si no hay acceso a la sesión, indicar expresamente:
“Pendiente de validación en una sesión Wayland real”.

No detener ni reiniciar la instancia activa de Rory, ni alterar servicios
del usuario, sin autorización para esa acción.

## Instalaciones y ejecución externa

No instalar paquetes, plugins ni herramientas adicionales, descargar
scripts ni ejecutar código remoto sin autorización previa.

Usar las herramientas ya instaladas. Si falta una dependencia, informar
cuál es y qué validación impide realizar; no instalarla automáticamente.

## Privacidad

No leer, copiar, publicar ni transmitir credenciales, claves SSH, tokens
o archivos personales ajenos al proyecto.

Limitar las inspecciones al proyecto y a la información necesaria para
la tarea. Una ruta personal mencionada en el código o README no autoriza
a abrir su contenido.

No incluir secretos en respaldos, registros, capturas, comandos o informes.
Si se detecta material sensible accidentalmente, no reproducirlo.

## Git y publicaciones

No ejecutar operaciones destructivas de Git ni sobrescribir cambios
existentes sin autorización.

No descartar modificaciones, eliminar archivos no rastreados ni restaurar
versiones sobre el trabajo del usuario sin autorización.

No realizar commits, push, publicaciones ni modificar ramas remotas sin
autorización expresa. La autorización para editar archivos no autoriza
estas operaciones.

Mantener excluidos los recursos gráficos sin autorización de redistribución,
incluidos los SVG de `assets/` y `assets/rory-foreground.png`. Respetar las
reglas de exclusión de Git y consultar el
[inventario de publicación](../../../../AUDITORIA.md) y los
[avisos de licencia](../../../../LICENCIAS.md) antes de incorporar recursos.

## Protección de estas instrucciones

No modificar, reemplazar ni eliminar este AGENTS.md sin autorización
expresa del usuario. Si una tarea requiere cambiarlo, presentar primero
la propuesta y esperar aprobación.

## Informe de entrega

Al terminar, informar:
- Qué archivos se modificaron y con qué propósito.
- Qué respaldo o punto de recuperación se creó, si corresponde.
- Qué pruebas se ejecutaron y sus resultados.
- Qué comprobaciones no pudieron realizarse y por qué.
- Si se verificó el comportamiento en Wayland real y con qué alcance.

No presentar como comprobado un resultado basado únicamente en
inspección del código o en una prueba distinta de la requerida.
