import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/planner_store.dart';
import '../models/planner.dart';
import 'editors.dart';
import 'sketch_editor.dart';
import 'timer_editor.dart';

class BlockContent extends StatefulWidget {
  const BlockContent({
    super.key,
    required this.block,
    required this.store,
    required this.date,
    required this.onSelectDate,
  });
  final PlannerBlock block;
  final PlannerStore store;
  final DateTime date;
  final ValueChanged<DateTime> onSelectDate;
  @override
  State<BlockContent> createState() => _BlockContentState();
}

class _BlockContentState extends State<BlockContent> {
  PlannerBlock get block => widget.block;
  Map<String, dynamic> get data => block.data;
  PlannerStore get store => widget.store;
  bool preview = false;
  int notePage = 0;
  void set(String key, dynamic value, {bool history = false}) =>
      store.change(() => data[key] = value, history: history);
  List<Map<String, dynamic>> list(String key) => (data[key] as List? ?? [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  void feedback(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  @override
  Widget build(BuildContext context) => switch (block.kind) {
    BlockKind.note => note(),
    BlockKind.tasks => tasks(),
    BlockKind.schedule => schedule(),
    BlockKind.week => week(),
    BlockKind.month => calendar(),
    BlockKind.mood => mood(),
    BlockKind.habits => habits(),
    BlockKind.pomodoro => TimerEditor(block: block, store: store),
    BlockKind.sketch => SketchEditor(block: block, store: store),
    BlockKind.photo => photo(),
    BlockKind.review => review(),
    BlockKind.countdown => countdown(),
  };

  Widget note() {
    final pages = List<String>.from(
      data['pages'] as List? ?? [data['text'] as String? ?? ''],
    );
    if (pages.isEmpty) pages.add('');
    notePage = notePage.clamp(0, pages.length - 1);
    final text = pages[notePage];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: notePage > 0 ? () => setState(() => notePage--) : null,
              icon: const Icon(Icons.chevron_left, size: 18),
              tooltip: 'Página anterior',
            ),
            Text(
              '${notePage + 1}/${pages.length}',
              style: const TextStyle(fontSize: 12),
            ),
            IconButton(
              onPressed: notePage < pages.length - 1
                  ? () => setState(() => notePage++)
                  : null,
              icon: const Icon(Icons.chevron_right, size: 18),
              tooltip: 'Página siguiente',
            ),
            IconButton(
              onPressed: () {
                pages.add('');
                set('pages', pages, history: true);
                setState(() => notePage = pages.length - 1);
              },
              icon: const Icon(Icons.add, size: 18),
              tooltip: 'Agregar página',
            ),
            const Spacer(),
            IconButton(
              onPressed: () => setState(() => preview = !preview),
              tooltip: preview ? 'Editar nota' : 'Vista Markdown',
              icon: Icon(
                preview ? Icons.edit_outlined : Icons.visibility_outlined,
                size: 18,
              ),
            ),
          ],
        ),
        if (preview)
          MarkdownBody(
            data: text.isEmpty ? '*Tu próxima historia empieza acá.*' : text,
            selectable: true,
            onTapLink: (_, href, _) async {
              final uri = Uri.tryParse(href ?? '');
              if (uri != null && ['https', 'http'].contains(uri.scheme)) {
                await launchUrl(uri);
              }
            },
          )
        else
          EntryField(
            key: ValueKey('note-$notePage'),
            value: text,
            hint:
                '¿Qué te gustaría recordar de hoy?\n\nPodés usar **negrita**, listas y # títulos.',
            minLines: 7,
            onChanged: (value) {
              pages[notePage] = value;
              set('pages', pages);
            },
          ),
      ],
    );
  }

  Widget tasks() {
    final items = list('items');
    final done = items.where((e) => e['done'] == true).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items.isNotEmpty) ...[
          Text(
            '$done de ${items.length} completadas',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: done / items.length,
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 10),
        ],
        ...items.asMap().entries.map((entry) {
          final task = entry.value;
          return Row(
            children: [
              Checkbox(
                value: task['done'] == true,
                onChanged: (value) {
                  task['done'] = value;
                  set('items', items, history: true);
                },
              ),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final title = await askText(
                      context,
                      'Editar tarea',
                      value: task['title'] as String,
                    );
                    if (title != null && title.trim().isNotEmpty) {
                      task['title'] = title.trim();
                      set('items', items, history: true);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      task['title'] as String,
                      style: TextStyle(
                        decoration: task['done'] == true
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  task['priority'] = task['priority'] != true;
                  set('items', items, history: true);
                },
                icon: Icon(
                  task['priority'] == true ? Icons.star : Icons.star_border,
                  size: 18,
                ),
                tooltip: 'Marcar importante',
              ),
              IconButton(
                onPressed: () {
                  items.removeAt(entry.key);
                  set('items', items, history: true);
                },
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Eliminar tarea',
              ),
            ],
          );
        }),
        TextButton.icon(
          onPressed: () async {
            final title = await askText(
              context,
              'Nueva tarea',
              hint: 'Lo próximo que quiero hacer',
            );
            if (title != null && title.trim().isNotEmpty) {
              items.add({
                'id': newId(),
                'title': title.trim(),
                'done': false,
                'priority': false,
              });
              set('items', items, history: true);
            }
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Agregar tarea'),
        ),
      ],
    );
  }

  Future<void> editEvent(
    List<Map<String, dynamic>> events, [
    Map<String, dynamic>? event,
  ]) async {
    final title = await askText(
      context,
      event == null ? 'Nuevo evento' : 'Editar evento',
      value: event?['title'] as String? ?? '',
      hint: 'Reunión, clase, paseo…',
    );
    if (title == null || title.trim().isEmpty || !mounted) return;
    final oldTime = (event?['time'] as String? ?? '09:00').split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(oldTime[0]),
        minute: int.parse(oldTime[1]),
      ),
    );
    if (time == null) return;
    final updated = {
      'id': event?['id'] ?? newId(),
      'title': title.trim(),
      'time':
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
    };
    if (event == null) {
      events.add(updated);
    } else {
      events[events.indexOf(event)] = updated;
    }
    events.sort((a, b) => (a['time'] as String).compareTo(b['time'] as String));
    set('events', events, history: true);
  }

  Widget schedule() {
    final events = list('events');
    return Column(
      children: [
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Un poco de estructura para tu día.'),
          ),
        ...events.map(
          (event) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(
              event['time'] as String,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            title: Text(event['title'] as String),
            onTap: () => editEvent(events, event),
            trailing: IconButton(
              onPressed: () {
                events.remove(event);
                set('events', events, history: true);
              },
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Eliminar evento',
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => editEvent(events),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Agregar evento'),
        ),
      ],
    );
  }

  Widget week() {
    final monday = widget.date.subtract(
      Duration(days: widget.date.weekday - 1),
    );
    final values = Map<String, dynamic>.from(data['days'] as Map? ?? {});
    return Column(
      children: List.generate(7, (index) {
        final date = monday.add(Duration(days: index));
        final key = dayKey(date);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 62,
                child: TextButton(
                  onPressed: () => widget.onSelectDate(date),
                  child: Text(DateFormat('EEE d', 'es').format(date)),
                ),
              ),
              Expanded(
                child: EntryField(
                  value: values[key] as String? ?? '',
                  hint: 'Plan del día',
                  onChanged: (value) {
                    values[key] = value;
                    set('days', values);
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget calendar() {
    final first = DateTime(widget.date.year, widget.date.month);
    final start = first.subtract(Duration(days: first.weekday - 1));
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () =>
                  widget.onSelectDate(DateTime(first.year, first.month - 1)),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Mes anterior',
            ),
            Text(
              DateFormat('MMMM yyyy', 'es').format(first),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            IconButton(
              onPressed: () =>
                  widget.onSelectDate(DateTime(first.year, first.month + 1)),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Mes siguiente',
            ),
          ],
        ),
        Row(
          children: ['L', 'M', 'X', 'J', 'V', 'S', 'D']
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(d, style: const TextStyle(fontSize: 12)),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        ...List.generate(
          6,
          (week) => Row(
            children: List.generate(7, (day) {
              final value = start.add(Duration(days: week * 7 + day));
              final selected = dayKey(value) == dayKey(widget.date);
              final hasContent = store.blocks(value).isNotEmpty;
              return Expanded(
                child: InkWell(
                  onTap: () => widget.onSelectDate(value),
                  child: Container(
                    height: 33,
                    margin: const EdgeInsets.all(1),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${value.day}',
                          style: TextStyle(
                            fontSize: 12,
                            color: value.month == first.month
                                ? null
                                : Theme.of(context).disabledColor,
                          ),
                        ),
                        if (hasContent)
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget mood() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('¿Cómo te sentís hoy?'),
      const SizedBox(height: 18),
      Wrap(
        spacing: 6,
        runSpacing: 8,
        children: List.generate(
          5,
          (i) => ChoiceChip(
            label: Text(
              ['😔', '😕', '😐', '🙂', '😄'][i],
              style: const TextStyle(fontSize: 24),
            ),
            tooltip: ['Muy mal', 'Bajo', 'Neutral', 'Bien', 'Muy bien'][i],
            selected: data['mood'] == i,
            showCheckmark: false,
            onSelected: (_) => set('mood', i, history: true),
          ),
        ),
      ),
      const SizedBox(height: 18),
      EntryField(
        value: data['reflection'] as String? ?? '',
        minLines: 3,
        hint: 'Algo que influyó en mi día…',
        onChanged: (value) => set('reflection', value),
      ),
    ],
  );

  Widget habits() {
    final habits = store.document.habits;
    final monday = widget.date.subtract(
      Duration(days: widget.date.weekday - 1),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Una pequeña acción, cada día.',
          style: TextStyle(fontSize: 12),
        ),
        ...habits.map((habit) {
          final checks = habit['checks'] as Map? ?? {};
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        habit['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar hábito',
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      onPressed: () async {
                        final name = await askText(
                          context,
                          'Nombre del hábito',
                          value: habit['name'] as String,
                        );
                        if (name != null && name.trim().isNotEmpty) {
                          store.change(() => habit['name'] = name.trim());
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Eliminar hábito',
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('¿Eliminar hábito?'),
                            content: const Text(
                              'Se quitará de todas las fechas, junto con su historial. Podés deshacer este cambio.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          store.change(() => habits.remove(habit));
                        }
                      },
                    ),
                  ],
                ),
                Row(
                  children: List.generate(7, (i) {
                    final date = monday.add(Duration(days: i));
                    final checked = checks.containsKey(dayKey(date));
                    return Expanded(
                      child: Column(
                        children: [
                          Text(
                            ['L', 'M', 'X', 'J', 'V', 'S', 'D'][i],
                            style: const TextStyle(fontSize: 10),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 36,
                            ),
                            tooltip:
                                '${DateFormat('d/M').format(date)}: ${checked ? 'completado' : 'pendiente'}',
                            onPressed: () => store.toggleHabit(habit, date),
                            icon: Icon(
                              checked
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 22,
                              color: checked
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                if (checks[dayKey(widget.date)] != null)
                  Text(
                    'Registrado a las ${DateFormat('HH:mm').format(DateTime.parse(checks[dayKey(widget.date)] as String).toLocal())}',
                    style: const TextStyle(fontSize: 10),
                  ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () async {
            final name = await askText(
              context,
              'Nuevo hábito',
              hint: 'Leer, caminar, tomar agua…',
            );
            if (name != null && name.trim().isNotEmpty) {
              store.change(
                () => habits.add({
                  'id': newId(),
                  'name': name.trim(),
                  'checks': <String, dynamic>{},
                }),
              );
            }
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Agregar hábito'),
        ),
      ],
    );
  }

  Future<void> choosePhoto() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      if ((await file.length() ?? 13 * 1024 * 1024) > 1024 * 1024) {
        feedback('Elegí una imagen de hasta 1 MB para esta versión local.');
        return;
      }
      set('image', base64Encode(await file.readAsBytes()), history: true);
    } catch (_) {
      feedback('No se pudo abrir la imagen.');
    }
  }

  Widget photo() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (data['image'] is String)
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Decode(data['image'] as String),
            height: 160,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(
              height: 120,
              child: Center(child: Text('Formato de imagen no compatible.')),
            ),
          ),
        ),
      if (data['image'] == null)
        Container(
          height: 130,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.add_photo_alternate_outlined, size: 40),
          ),
        ),
      TextButton.icon(
        onPressed: choosePhoto,
        icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
        label: Text(data['image'] == null ? 'Elegir imagen' : 'Cambiar imagen'),
      ),
      EntryField(
        value: data['caption'] as String? ?? '',
        hint: 'La historia detrás de esta foto…',
        onChanged: (value) => set('caption', value),
      ),
    ],
  );
  Widget review() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        initialValue: data['category'] as String? ?? 'Libro',
        decoration: const InputDecoration(labelText: 'Tipo de experiencia'),
        items: [
          'Libro',
          'Película',
          'Serie',
          'Música',
          'Lugar',
          'Otra experiencia',
        ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (value) => set('category', value, history: true),
      ),
      const SizedBox(height: 12),
      EntryField(
        value: data['subject'] as String? ?? '',
        hint: 'Título o lugar',
        onChanged: (value) => set('subject', value),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          5,
          (i) => IconButton(
            tooltip: '${i + 1} estrellas',
            onPressed: () => set('rating', i + 1, history: true),
            icon: Icon(
              (data['rating'] as int? ?? 0) > i
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 26,
            ),
          ),
        ),
      ),
      EntryField(
        value: data['text'] as String? ?? '',
        minLines: 3,
        hint: '¿Qué te dejó esta experiencia?',
        onChanged: (value) => set('text', value),
      ),
    ],
  );
  Widget countdown() {
    final target = DateTime.tryParse(data['target'] as String? ?? '');
    final remaining = target == null
        ? null
        : DateTime.utc(target.year, target.month, target.day)
              .difference(
                DateTime.utc(
                  widget.date.year,
                  widget.date.month,
                  widget.date.day,
                ),
              )
              .inDays;
    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          remaining == null ? '—' : '${remaining.abs()}',
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w300,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          remaining == null
              ? 'Una fecha para esperar'
              : remaining == 0
              ? '¡Es hoy!'
              : remaining < 0
              ? 'días desde ese momento'
              : 'días para ese momento',
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final selected = await showDatePicker(
              context: context,
              initialDate: target ?? widget.date,
              firstDate: DateTime(1900),
              lastDate: DateTime(2200),
            );
            if (selected != null) {
              set('target', dayKey(selected), history: true);
            }
          },
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(
            target == null
                ? 'Elegir fecha'
                : DateFormat('d MMM yyyy', 'es').format(target),
          ),
        ),
      ],
    );
  }
}
