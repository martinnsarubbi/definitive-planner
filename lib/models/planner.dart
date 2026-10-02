import 'dart:convert';
import 'dart:math';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';
String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

enum BlockKind {
  note('Nota', 'Escribí tu diario y notas en Markdown'),
  tasks('Tareas', 'Pendientes, prioridades y completadas'),
  schedule('Agenda', 'Eventos y horarios del día'),
  week('Semana', 'Tu planificación de lunes a domingo'),
  month('Calendario', 'Navegá entre los días del mes'),
  mood('Ánimo', 'Registrá cómo te sentís'),
  habits('Hábitos', 'Rutinas y seguimiento diario'),
  pomodoro('Pomodoro', 'Concentración y descansos'),
  sketch('Dibujo', 'Escribí a mano con dedo, lápiz o mouse'),
  photo('Foto', 'Imágenes y recuerdos propios'),
  review('Experiencia', 'Libros, películas y valoraciones'),
  countdown('Cuenta regresiva', 'Días para una fecha especial');

  const BlockKind(this.label, this.description);
  final String label;
  final String description;
}

class PlannerBlock {
  PlannerBlock({
    required this.id,
    required this.kind,
    required this.title,
    this.width = 1,
    this.height = 1,
    Map<String, dynamic>? data,
    List<String>? tags,
    List<Map<String, dynamic>>? stickers,
  }) : data = data ?? {},
       tags = tags ?? [],
       stickers = stickers ?? [];
  final String id;
  final BlockKind kind;
  String title;
  int width;
  int height;
  Map<String, dynamic> data;
  List<String> tags;
  List<Map<String, dynamic>> stickers;

  factory PlannerBlock.create(BlockKind kind) =>
      PlannerBlock(id: newId(), kind: kind, title: kind.label);
  factory PlannerBlock.fromJson(Map<String, dynamic> json) {
    return PlannerBlock(
      id: json['id'] as String,
      kind: BlockKind.values.byName(json['kind'] as String),
      title: json['title'] as String,
      width: (json['width'] as int? ?? 1).clamp(1, 3),
      height: (json['height'] as int? ?? 1).clamp(1, 3),
      data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
      tags: List<String>.from(json['tags'] as List? ?? []),
      stickers: (json['stickers'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'width': width,
    'height': height,
    'data': data,
    'tags': tags,
    'stickers': stickers,
  };
  PlannerBlock duplicate() => PlannerBlock.fromJson(
    (jsonDecode(jsonEncode(toJson())) as Map<String, dynamic>)
      ..['id'] = newId(),
  );
}

class PlannerDocument {
  PlannerDocument({
    Map<String, List<PlannerBlock>>? pages,
    List<Map<String, dynamic>>? habits,
    Map<String, List<PlannerBlock>>? templates,
    this.accent = 0,
    this.dark = false,
  }) : pages = pages ?? {},
       habits = habits ?? [],
       templates = templates ?? {};
  final Map<String, List<PlannerBlock>> pages;
  final List<Map<String, dynamic>> habits;
  final Map<String, List<PlannerBlock>> templates;
  int accent;
  bool dark;

  factory PlannerDocument.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Versión de copia no compatible.');
    }
    Map<String, List<PlannerBlock>> parsePages(dynamic value) =>
        (value as Map<String, dynamic>? ?? {}).map(
          (key, items) => MapEntry(
            key,
            (items as List)
                .map((e) => PlannerBlock.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
        );
    final document = PlannerDocument(
      pages: parsePages(json['pages']),
      templates: parsePages(json['templates']),
      habits: (json['habits'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      accent: (json['accent'] as int? ?? 0).clamp(0, 3),
      dark: json['dark'] as bool? ?? false,
    );
    for (final key in document.pages.keys) {
      if (dayKey(DateTime.parse(key)) != key) {
        throw const FormatException('Fecha inválida.');
      }
    }
    return document;
  }
  Map<String, dynamic> toJson() => {
    'version': 1,
    'pages': pages.map(
      (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
    ),
    'habits': habits,
    'templates': templates.map(
      (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
    ),
    'accent': accent,
    'dark': dark,
  };
}
