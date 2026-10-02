# Validación de la primera versión

Entorno: Linux x64, Flutter 3.47.6 / Dart 3.13.5, Chromium 151. Consulta funcional y trabajo realizados el 2 de octubre de 2026.

- `tool/setup_cloud.sh`: ejecutado y repetido con éxito; verifica la revisión del SDK y respeta `pubspec.lock`.
- `flutter analyze`: sin problemas.
- `flutter test`: 15 pruebas aprobadas de de persistencia/restauración, aislamiento por fecha, copia profunda de widgets y plantillas, historial, hábitos, errores de almacenamiento, archivos inválidos, temporizador, tareas e interfaz de teléfono.
- `flutter build web --release --no-web-resources-cdn`: compilación de producción generada en `build/web`.
- Servidor local iniciado y reiniciado; documento y bundle JavaScript devuelven HTTP 200.
- `node tool/browser_smoke.cjs`: crea/completa una tarea por la interfaz, recarga y verifica su persistencia, aplica una plantilla sin borrar datos, descarga una copia JSON, agrega otro widget y restaura la copia verificando que se recupera el contenido anterior. Abre el menú en ancho de teléfono y comprueba la búsqueda con y sin resultados. Verifica que no haya errores JavaScript ni solicitudes fallidas.
- Inspección visual de las capturas de escritorio y teléfono; fuente emoji incluida para evitar dependencias de red en los widgets incorporados.

No ejecutado: compilaciones o pruebas nativas de iOS/iPadOS, Android, Windows y macOS; publicación en tiendas; despliegue web público; restauración del snapshot en otra tarea cloud. Generar los proyectos de plataforma no verifica esos destinos.

La ficha pública de Whatting se consultó, pero no se hizo una comparación interactiva con su app instalada. Las diferencias de alcance están en `whatting-research.md`.
