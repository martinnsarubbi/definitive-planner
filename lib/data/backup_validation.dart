import 'dart:convert';
import '../models/planner.dart';

/// Reject incompatible nested content before an import can replace local data.
void validateDocument(PlannerDocument document) {
  Never invalid() =>
      throw const FormatException('Contenido de copia inválido.');
  void date(String key) {
    final value = DateTime.tryParse(key);
    if (value == null ||
        value.year < 1900 ||
        value.year > 2200 ||
        dayKey(value) != key) {
      invalid();
    }
  }

  void optionalType<T>(Map<dynamic, dynamic> data, String key) {
    if (data.containsKey(key) && data[key] is! T) invalid();
  }

  void number(dynamic value, num min, num max) {
    if (value is! num || !value.isFinite || value < min || value > max) {
      invalid();
    }
  }

  final ids = <String>{};
  for (final key in document.pages.keys) {
    date(key);
  }
  for (final page in [...document.pages.values, ...document.templates.values]) {
    for (final block in page) {
      if (block.id.isEmpty || !ids.add(block.id)) invalid();
      final data = block.data;
      for (final key in [
        'text',
        'image',
        'caption',
        'target',
        'reflection',
        'subject',
        'category',
      ]) {
        optionalType<String>(data, key);
      }
      for (final key in [
        'minutes',
        'remaining',
        'endsAt',
        'sessions',
        'mood',
        'rating',
      ]) {
        optionalType<int>(data, key);
      }
      optionalType<bool>(data, 'completed');
      if (data['minutes'] != null && ![5, 15, 25].contains(data['minutes'])) {
        invalid();
      }
      if (data['remaining'] != null) number(data['remaining'], 0, 86400);
      if (data['endsAt'] != null) number(data['endsAt'], 0, 8000000000000);
      if (data['sessions'] != null) number(data['sessions'], 0, 1000000);
      if (data['mood'] != null) number(data['mood'], 0, 4);
      if (data['rating'] != null) number(data['rating'], 1, 5);
      if (data['target'] != null) date(data['target'] as String);
      if (data['category'] != null &&
          ![
            'Libro',
            'Película',
            'Serie',
            'Música',
            'Lugar',
            'Otra experiencia',
          ].contains(data['category'])) {
        invalid();
      }
      if (data['pages'] != null) {
        if (data['pages'] is! List ||
            (data['pages'] as List).any((p) => p is! String)) {
          invalid();
        }
      }
      if (data['days'] != null) {
        if (data['days'] is! Map) invalid();
        for (final entry in (data['days'] as Map).entries) {
          date(entry.key as String);
          if (entry.value is! String) invalid();
        }
      }
      for (final key in ['items', 'events', 'strokes']) {
        if (data[key] != null && data[key] is! List) invalid();
        for (final item in (data[key] as List? ?? [])) {
          if (item is! Map) invalid();
          if (key == 'items') {
            if (item['title'] is! String || item['done'] is! bool) invalid();
            optionalType<bool>(item, 'priority');
          } else if (key == 'events') {
            if (item['title'] is! String ||
                item['time'] is! String ||
                !RegExp(
                  r'^([01]\d|2[0-3]):[0-5]\d$',
                ).hasMatch(item['time'] as String)) {
              invalid();
            }
          } else {
            if (item['color'] is! int || item['points'] is! List) invalid();
            number(item['color'], 0, 0xFFFFFFFF);
            number(item['width'], 1, 10);
            for (final point in item['points'] as List) {
              if (point is! List || point.length != 2) invalid();
              number(point[0], 0, 1);
              number(point[1], 0, 1);
            }
          }
        }
      }
      if (data['image'] != null &&
          base64Decode(data['image'] as String).length > 1024 * 1024) {
        invalid();
      }
      for (final sticker in block.stickers) {
        if (sticker['id'] is! String || sticker['emoji'] is! String) invalid();
        number(sticker['x'], 0, 1);
        number(sticker['y'], 0, 1);
        number(sticker['size'], 10, 100);
        number(sticker['angle'], -100000, 100000);
      }
    }
  }
  final habitIds = <String>{};
  for (final habit in document.habits) {
    if (habit['id'] is! String ||
        !habitIds.add(habit['id'] as String) ||
        habit['name'] is! String ||
        habit['checks'] is! Map) {
      invalid();
    }
    for (final entry in (habit['checks'] as Map).entries) {
      date(entry.key as String);
      if (entry.value is! String ||
          DateTime.tryParse(entry.value as String) == null) {
        invalid();
      }
    }
  }
}
