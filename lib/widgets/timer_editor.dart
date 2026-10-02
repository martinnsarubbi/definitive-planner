import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/planner_store.dart';
import '../models/planner.dart';
import '../models/focus_timer.dart';

class TimerEditor extends StatefulWidget {
  const TimerEditor({super.key, required this.block, required this.store});
  final PlannerBlock block;
  final PlannerStore store;
  @override
  State<TimerEditor> createState() => _TimerEditorState();
}

class _TimerEditorState extends State<TimerEditor> {
  late final Timer ticker;
  Map<String, dynamic> get data => widget.block.data;
  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (data['endsAt'] != null &&
          remainingSeconds(data, DateTime.now()) == 0) {
        widget.store.change(() {
          data.remove('endsAt');
          data['remaining'] = (data['minutes'] as int? ?? 25) * 60;
          data['sessions'] = (data['sessions'] as int? ?? 0) + 1;
          data['completed'] = true;
        }, history: false);
        SystemSound.play(SystemSoundType.alert);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = remainingSeconds(data, DateTime.now());
    final running = data['endsAt'] != null;
    return Column(
      children: [
        Wrap(
          spacing: 6,
          children: [25, 5, 15]
              .map(
                (minutes) => ChoiceChip(
                  label: Text(minutes == 25 ? 'Foco' : '${minutes}m pausa'),
                  selected: (data['minutes'] as int? ?? 25) == minutes,
                  onSelected: running
                      ? null
                      : (_) => widget.store.change(() {
                          data['minutes'] = minutes;
                          data['remaining'] = minutes * 60;
                          data['completed'] = false;
                        }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        Text(
          '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.w300,
            color: Theme.of(context).colorScheme.primary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (data['completed'] == true)
          const Text('Sesión terminada. Tomate un respiro.'),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => widget.store.change(() {
                data['completed'] = false;
                if (running) {
                  data['remaining'] = seconds;
                  data.remove('endsAt');
                } else {
                  data['endsAt'] =
                      DateTime.now().millisecondsSinceEpoch + seconds * 1000;
                }
              }, history: false),
              icon: Icon(running ? Icons.pause : Icons.play_arrow),
              label: Text(running ? 'Pausar' : 'Iniciar'),
            ),
            IconButton(
              onPressed: () => widget.store.change(() {
                data.remove('endsAt');
                data['remaining'] = (data['minutes'] as int? ?? 25) * 60;
                data['completed'] = false;
              }, history: false),
              icon: const Icon(Icons.restart_alt),
              tooltip: 'Reiniciar temporizador',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${data['sessions'] ?? 0} sesiones completadas',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
