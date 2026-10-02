import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_planner/main.dart';
import 'package:definitive_planner/models/planner.dart';
import 'package:definitive_planner/data/planner_store.dart';
import 'planner_store_test.dart' show MemoryStorage;

void main() {
  testWidgets('create a tasks widget, add a task and complete it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = PlannerStore(MemoryStorage());
    await store.load();
    await tester.pumpWidget(PlannerApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Un día por escribir'), findsOneWidget);
    await tester.tap(find.text('Agregar widget'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tareas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar tarea'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Leer 10 páginas');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Leer 10 páginas'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('1 de 1 completadas'), findsOneWidget);
    await store.flush();
    final restored = PlannerStore(store.storage);
    await restored.load();
    expect(
      restored.blocks(DateTime.now()).first.data['items'][0]['done'],
      true,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('all widget types render at phone width without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = PlannerStore(MemoryStorage());
    await store.load();
    for (final kind in BlockKind.values) {
      store.add(DateTime.now(), kind);
    }
    await tester.pumpWidget(PlannerApp(store: store));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('template adds content and undo restores the empty page', (
    tester,
  ) async {
    final store = PlannerStore(MemoryStorage());
    await store.load();
    await tester.pumpWidget(PlannerApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir una plantilla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Día tranquilo'));
    await tester.pumpAndSettle();
    expect(store.blocks(DateTime.now()), hasLength(4));
    await tester.tap(find.byTooltip('Deshacer cambio de estructura'));
    await tester.pumpAndSettle();
    expect(find.text('Un día por escribir'), findsOneWidget);
  });
}
