import 'package:flutter/material.dart';
import '../models/planner.dart';

IconData blockIcon(BlockKind kind) => switch (kind) {
  BlockKind.note => Icons.notes_outlined,
  BlockKind.tasks => Icons.checklist_outlined,
  BlockKind.schedule => Icons.schedule_outlined,
  BlockKind.week => Icons.view_week_outlined,
  BlockKind.month => Icons.calendar_month_outlined,
  BlockKind.mood => Icons.sentiment_satisfied_alt,
  BlockKind.habits => Icons.spa_outlined,
  BlockKind.pomodoro => Icons.timelapse_outlined,
  BlockKind.sketch => Icons.draw_outlined,
  BlockKind.photo => Icons.photo_outlined,
  BlockKind.review => Icons.auto_stories_outlined,
  BlockKind.countdown => Icons.event_outlined,
};

Future<String?> askText(
  BuildContext context,
  String title, {
  String value = '',
  String? hint,
}) async {
  final controller = TextEditingController(text: value);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  // The route may still be animating its TextField after showDialog resolves.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  controller.dispose();
  return result;
}

/// Keeps the caret during autosave and refreshes when undo/import changes data.
class EntryField extends StatefulWidget {
  const EntryField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.minLines = 1,
    this.maxLines,
    this.style,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int minLines;
  final int? maxLines;
  final TextStyle? style;
  @override
  State<EntryField> createState() => _EntryFieldState();
}

class _EntryFieldState extends State<EntryField> {
  late final TextEditingController controller = TextEditingController(
    text: widget.value,
  );
  @override
  void didUpdateWidget(EntryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.text != widget.value) {
      controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: widget.onChanged,
    style: widget.style,
    minLines: widget.minLines,
    maxLines: widget.maxLines,
    decoration: InputDecoration(hintText: widget.hint),
  );
}
