import 'package:flutter/material.dart';
import '../data/planner_store.dart';
import '../models/planner.dart';

class SketchEditor extends StatefulWidget {
  const SketchEditor({super.key, required this.block, required this.store});
  final PlannerBlock block;
  final PlannerStore store;
  @override
  State<SketchEditor> createState() => _SketchEditorState();
}

class _SketchEditorState extends State<SketchEditor> {
  List<Offset> active = [];
  final List<Map<String, dynamic>> redo = [];
  Color color = const Color(0xFF354C3A);
  double width = 3;
  List<Map<String, dynamic>> get strokes =>
      (widget.block.data['strokes'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Offset normalized(Offset point, Size size) => Offset(
    (point.dx / size.width).clamp(0, 1),
    (point.dy / size.height).clamp(0, 1),
  );
  void update(List<Map<String, dynamic>> value) =>
      widget.store.change(() => widget.block.data['strokes'] = value);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...[
            const Color(0xFF354C3A),
            const Color(0xFF4269A5),
            const Color(0xFFB75560),
          ].map(
            (c) => IconButton(
              tooltip: 'Color del lápiz',
              onPressed: () => setState(() => color = c),
              icon: Icon(
                color == c ? Icons.radio_button_checked : Icons.circle,
                color: c,
                size: 20,
              ),
            ),
          ),
          IconButton(
            onPressed: strokes.isEmpty
                ? null
                : () {
                    final values = strokes;
                    redo.add(values.removeLast());
                    update(values);
                  },
            icon: const Icon(Icons.undo, size: 18),
            tooltip: 'Deshacer trazo',
          ),
          IconButton(
            onPressed: redo.isEmpty
                ? null
                : () {
                    final values = strokes;
                    values.add(redo.removeLast());
                    update(values);
                  },
            icon: const Icon(Icons.redo, size: 18),
            tooltip: 'Rehacer trazo',
          ),
        ],
      ),
      Row(
        children: [
          const Text('Grosor', style: TextStyle(fontSize: 11)),
          Expanded(
            child: Slider(
              value: width,
              min: 1,
              max: 10,
              divisions: 9,
              label: width.toInt().toString(),
              onChanged: (value) => setState(() => width = value),
            ),
          ),
        ],
      ),
      Container(
        height: 210,
        decoration: BoxDecoration(
          color: const Color(0xFFFAF8F1),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, bounds) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => setState(
              () =>
                  active = [normalized(details.localPosition, bounds.biggest)],
            ),
            onPanUpdate: (details) => setState(
              () =>
                  active.add(normalized(details.localPosition, bounds.biggest)),
            ),
            onPanEnd: (_) {
              if (active.isEmpty) return;
              final values = strokes
                ..add({
                  'color': color.toARGB32(),
                  'width': width,
                  'points': active.map((p) => [p.dx, p.dy]).toList(),
                });
              active = [];
              redo.clear();
              update(values);
            },
            onPanCancel: () => setState(() => active = []),
            child: CustomPaint(
              size: bounds.biggest,
              painter: SketchPainter(
                strokes: strokes,
                active: active,
                color: color,
                width: width,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Dibujá con lápiz, dedo o mouse.',
        style: TextStyle(fontSize: 11),
      ),
    ],
  );
}

class SketchPainter extends CustomPainter {
  SketchPainter({
    required this.strokes,
    required this.active,
    required this.color,
    required this.width,
  });
  final List<Map<String, dynamic>> strokes;
  final List<Offset> active;
  final Color color;
  final double width;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFE5E2D7)
      ..strokeWidth = .6;
    for (double y = 24; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    void draw(List<Offset> points, Color color, double width) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (points.isEmpty) return;
      if (points.length == 1) {
        canvas.drawCircle(
          Offset(points.first.dx * size.width, points.first.dy * size.height),
          width / 2,
          Paint()..color = color,
        );
        return;
      }
      final path = Path()
        ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }

    for (final stroke in strokes) {
      draw(
        (stroke['points'] as List)
            .map(
              (p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
            )
            .toList(),
        Color(stroke['color'] as int),
        (stroke['width'] as num).toDouble(),
      );
    }
    draw(active, color, width);
  }

  @override
  bool shouldRepaint(covariant SketchPainter oldDelegate) => true;
}
