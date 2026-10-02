import 'package:flutter/material.dart';
import '../data/planner_store.dart';
import '../models/planner.dart';
import 'block_content.dart';
import 'editors.dart';

class BlockCard extends StatelessWidget {
  const BlockCard({
    super.key,
    required this.block,
    required this.store,
    required this.date,
    required this.onSelectDate,
    required this.index,
    this.focused = false,
  });
  final PlannerBlock block;
  final PlannerStore store;
  final DateTime date;
  final ValueChanged<DateTime> onSelectDate;
  final int index;
  final bool focused;

  Future<void> action(BuildContext context, String action) async {
    switch (action) {
      case 'rename':
        final title = await askText(
          context,
          'Título del widget',
          value: block.title,
        );
        if (title != null && title.trim().isNotEmpty) {
          store.change(() => block.title = title.trim());
        }
      case 'tags':
        final tags = await askText(
          context,
          'Etiquetas separadas por comas',
          value: block.tags.join(', '),
        );
        if (tags != null) {
          store.change(
            () => block.tags = tags
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toSet()
                .toList(),
          );
        }
      case 'duplicate':
        store.duplicate(date, block);
      case 'copy':
        final target = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(1900),
          lastDate: DateTime(2200),
        );
        if (target != null) store.copyTo(target, block);
      case 'delete':
        store.remove(date, block.id);
      case 'up':
        store.move(date, block.id, index - 1);
      case 'down':
        store.move(date, block.id, index + 1);
      case 'width':
        store.change(() => block.width = block.width % 3 + 1);
      case 'height':
        store.change(() => block.height = block.height % 3 + 1);
      case 'sticker':
        if (!context.mounted) return;
        final emoji = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Agregar sticker'),
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      [
                            '✨',
                            '🌱',
                            '☀️',
                            '🌙',
                            '💚',
                            '⭐',
                            '📚',
                            '☕',
                            '🌸',
                            '🎯',
                            '✈️',
                            '🎵',
                          ]
                          .map(
                            (emoji) => InkWell(
                              onTap: () => Navigator.pop(context, emoji),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 32),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ],
          ),
        );
        if (emoji != null) {
          store.change(
            () => block.stickers.add({
              'id': newId(),
              'emoji': emoji,
              'x': .7,
              'y': .15,
              'size': 38.0,
              'angle': 0.0,
            }),
          );
        }
      case 'focus':
        await showDialog<void>(
          context: context,
          builder: (context) => Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                title: Text(block.title),
                leading: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar enfoque',
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: ListenableBuilder(
                  listenable: store,
                  builder: (context, _) {
                    final matches = store
                        .blocks(date)
                        .where((b) => b.id == block.id);
                    if (matches.isEmpty) {
                      return const Center(
                        child: Text('Este widget ya no está en la página.'),
                      );
                    }
                    return BlockCard(
                      block: matches.first,
                      store: store,
                      date: date,
                      onSelectDate: (value) {
                        Navigator.pop(context);
                        onSelectDate(value);
                      },
                      index: index,
                      focused: true,
                    );
                  },
                ),
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 6, 4),
            child: Row(
              children: [
                if (!focused)
                  LongPressDraggable<String>(
                    data: block.id,
                    feedback: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(block.title),
                      ),
                    ),
                    child: Tooltip(
                      message: 'Mantené presionado para mover',
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.drag_indicator,
                          size: 18,
                          color: scheme.outline,
                        ),
                      ),
                    ),
                  ),
                Icon(blockIcon(block.kind), size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    block.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (!focused)
                  IconButton(
                    onPressed: () => action(context, 'focus'),
                    tooltip: 'Abrir en enfoque',
                    icon: const Icon(Icons.open_in_full, size: 16),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Opciones de ${block.title}',
                  onSelected: (value) => action(context, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text('Cambiar título'),
                    ),
                    const PopupMenuItem(
                      value: 'tags',
                      child: Text('Editar etiquetas'),
                    ),
                    const PopupMenuItem(
                      value: 'sticker',
                      child: Text('Agregar sticker'),
                    ),
                    if (!focused) ...[
                      PopupMenuItem(
                        value: 'width',
                        child: Text('Ancho: ${block.width} columna(s)'),
                      ),
                      PopupMenuItem(
                        value: 'height',
                        child: Text(
                          'Alto: ${['compacto', 'mediano', 'grande'][block.height - 1]}',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'up',
                        child: Text('Mover antes'),
                      ),
                      const PopupMenuItem(
                        value: 'down',
                        child: Text('Mover después'),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Duplicar'),
                      ),
                      const PopupMenuItem(
                        value: 'copy',
                        child: Text('Copiar a otra fecha'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar (se puede deshacer)'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (block.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                block.tags.map((t) => '#$t').join('  '),
                style: TextStyle(fontSize: 11, color: scheme.primary),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: LayoutBuilder(
                builder: (context, bounds) => Stack(
                  children: [
                    Positioned.fill(
                      child: SingleChildScrollView(
                        child: BlockContent(
                          block: block,
                          store: store,
                          date: date,
                          onSelectDate: onSelectDate,
                        ),
                      ),
                    ),
                    ...block.stickers.map(
                      (sticker) => Positioned(
                        left:
                            ((sticker['x'] as num).toDouble() *
                                    (bounds.maxWidth - 58))
                                .clamp(0, bounds.maxWidth),
                        top:
                            ((sticker['y'] as num).toDouble() *
                                    (bounds.maxHeight - 58))
                                .clamp(0, bounds.maxHeight),
                        child: GestureDetector(
                          onPanUpdate: (details) => store.change(() {
                            sticker['x'] =
                                ((sticker['x'] as num) +
                                        details.delta.dx /
                                            (bounds.maxWidth - 58))
                                    .clamp(0.0, 1.0);
                            sticker['y'] =
                                ((sticker['y'] as num) +
                                        details.delta.dy /
                                            (bounds.maxHeight - 58))
                                    .clamp(0.0, 1.0);
                          }, history: false),
                          onDoubleTap: () => store.change(
                            () =>
                                sticker['size'] = (sticker['size'] as num) >= 62
                                ? 26.0
                                : (sticker['size'] as num) + 12.0,
                          ),
                          onLongPress: () => showModalBottomSheet<void>(
                            context: context,
                            builder: (context) => SafeArea(
                              child: Wrap(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.rotate_right),
                                    title: const Text('Girar sticker'),
                                    onTap: () {
                                      store.change(
                                        () => sticker['angle'] =
                                            (sticker['angle'] as num) + .4,
                                      );
                                      Navigator.pop(context);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.delete_outline),
                                    title: const Text('Eliminar sticker'),
                                    onTap: () {
                                      store.change(
                                        () => block.stickers.remove(sticker),
                                      );
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          child: Tooltip(
                            message:
                                'Arrastrar · doble toque: tamaño · mantener: opciones',
                            child: Transform.rotate(
                              angle: (sticker['angle'] as num).toDouble(),
                              child: Text(
                                sticker['emoji'] as String,
                                style: TextStyle(
                                  fontSize: (sticker['size'] as num).toDouble(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return focused
        ? card
        : SizedBox(height: 350 + (block.height - 1) * 160, child: card);
  }
}
