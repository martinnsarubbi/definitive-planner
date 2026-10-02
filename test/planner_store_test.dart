import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_planner/data/planner_store.dart';
import 'package:definitive_planner/models/planner.dart';
import 'package:definitive_planner/models/focus_timer.dart';

class MemoryStorage implements PlannerStorage {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('disk full');
    this.value = value;
  }
}

void main() {
  final date = DateTime(2026, 10, 2);
  late MemoryStorage storage;
  late PlannerStore store;
  setUp(() async {
    storage = MemoryStorage();
    store = PlannerStore(storage);
    await store.load();
  });

  test('pages, notes and task completion survive a fresh store', () async {
    store.add(date, BlockKind.tasks);
    store.change(
      () => store.blocks(date).first.data['items'] = [
        {'id': 'task', 'title': 'Leer', 'done': true},
      ],
    );
    store.add(date.add(const Duration(days: 1)), BlockKind.note);
    store.change(
      () =>
          store.blocks(date.add(const Duration(days: 1))).first.data['pages'] =
              ['Diario', 'Segunda página'],
    );
    await store.flush();
    final restored = PlannerStore(storage);
    await restored.load();
    expect(restored.blocks(date).first.data['items'][0]['done'], true);
    expect(
      restored.blocks(date.add(const Duration(days: 1))).first.data['pages'],
      ['Diario', 'Segunda página'],
    );
    expect(restored.blocks(date.subtract(const Duration(days: 1))), isEmpty);
  });
  test(
    'duplicate and templates deeply copy content with independent IDs',
    () async {
      store.add(date, BlockKind.tasks);
      store.change(
        () => store.blocks(date).first.data['items'] = [
          {'title': 'Original', 'done': false},
        ],
      );
      store.duplicate(date, store.blocks(date).first);
      final blocks = store.blocks(date);
      expect(blocks[0].id, isNot(blocks[1].id));
      store.change(() => blocks[1].data['items'][0]['title'] = 'Copia');
      expect(blocks[0].data['items'][0]['title'], 'Original');
      store.saveTemplate('Personal', date);
      final tomorrow = date.add(const Duration(days: 1));
      store.applyTemplate(tomorrow, store.document.templates['Personal']!);
      store.change(
        () => store.blocks(tomorrow).first.data['items'][0]['title'] = 'Mañana',
      );
      expect(
        store.document.templates['Personal']!.first.data['items'][0]['title'],
        'Original',
      );
      await store.flush();
      expect(() => PlannerStore.decodeBackup(store.export()), returnsNormally);
    },
  );
  test('reordering and removal can be undone and redone', () {
    store.add(date, BlockKind.note);
    store.add(date, BlockKind.tasks);
    final id = store.blocks(date).first.id;
    store.move(date, id, 1);
    expect(store.blocks(date).last.id, id);
    store.remove(date, id);
    expect(store.blocks(date).length, 1);
    store.undo();
    expect(store.blocks(date).last.id, id);
    store.redo();
    expect(store.blocks(date).length, 1);
  });
  test('editing after undo invalidates redo so new text cannot be lost', () {
    store.add(date, BlockKind.note);
    store.add(date, BlockKind.tasks);
    store.undo();
    expect(store.canRedo, true);
    store.change(
      () => store.blocks(date).first.data['pages'] = ['Texto nuevo'],
      history: false,
    );
    expect(store.canRedo, false);
    store.redo();
    expect(store.blocks(date).first.data['pages'], ['Texto nuevo']);
  });

  test('template application preserves existing page content', () {
    store.add(date, BlockKind.note);
    final original = store.blocks(date).first.id;
    store.applyTemplate(date, builtInTemplates()['Día tranquilo']!);
    expect(store.blocks(date).length, 5);
    expect(store.blocks(date).first.id, original);
  });
  test('habit checks are independent across dates and toggle off', () {
    store.change(
      () => store.document.habits.add({
        'id': 'h',
        'name': 'Leer',
        'checks': <String, dynamic>{},
      }),
    );
    final habit = store.document.habits.first;
    store.toggleHabit(habit, date);
    store.toggleHabit(habit, date.add(const Duration(days: 1)));
    store.toggleHabit(habit, date);
    expect((habit['checks'] as Map).keys, ['2026-10-03']);
  });
  test('malformed or future backups never replace open data', () async {
    store.add(date, BlockKind.note);
    await store.flush();
    final before = store.export();
    await expectLater(store.import('{"version":2}'), throwsFormatException);
    expect(store.export(), before);
    expect(storage.value, before);
    await expectLater(store.import('not json'), throwsFormatException);
    expect(store.export(), before);
  });
  test('failed persistence is visible and retry preserves edits', () async {
    storage.fail = true;
    store.add(date, BlockKind.note);
    await store.flush();
    expect(store.error, isNotNull);
    expect(store.blocks(date), hasLength(1));
    storage.fail = false;
    await store.save();
    expect(store.error, isNull);
    expect(storage.value, store.export());
  });
  test('failed import write does not replace existing data', () async {
    store.add(date, BlockKind.note);
    await store.flush();
    final before = store.export();
    storage.fail = true;
    await expectLater(
      store.import(jsonEncode(PlannerDocument().toJson())),
      throwsStateError,
    );
    expect(store.export(), before);
  });
  test('corrupt saved data is not silently overwritten on load', () async {
    storage.value = 'broken';
    await store.load();
    expect(store.loadFailed, true);
    store.add(date, BlockKind.note);
    await store.flush();
    expect(storage.value, 'broken');
    expect(store.blocks(date), isEmpty);
  });
  test(
    'nested malformed imports are rejected without replacing the planner',
    () async {
      store.add(date, BlockKind.tasks);
      await store.flush();
      final before = store.export();
      final raw = jsonDecode(before) as Map<String, dynamic>;
      raw['pages']['2026-10-02'][0]['data']['items'] = [
        {'title': 7, 'done': false},
      ];
      await expectLater(store.import(jsonEncode(raw)), throwsFormatException);
      expect(store.export(), before);
      expect(storage.value, before);
    },
  );

  test('timer deadline survives suspension and never becomes negative', () {
    final now = DateTime(2026, 10, 2, 9);
    final timer = {
      'endsAt': now.add(const Duration(minutes: 25)).millisecondsSinceEpoch,
    };
    expect(
      remainingSeconds(timer, now.add(const Duration(minutes: 7))),
      18 * 60,
    );
    expect(remainingSeconds(timer, now.add(const Duration(hours: 1))), 0);
    expect(remainingSeconds({'remaining': 123}, now), 123);
  });
}
