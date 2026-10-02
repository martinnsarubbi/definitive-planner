# Referencia funcional: Whatting

Consulta: 2 de octubre de 2026. Fuente primaria: [App Store Argentina](https://apps.apple.com/ar/app/whatting-agenda-diario-notas/id6740423681), descripción y notas públicas de las versiones 26.31.03–26.40.01. No se ejecutó la aplicación original: estas son funciones publicadas, no una auditoría de cada pantalla o del plan Pro.

## Hallazgos

Whatting no es solamente una agenda: es un tablero por fecha compuesto por widgets que se pueden agregar, arrastrar, redimensionar y abrir en modo enfoque. Ofrece plantillas diarias, semanales, mensuales, de estudio, viajes y bullet journal.

La descripción ya anuncia seguimiento de hábitos y objetivos; no es una función ausente de la referencia. Se incluye una base local en nuestra primera versión, extensible más adelante.

Funciones anunciadas:

- Tareas, diario, notas Markdown, escritura con teclado y texto con formato.
- Calendario, planificador semanal, horario de clases, Pomodoro, hábitos y ánimo.
- Escritura y dibujo con Apple Pencil, selección con lazo, deshacer/rehacer y guardado de trazos como stickers.
- Fotos y videos, varias páginas por widget, duplicado/copiado, etiquetas y búsqueda en texto.
- Stickers movibles, tamaño y rotación; borde, relieve y sombra; imágenes propias y recorte de sujetos; stickers animados desde hasta tres segundos de video.
- Stickers interactivos de hora, clima y pronóstico, valoración, Apple Music y ubicación/mapas.
- Reseñas de libros, películas y otras experiencias.
- Vista general por fechas, modo enfoque y navegación por gestos.
- Sincronización iCloud, widgets de pantalla de inicio, atajos de teclado.
- Suscripción Pro, códigos de invitación, monedas y misiones. Las reglas completas no están documentadas en la ficha consultada.

## Decisión tecnológica

Flutter/Dart permite una base compartida para iPhone, iPad, Android, web, Windows y macOS. La interfaz y el dominio no dependen de APIs de Apple. El diseño reside en `lib/theme/app_theme.dart`; la persistencia se encapsula en `lib/data/planner_store.dart` para poder incorporar sincronización después.

El soporte de Flutter no equivale a haber probado cada plataforma: iOS y macOS requieren un Mac con Xcode; Windows requiere Windows y Visual Studio; Android necesita su SDK. Este entorno Linux se usa para análisis, pruebas y compilación web.

## Alcance y diferencias

La primera entrega implementa el núcleo local de planificación. No se presenta como paridad completa con Whatting. Consultar `README.md` para las funciones implementadas y las verificaciones reales.

Quedan como trabajo de paridad explícito: sincronización entre dispositivos y conflictos; integración con calendarios del sistema y notificaciones; extensiones de pantalla de inicio; Apple Pencil con presión, rechazo de palma y lazo; video embebido/recorte automático, segmentación de sujetos y stickers animados; clima geolocalizado, mapas y catálogo/reproducción de Apple Music. Requieren desarrollo y/o APIs específicas. No se simulan con botones inactivos. La base usa dibujos independientes y stickers emoji, no reproduce el editor completo de la referencia.

La monetización, monedas e invitaciones pertenecen al negocio de Whatting y no se trasladan por defecto. Las plantillas y el código son propios; no se reutilizan sus recursos gráficos ni marca.
