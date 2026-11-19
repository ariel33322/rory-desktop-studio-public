# Inventario de publicación y restauración

Inspección local del 18 de noviembre de 2026. El contenido activo se guardó por separado en un respaldo privado con manifiesto y SHA-256. La exportación modular conserva los archivos de trabajo y excluye los historiales de origen. El código original de Rory y Crimson Noir se incluye bajo MIT. Los recursos gráficos de redistribución no autorizada quedan fuera.

| Componente | Origen y estado | Candidato para publicar |
|---|---|---|
| Integración Lua, capturas, grabación | `.config/hypr/hyprland.lua`, `infinite-desktop.lua`, `screen-record.py` y enlace `screenshot.py` a `scripts/screenshot.py`. `.config/hypr-personal/crimson-noir.lua` contiene el ajuste de Super. | Código de integración y scripts, con los avisos correspondientes a las fuentes reutilizadas. El archivo conserva bloques del ejemplo de Hyprland instalado en `/usr/share/hypr/hyprland.lua`. Incluir el aviso BSD-3-Clause del ejemplo. [Licencia de Hyprland 0.56.2](https://github.com/hyprwm/Hyprland/blob/v0.56.2/LICENSE). Documentar o parametrizar los destinos del HDD en la futura copia pública. |
| Infinite Desktop | Git propio, base `38da6c85d729a310f34bba38df6689b87ee364d2`. `bin/` contiene las versiones activas y no está rastreado en ese repositorio. | Código bajo MIT con el aviso de Sarods2D. Exportar explícitamente los Python de `bin/` y revisar atribución de cambios locales. El zoom adapta la técnica de DarkShadowShell, cuyo repositorio usa MIT. Conservar el crédito y el aviso si se incorporan fragmentos. [Licencia de DarkShadowShell](https://github.com/shadowww-dev/DarkShadowShell/blob/main/LICENSE). [Upstream y licencia](https://github.com/sarodscommits/hyprland-infinitie-desktop-v2). |
| Rory Desktop Studio | Git propio, base `d773dab7cb5a872f1b987426f7e26570cfb932a6`. Hay nueve archivos rastreados modificados y un observador QML nuevo requerido en ejecución. La auditoría local no encontró licencia en el árbol ni pudo verificar el remoto. | Código original MIT, 2026 ariel33322. La exportación conserva código, cambios locales, módulos y pruebas. Los SVG y el PNG `assets/rory-foreground.png` siguen excluidos. Las preferencias y asociaciones quedan privadas. |
| Crimson Noir | `crimson-noir/` contiene el teléfono y selector activos, además de shells auxiliares de dock y tablet. Sin repositorio Git propio identificado. | Código original MIT, 2026 ariel33322. La tablet resuelve las carpetas mediante XDG. Las referencias visuales e iconos con derechos pendientes quedan fuera. Los iconos usados desde temas instalados deben quedar como dependencias. |
| Skwd-wall y familia | Despliegue aislado en `.local/share/rory-deck-native/` con servicio de usuario, binarios y avisos. El selector, Deck y Paper coinciden byte por byte con la extracción local de beta.29. La release está fijada a `92202807ba4edc239ef723edeed2026b832bbc62`. | Publicar el lanzador y unidad tras revisión de autoría, y una plantilla de configuración despersonalizada. Enlazar la release. Redistribuir código original MIT con sus avisos si se decide incluirlo. Mantener los avisos respectivos de fuentes, iconos y dependencias. Si se empaquetan binarios, revisar además LGPL y entrega de fuentes de FFmpeg, y el resto de avisos de los paquetes. [Release oficial](https://github.com/liixini/skwd-wall/releases/tag/v1.0.0-beta.29). |

## Fuentes de Skwd y equivalencia

La copia de fuentes de Wall en `skwd-wall-lab/source` es un checkout Git en `04344fc867f52d5a124d6ac8acad5ad984b91700`. Hay checkouts separados de Deck `2f7ea97a6e3a9c3802696fa94313740da16c5303`, Paper `ab6d71d6abaeb0f519003c11ff968c9dc296ed11` y Lens `639736f2fbffd6797f9218af001eb7f438dad0ad` en `public-build/`. Se encontraron textos MIT para el código original y licencias separadas para terceros. Los pins públicos de esas dependencias difieren de los del CI histórico. Por ello, la receta comprobable para recuperar la interfaz y optimizaciones instaladas parte del despliegue privado o de los paquetes oficiales identificados por hash. La compilación experimental, los parches de laboratorio y sus pruebas no forman parte de la configuración activa. [Licencias de Skwd-wall](https://github.com/liixini/skwd-wall/blob/v2/LICENSING.md).

El respaldo conserva UI, recursos instalados, `control`, servicio, árbol `config/`, marcador `picker-bc` y bibliotecas y enlaces de Paper. La biblioteca de Skwd se vuelve a poblar desde medios proporcionados localmente. El estado que se genera al iniciar Hyprland se recrea.

## Revisión de privacidad

- Revisé texto de configuración y código con búsquedas de credenciales y rutas. No encontré coincidencias con patrones de claves privadas, tokens GitHub/AWS o credenciales literales de las formas buscadas. Es una comprobación heurística del contenido seleccionado. El alcance de historial se detalla abajo.
- Excluir las preferencias privadas `.*-settings.ini`, perfiles y asociaciones de Rory, así como el JSON activo de Skwd-wall. El JSON incluye rutas de biblioteca, carpetas excluidas y el fondo configurado. Revisar asimismo las rutas de la tablet de Crimson Noir, el directorio personal en documentos de desarrollo y los identificadores de Git antes de cualquier publicación.
- Excluir bases SQLite, WAL/SHM, sesión generada, cachés y miniaturas, logs, respaldos previos, capturas, grabaciones, fondos, videos, música, directorios personales y cualquier material del HDD. Conservar los recursos gráficos de la interfaz en privado hasta verificar su licencia.
- Excluir paquetes, compilaciones y binarios del borrador público. El despliegue nativo ocupa aproximadamente 167 MiB antes de comprimir. El árbol de compilación de pruebas ocupa alrededor de 2 GiB. El respaldo privado conserva el despliegue nativo restaurable, con licencia y bibliotecas.
- Las licencias del código original se aplican por componente. Los avisos de terceros se conservan y los recursos gráficos sin autorización continúan excluidos.

## Límites de la restauración

El respaldo reproduce los archivos seleccionados y enlaces, no el contenido de las unidades montadas ni la caché o base de la biblioteca. Los perfiles y asociaciones privados pueden guardar referencias a medios que deberán proporcionarse por separado. La portabilidad depende de los paquetes, permisos de entrada, GPU y monitor registrados en el README. La sesión activa no se reinició. En el entorno de auditoría, el HDD aparece montado en solo lectura y las consultas a Hyprland no tienen acceso a su socket.

## Historial revisado en la segunda etapa

Se revisaron las revisiones alcanzables desde las referencias locales y HEAD, rutas de archivos, metadatos de autoría y coincidencias de texto con patrones de secretos. Las exportaciones conservan archivos de trabajo y excluyen el historial original.

| Historial | Hallazgos |
|---|---|
| Rory Desktop Studio, 4 commits | Una identidad de correo en metadatos, ruta absoluta privada en `AGENTS.md` y ocho gráficos versionados con derechos pendientes. `AGENTS.md` y esos recursos quedaron fuera de la exportación. |
| Infinite Desktop, 36 commits | Dos identidades de correo en metadatos. `scripts/files.zip` está versionado e incluye copias de código/documentación, y también existe un ZIP local en `bin/`. Ambos quedan fuera. |
| Skwd Wall, Deck, Paper, Lens y checkout experimental | Cinco checkouts superficiales, un commit disponible por checkout. Se localizaron rutas de ejemplo en pruebas, coincidencias de red en pruebas o dependencias y fotografías integradas en Deck. La exportación remite a la release para el binario y conserva avisos MIT. Estas copias superficiales no permiten auditar revisiones anteriores. |
| Crimson Noir y configuración base | Sin historial Git de origen identificado. Se revisaron los archivos de trabajo seleccionados. |

No aparecieron coincidencias con los patrones de secretos usados sobre los historiales disponibles. Los correos de autoría siguen en los repositorios de origen. Para importar historiales completos en el futuro, revisar las identidades y la procedencia de archivos históricos antes de hacerlo.

## Recursos gráficos ausentes de la copia pública

- Rory `assets/` excluye `cresta.svg`, `esquina.svg`, `floral-center.svg`, `floral-corner.svg`, `floral-leaf.svg`, `floral-petal.svg`, `panel-rose.svg` y `rory-foreground.png`. La copia conserva las referencias decorativas para que puedan satisfacerse con archivos propios autorizados. `cava-rory.conf` sí se conserva.
- Crimson Noir conserva referencias a iconos del sistema y los fallbacks de su tablet. Quedan fuera imágenes de referencia y logotipos no autorizados. El dock y la tablet son auxiliares y no tienen arranque automático.
- Skwd-wall conserva la interfaz a través de la release oficial. El árbol público excluye imágenes de Deck, ejecutables y bibliotecas empaquetadas. El ejemplo JSON conserva el diseño y los ajustes reutilizables después de retirar fondos, biblioteca y asociaciones de monitor. Las plantillas Matugen de la instalación exacta siguen en el respaldo privado.

## Verificación de la exportación

Se verificó la sintaxis de Lua, Python, JSON y el lanzador Bash, los dos QML que se adaptaron a rutas portables, los avisos y las reglas Git de exclusión. Se copiaron los cinco árboles por separado a destinos temporales y se comprobó el enlace de captura. Los demás QML se conservaron byte por byte. El formateador Qt local no aceptó varios de esos archivos sin cambios y llegó a fallar con un error interno en uno. La ejecución y apariencia de la variante completa siguen pendientes de validación en Wayland.
