import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/planner_store.dart';
import 'theme/app_theme.dart';
import 'widgets/planner_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = PlannerStore(LocalPlannerStorage());
  await store.load();
  runApp(PlannerApp(store: store));
}

class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key, required this.store});
  final PlannerStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => MaterialApp(
      title: 'Definitive Planner',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.build(store.document.accent, Brightness.light),
      darkTheme: AppTheme.build(store.document.accent, Brightness.dark),
      themeMode: store.document.dark ? ThemeMode.dark : ThemeMode.light,
      home: PlannerScreen(store: store),
    ),
  );
}
