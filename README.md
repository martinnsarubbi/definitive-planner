# Definitive Planner

Agenda modular en **Flutter / Dart** para iPhone, iPad, Android, web, Windows y macOS. Primera implementación local inspirada en las funciones públicas de Whatting, con código, plantillas y diseño propios.

## Qué podés usar

- Páginas por fecha; calendario y navegación diaria; vista general y búsqueda de texto/etiquetas.
- Tablero adaptable de una, dos o tres columnas. Agregar, reordenar con el asa de arrastre, cambiar ancho/alto, duplicar, copiar a otra fecha y eliminar widgets. Deshacer/rehacer cambios de estructura.
- Notas Markdown con varias páginas, vista previa y enlaces web.
- Tareas con completado y prioridad; agenda con eventos/horas; planificador semanal editable.
- Registro de ánimo y reflexión; hábitos compartidos entre páginas, marcas por fecha y hora de registro.
- Pomodoro (25 minutos de foco, descansos de 5/15), pausa, reinicio y sesiones completadas. El plazo se conserva al navegar o recargar; no hay notificaciones del sistema en segundo plano.
- Dibujo con dedo, lápiz o mouse, colores/grosor y deshacer/rehacer trazos.
- Fotos locales y leyendas (hasta 1 MB por imagen); reseñas con valoración; cuenta regresiva.
- Stickers emoji: arrastrar, doble toque para cambiar tamaño y mantener presionado para girar/eliminar.
- Cuatro plantillas propias y guardado de plantillas personales con contenido. Aplicarlas agrega widgets sin borrar la página actual.
- Modo enfoque, tema claro/oscuro y cuatro acentos. Estilos centralizados en `lib/theme/app_theme.dart`.
- Persistencia local, exportación/importación JSON con validación y confirmación antes de reemplazar datos. Los errores de lectura/guardado se muestran en pantalla.

No se presenta como paridad completa con Whatting. La [investigación funcional](docs/whatting-research.md) enumera la fuente y las funciones pendientes: sincronización, integraciones nativas, editor avanzado de stickers, video, mapas, clima y música, entre otras. Whatting ya anuncia un habit tracker; esta base incluye seguimiento diario simple para ampliarlo después.

## Desarrollo

Versión probada: Flutter **3.47.6**, Dart **3.13.5**. SDK fijado en `.flutter-version`, dependencias en `pubspec.lock`.

Con Flutter instalado en tu máquina:

```bash
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter run -d chrome
```

En este entorno cloud (Linux, directorio personal de solo lectura):

```bash
cd /workspace/definitive-planner
./tool/setup_cloud.sh
./tool/flutterw analyze
./tool/flutterw test
./tool/flutterw run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

El wrapper guarda las cachés bajo `/workspace/.toolchains`, configura Chromium y evita escrituras en el directorio personal. No modifica `HOME`. Cada tarea cloud ya está aislada: usar este checkout, sin crear worktrees salvo pedido explícito.

Para compilar y servir la versión web de producción localmente:

```bash
./tool/flutterw build web --release --no-web-resources-cdn
python -m http.server 8765 --bind 127.0.0.1 --directory build/web
```

El servidor es para desarrollo/verificación local. Publicar en producción requiere servir `build/web` por HTTPS. No se ha desplegado públicamente.

## Plataformas

| Destino | Proyecto | Verificación / requisitos |
| --- | --- | --- |
| Web | `web/` | Compilación release y comprobación en Chromium en este entorno |
| iPhone / iPad | `ios/` | Generado; requiere macOS, Xcode y firma para dispositivo/distribución |
| Android | `android/` | Generado; requiere SDK Android/JDK y configuración de firma release |
| Windows | `windows/` | Generado; requiere Windows y Visual Studio con herramientas C++ |
| macOS | `macos/` | Generado; requiere macOS/Xcode; permisos de archivos elegidos por el usuario configurados |

Los proyectos nativos todavía no han sido compilados o probados en dispositivos. El ID de aplicación y los iconos son provisionales. Las credenciales de distribución y las firmas no están incluidas.

## Datos y límites de esta versión

`PlannerStorage` separa persistencia e interfaz. Actualmente usa `shared_preferences`: datos locales pequeños, sin cuenta ni servidor. No hay sincronización automática entre dispositivos. Para trasladar una agenda, exportar/importar desde **Personalizar**.

Las fotos se guardan dentro de la copia JSON. La capacidad depende de la plataforma/navegador; los errores por falta de espacio se informan y permiten exportar los cambios abiertos. La agenda y las importaciones se limitan a 12 MB; se rechazan los cambios que superan ese límite. No usar todavía como único archivo de fotos o documentos importantes. Borrar datos del navegador o desinstalar puede borrar la agenda. El siguiente paso de almacenamiento para colecciones grandes es una base local y archivos adjuntos separados, antes de implementar sincronización.

## Estructura

- `lib/models/`: documento versionado, widgets y cálculo del temporizador.
- `lib/data/`: repositorio local, historial y validación de copias.
- `lib/widgets/`: navegación, tablero y editores.
- `lib/theme/`: colores, espaciado, bordes y tipografía.
- `test/`: persistencia, recuperación ante errores e interacción de UI.
- `tool/`: preparación reproducible del entorno cloud.

Para agregar un widget, declarar su tipo en `BlockKind`, su editor en `BlockContent`, icono en `editors.dart` y validación en `backup_validation.dart`. Un cambio incompatible de datos debe incluir una migración explícita de versión.

## Verificación en navegador

`tool/browser_smoke.cjs` usa Playwright y un Chromium instalado. Ejecutarlo con el servidor local anterior activo y Playwright disponible en Node (`npm install --prefix /tmp/planner-browser-check playwright`, y `NODE_PATH=/tmp/planner-browser-check/node_modules node tool/browser_smoke.cjs` si hace falta). Usa un perfil temporal independiente, no los datos personales del navegador. Crea y completa una tarea, recarga, aplica una plantilla, exporta/restaura una copia y prueba navegación móvil. `PLANNER_URL` y `CHROME_EXECUTABLE` permiten configurar URL y navegador.

La fuente de emojis se distribuye con su licencia en `assets/fonts/`, para evitar descargas externas de los stickers y estados de ánimo incorporados.
