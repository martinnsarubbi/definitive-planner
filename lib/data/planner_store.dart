import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/planner.dart';
import 'backup_validation.dart';

abstract interface class PlannerStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class LocalPlannerStorage implements PlannerStorage {
  static const key = 'definitive_planner_v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  @override
  Future<String?> read() => _preferences.getString(key);
  @override
  Future<void> write(String value) => _preferences.setString(key, value);
}

class PlannerStore extends ChangeNotifier {
  static const maxBackupBytes = 12 * 1024 * 1024;
  PlannerStore(this.storage);
  final PlannerStorage storage;
  PlannerDocument document = PlannerDocument();
  bool loaded = false;
  bool saving = false;
  String? error;
  bool loadFailed = false;
  Future<void> _pending = Future.value();
  int _saveRevision = 0;
  final List<String> _undo = [];
  final List<String> _redo = [];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  Future<void> load() async {
    try {
      final raw = await storage.read();
      if (raw != null) document = decodeBackup(raw);
      loadFailed = false;
      error = null;
    } catch (_) {
      loadFailed = true;
      error =
          'No se pudieron leer tus datos. Conservamos la copia original. Reintentá o importá una copia válida.';
    }
    loaded = true;
    notifyListeners();
  }

  static PlannerDocument decodeBackup(String raw) {
    if (utf8.encode(raw).length > maxBackupBytes) {
      throw const FormatException('La copia supera 12 MB.');
    }
    final document = PlannerDocument.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    validateDocument(document);
    return document;
  }

  List<PlannerBlock> blocks(DateTime date) =>
      document.pages[dayKey(date)] ?? [];
  void change(VoidCallback action, {bool history = true}) {
    if (loadFailed) return;
    final previous = export();
    action();
    if (utf8.encode(export()).length > maxBackupBytes) {
      document = PlannerDocument.fromJson(jsonDecode(previous));
      error =
          'No se aplicó el cambio: la agenda supera el límite local de 12 MB. Exportá una copia y reducí las fotos.';
      notifyListeners();
      return;
    }
    if (history) {
      _undo.add(previous);
      if (_undo.length > 25) _undo.removeAt(0);
    }
    _redo.clear();
    save();
  }

  Future<void> save() {
    final snapshot = export();
    final revision = ++_saveRevision;
    saving = true;
    error = null;
    notifyListeners();
    final operation = _pending.then((_) => storage.write(snapshot));
    _pending = operation.then(
      (_) {
        if (revision != _saveRevision) return;
        saving = false;
        error = null;
        notifyListeners();
      },
      onError: (Object e) {
        if (revision != _saveRevision) return;
        saving = false;
        error =
            'No se pudo guardar. Tus cambios siguen abiertos: exportá una copia y reintentá. Puede faltar espacio.';
        notifyListeners();
      },
    );
    return _pending;
  }

  Future<void> flush() => _pending;
  String export() => jsonEncode(document.toJson());

  Future<void> import(String raw) async {
    final imported = decodeBackup(raw);
    // Write before replacing state: a failed import never destroys the open planner.
    await flush();
    await storage.write(jsonEncode(imported.toJson()));
    document = imported;
    _undo.clear();
    _redo.clear();
    loadFailed = false;
    error = null;
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(export());
    document = PlannerDocument.fromJson(jsonDecode(_undo.removeLast()));
    save();
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(export());
    document = PlannerDocument.fromJson(jsonDecode(_redo.removeLast()));
    save();
  }

  void add(DateTime date, BlockKind kind) => change(() {
    document.pages
        .putIfAbsent(dayKey(date), () => [])
        .add(PlannerBlock.create(kind));
  });
  void remove(DateTime date, String id) =>
      change(() => blocks(date).removeWhere((b) => b.id == id));
  void duplicate(DateTime date, PlannerBlock block) =>
      change(() => blocks(date).add(block.duplicate()));
  void copyTo(DateTime date, PlannerBlock block) => change(() {
    document.pages.putIfAbsent(dayKey(date), () => []).add(block.duplicate());
  });
  void move(DateTime date, String id, int target) => change(() {
    final list = blocks(date);
    final index = list.indexWhere((b) => b.id == id);
    if (index < 0) return;
    final block = list.removeAt(index);
    list.insert(target.clamp(0, list.length), block);
  });
  void applyTemplate(DateTime date, List<PlannerBlock> template) => change(() {
    document.pages
        .putIfAbsent(dayKey(date), () => [])
        .addAll(template.map((b) => b.duplicate()));
  });
  void saveTemplate(String name, DateTime date) => change(() {
    document.templates[name] = blocks(date).map((b) => b.duplicate()).toList();
  });
  void toggleHabit(Map<String, dynamic> habit, DateTime date) => change(() {
    final checks = Map<String, dynamic>.from(habit['checks'] as Map? ?? {});
    final key = dayKey(date);
    if (checks.containsKey(key)) {
      checks.remove(key);
    } else {
      checks[key] = DateTime.now().toIso8601String();
    }
    habit['checks'] = checks;
  });
}

Map<String, List<PlannerBlock>> builtInTemplates() => {
  'Día tranquilo': [
    BlockKind.tasks,
    BlockKind.note,
    BlockKind.mood,
    BlockKind.schedule,
  ],
  'Estudio': [
    BlockKind.week,
    BlockKind.tasks,
    BlockKind.pomodoro,
    BlockKind.note,
  ],
  'Diario de viaje': [
    BlockKind.photo,
    BlockKind.note,
    BlockKind.review,
    BlockKind.countdown,
  ],
  'Mi rutina': [
    BlockKind.habits,
    BlockKind.mood,
    BlockKind.tasks,
    BlockKind.note,
  ],
}.map((name, kinds) => MapEntry(name, kinds.map(PlannerBlock.create).toList()));
