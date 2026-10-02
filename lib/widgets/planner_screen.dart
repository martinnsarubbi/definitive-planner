import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/planner_store.dart';
import '../models/planner.dart';
import '../theme/app_theme.dart';
import 'block_card.dart';
import 'editors.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, required this.store});
  final PlannerStore store;
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime date = DateUtils.dateOnly(DateTime.now());
  bool overview = false;
  String query = '';
  PlannerStore get store => widget.store;
  void selectDate(DateTime value) => setState(() {
    date = DateUtils.dateOnly(value);
    overview = false;
  });
  void message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (selected != null) selectDate(selected);
  }

  Future<void> exportBackup() async {
    try {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Guardar copia de seguridad',
        fileName: 'planner-${dayKey(DateTime.now())}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(store.export())),
      );
      if (path != null) {
        message('Copia exportada. Guardala en un lugar seguro.');
      }
    } catch (_) {
      message(
        'No se pudo exportar la copia. Reintentá desde tu navegador o dispositivo.',
      );
    }
  }

  Future<void> importBackup() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) return;
      if ((await file.length() ?? 13 * 1024 * 1024) > 12 * 1024 * 1024) {
        message('Elegí una copia JSON de hasta 12 MB.');
        return;
      }
      final raw = utf8.decode(await file.readAsBytes());
      final imported = PlannerStore.decodeBackup(raw);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Restaurar esta copia?'),
          content: Text(
            'Contiene ${imported.pages.length} días. Reemplazará los datos de este dispositivo. Exportá antes tu agenda actual si querés conservarla.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restaurar'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await store.import(raw);
        message('Copia restaurada.');
      }
    } catch (_) {
      message(
        'No se pudo importar. El archivo no es válido o no hay espacio. Tus datos anteriores se conservan.',
      );
    }
  }

  Future<void> addWidget() async {
    final kind = await showDialog<BlockKind>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tu día, a tu manera',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
                const Text('Elegí un widget para tu página.'),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    children: BlockKind.values
                        .map(
                          (kind) => ListTile(
                            leading: Icon(blockIcon(kind)),
                            title: Text(kind.label),
                            subtitle: Text(kind.description),
                            trailing: const Icon(Icons.add),
                            onTap: () => Navigator.pop(context, kind),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (kind != null) {
      store.add(date, kind);
      setState(() => overview = false);
    }
  }

  Future<void> templates() async {
    await showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Empezá con una plantilla'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Text(
              'Se agregan widgets a este día sin borrar lo que ya escribiste.',
            ),
          ),
          ...{...builtInTemplates(), ...store.document.templates}.entries.map(
            (entry) => SimpleDialogOption(
              onPressed: () {
                store.applyTemplate(date, entry.value);
                Navigator.pop(context);
                setState(() => overview = false);
              },
              child: ListTile(
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: Text(entry.key),
                subtitle: Text('${entry.value.length} widgets'),
              ),
            ),
          ),
          if (store.blocks(date).isNotEmpty)
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(context);
                final name = await askText(
                  this.context,
                  'Nombre de la plantilla',
                  hint: 'Mi semana ideal',
                );
                if (name != null && name.trim().isNotEmpty) {
                  var unique = name.trim();
                  while (store.document.templates.containsKey(unique) ||
                      builtInTemplates().containsKey(unique)) {
                    unique = '$unique (copia)';
                  }
                  store.saveTemplate(unique, date);
                  message('Plantilla guardada con su contenido actual.');
                }
              },
              child: const ListTile(
                leading: Icon(Icons.bookmark_add_outlined),
                title: Text('Guardar esta página como plantilla'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> settings() async {
    await showDialog<void>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) => AlertDialog(
          title: const Text('Hacé tuyo este espacio'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Color de acento'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: List.generate(
                    AppTheme.colors.length,
                    (i) => IconButton.filled(
                      tooltip: ['Bosque', 'Azul', 'Terracota', 'Lavanda'][i],
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.colors[i],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () =>
                          store.change(() => store.document.accent = i),
                      icon: Icon(
                        store.document.accent == i
                            ? Icons.check
                            : Icons.circle_outlined,
                      ),
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Modo oscuro'),
                  value: store.document.dark,
                  onChanged: (value) =>
                      store.change(() => store.document.dark = value),
                ),
                const Divider(),
                const Text(
                  'Tus datos se guardan en este dispositivo. Exportá una copia antes de borrar datos del navegador o desinstalar la app.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    exportBackup();
                  },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Exportar copia JSON'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    importBackup();
                  },
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Restaurar copia JSON'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Listo'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true): store.undo,
      const SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: true,
        shift: true,
      ): store.redo,
    },
    child: Focus(
      autofocus: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          return Scaffold(
            key: scaffoldKey,
            appBar: wide
                ? null
                : AppBar(
                    title: const Text('Definitive Planner'),
                    actions: [
                      IconButton(
                        onPressed: settings,
                        icon: const Icon(Icons.tune),
                        tooltip: 'Personalizar',
                      ),
                    ],
                  ),
            drawer: wide ? null : Drawer(child: SafeArea(child: sidebar())),
            body: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide) SizedBox(width: 245, child: sidebar()),
                  Expanded(
                    child: Column(
                      children: [
                        if (store.error != null)
                          MaterialBanner(
                            content: Text(store.error!),
                            actions: [
                              TextButton(
                                onPressed: store.loadFailed
                                    ? store.load
                                    : store.save,
                                child: const Text('Reintentar'),
                              ),
                              TextButton(
                                onPressed: store.loadFailed
                                    ? importBackup
                                    : exportBackup,
                                child: Text(
                                  store.loadFailed ? 'Restaurar' : 'Exportar',
                                ),
                              ),
                            ],
                          ),
                        Expanded(
                          child: store.loadFailed
                              ? const Center(
                                  child: Text(
                                    'Recuperá tus datos para continuar.',
                                  ),
                                )
                              : SingleChildScrollView(
                                  padding: EdgeInsets.all(wide ? 32 : 16),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: AppTheme.contentWidth,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          header(),
                                          const SizedBox(height: 24),
                                          if (overview)
                                            overviewBody()
                                          else
                                            board(),
                                          const SizedBox(height: 48),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget sidebar() => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        right: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: .15),
        ),
      ),
    ),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Icon(
          Icons.auto_stories_outlined,
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        const Text(
          'definitive\nplanner',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Un lugar para tus días.'),
        const SizedBox(height: 36),
        navigationTile(
          'Mi página',
          Icons.grid_view_outlined,
          !overview,
          () => setState(() => overview = false),
        ),
        navigationTile(
          'Vista general',
          Icons.auto_awesome_mosaic_outlined,
          overview,
          () => setState(() => overview = true),
        ),
        navigationTile(
          'Plantillas',
          Icons.dashboard_customize_outlined,
          false,
          templates,
        ),
        const SizedBox(height: 24),
        const Text(
          'TU ESPACIO',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.7,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${store.document.pages.values.where((p) => p.isNotEmpty).length} días con historias',
        ),
        const Spacer(),
        navigationTile('Personalizar', Icons.tune, false, settings),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              store.error != null
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              size: 15,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                store.error != null
                    ? 'Guardado pendiente'
                    : store.saving
                    ? 'Guardando…'
                    : 'Guardado en este dispositivo',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  Widget navigationTile(
    String text,
    IconData icon,
    bool selected,
    VoidCallback action,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Material(
      type: MaterialType.transparency,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: selected,
        selectedTileColor: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: .5),
        leading: Icon(icon, size: 21),
        title: Text(text),
        onTap: () {
          scaffoldKey.currentState?.closeDrawer();
          action();
        },
      ),
    ),
  );
  Widget header() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            overview
                ? 'Tus días, de un vistazo'
                : DateFormat('EEEE', 'es').format(date).toUpperCase(),
            style: TextStyle(
              fontSize: overview ? 26 : 12,
              letterSpacing: overview ? 0 : 2,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!overview) ...[
            IconButton(
              onPressed: () =>
                  selectDate(date.subtract(const Duration(days: 1))),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Día anterior',
            ),
            IconButton(
              onPressed: () => selectDate(date.add(const Duration(days: 1))),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Día siguiente',
            ),
            TextButton(
              onPressed: () => selectDate(DateTime.now()),
              child: const Text('Hoy'),
            ),
          ],
        ],
      ),
      if (!overview)
        GestureDetector(
          onTap: pickDate,
          child: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                DateFormat("d 'de' MMMM, yyyy", 'es').format(date),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.8,
                ),
              ),
              IconButton(
                onPressed: pickDate,
                tooltip: 'Elegir fecha',
                icon: const Icon(Icons.calendar_today_outlined, size: 20),
              ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      Text(
        overview
            ? 'Buscá recuerdos, notas y etiquetas en todas tus páginas.'
            : 'Organizá lo importante. Dejá espacio para lo demás.',
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: addWidget,
            icon: const Icon(Icons.add),
            label: const Text('Agregar widget'),
          ),
          OutlinedButton.icon(
            onPressed: templates,
            icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
            label: const Text('Plantillas'),
          ),
          IconButton(
            onPressed: store.canUndo ? store.undo : null,
            tooltip: 'Deshacer cambio de estructura',
            icon: const Icon(Icons.undo, size: 20),
          ),
          IconButton(
            onPressed: store.canRedo ? store.redo : null,
            tooltip: 'Rehacer cambio de estructura',
            icon: const Icon(Icons.redo, size: 20),
          ),
        ],
      ),
    ],
  );

  Widget board() {
    final blocks = store.blocks(date);
    if (blocks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Column(
          children: [
            Icon(
              Icons.edit_note,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Un día por escribir',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agregá tu primer widget o probá una plantilla.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: templates,
              child: const Text('Elegir una plantilla'),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 650
            ? 2
            : 1;
        final cell =
            (constraints.maxWidth - (columns - 1) * AppTheme.gap) / columns;
        return Wrap(
          spacing: AppTheme.gap,
          runSpacing: AppTheme.gap,
          children: blocks.asMap().entries.map((entry) {
            final block = entry.value;
            final span = block.width.clamp(1, columns);
            return DragTarget<String>(
              onWillAcceptWithDetails: (details) => details.data != block.id,
              onAcceptWithDetails: (details) =>
                  store.move(date, details.data, entry.key),
              builder: (context, candidates, rejected) => Container(
                width: cell * span + AppTheme.gap * (span - 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: candidates.isEmpty
                      ? null
                      : Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                ),
                child: BlockCard(
                  key: ValueKey(block.id),
                  block: block,
                  store: store,
                  date: date,
                  onSelectDate: selectDate,
                  index: entry.key,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget overviewBody() {
    final entries =
        store.document.pages.entries
            .where(
              (entry) =>
                  entry.value.isNotEmpty &&
                  (query.isEmpty ||
                      entry.key.contains(query) ||
                      entry.value.any(
                        (b) =>
                            '${b.title} ${b.tags.join(' ')} ${jsonEncode(b.data)}'
                                .toLowerCase()
                                .contains(query.toLowerCase()),
                      )),
            )
            .toList()
          ..sort((a, b) => b.key.compareTo(a.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar notas, tareas, fechas o etiquetas',
          ),
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: 20),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('Todavía no hay páginas que coincidan.'),
          ),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: Icon(
                  Icons.book_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  DateFormat(
                    "EEEE d 'de' MMMM, yyyy",
                    'es',
                  ).format(DateTime.parse(entry.key)),
                ),
                subtitle: Text(
                  entry.value.map((b) => b.title).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => selectDate(DateTime.parse(entry.key)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
