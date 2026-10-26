import 'dart:math';

import 'package:flutter/material.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/dates.dart';
import 'package:bowie/features/diary/domain/pet_event.dart';
import 'package:bowie/features/pets/domain/weight.dart';

/// The pet's weight over time, from the weighings in the diary: dates on the
/// horizontal axis, kg on the vertical one.
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.points, required this.petName});

  /// The oldest first, at least one.
  final List<WeightPoint> points;
  final String petName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final first = points.first;
    final last = points.last;
    final change = roundWeight(last.kg - first.kg);
    final summary = points.length == 1
        ? 'Um registro: ${formatKg(last.kg)} em ${formatDayBr(last.day)}.'
        : change == 0
        ? 'Sem mudança desde ${formatDayBr(first.day)}.'
        : '${change > 0 ? '+' : '−'}${formatKg(change.abs())} desde '
              '${formatDayBr(first.day)}.';
    return Semantics(
      label:
          'Gráfico do peso de $petName. ${points.length} registros, de '
          '${formatKg(first.kg)} em ${formatDayBr(first.day)} a '
          '${formatKg(last.kg)} em ${formatDayBr(last.day)}.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary,
            style: BowieType.callout.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: BowieSpacing.s3),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: _WeightPainter(
                points: points,
                line: colors.link,
                grid: colors.border,
                label: BowieType.caption.copyWith(color: colors.textMuted),
                textScaler: MediaQuery.textScalerOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "05/10/26": short enough for the axis.
String shortDay(DateTime day) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(day.day)}/${two(day.month)}/${two(day.year % 100)}';
}

/// The kg on the vertical axis: three steps that hold every weighing, with
/// some room above and below.
List<double> weightTicks(Iterable<double> values) {
  var low = values.reduce(min);
  var high = values.reduce(max);
  final pad = high == low ? max(1.0, high * 0.05) : (high - low) * 0.2;
  low = max(0, low - pad);
  high = high + pad;
  final step = _niceStep((high - low) / 2);
  low = (low / step).floorToDouble() * step;
  high = (high / step).ceilToDouble() * step;
  if (high - low < 2 * step) high = low + 2 * step;
  final ticks = <double>[];
  for (var value = low; value <= high + step / 2; value += step) {
    ticks.add(roundWeight(value));
  }
  return ticks;
}

double _niceStep(double raw) {
  final power = pow(10, (log(raw) / ln10).floor()).toDouble();
  for (final factor in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (raw <= factor * power) return max(0.1, factor * power);
  }
  return 10 * power;
}

class _WeightPainter extends CustomPainter {
  _WeightPainter({
    required this.points,
    required this.line,
    required this.grid,
    required this.label,
    required this.textScaler,
  });

  final List<WeightPoint> points;
  final Color line;
  final Color grid;
  final TextStyle label;
  final TextScaler textScaler;

  TextPainter _text(String text) => TextPainter(
    text: TextSpan(text: text, style: label),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final ticks = weightTicks(points.map((p) => p.kg));
    final yLabels = [for (final t in ticks) _text(formatKg(t))];
    final left = yLabels.map((t) => t.width).reduce(max) + BowieSpacing.s2;
    final firstX = _text(shortDay(points.first.day));
    final lastX = _text(shortDay(points.last.day));
    final bottom = firstX.height + BowieSpacing.s2;
    final chart = Rect.fromLTRB(
      left,
      yLabels.first.height / 2,
      size.width - lastX.width / 2,
      size.height - bottom,
    );

    final low = ticks.first, high = ticks.last;
    double y(double kg) =>
        chart.bottom - (kg - low) / (high - low) * chart.height;
    final start = points.first.day, end = points.last.day;
    final span = end.difference(start).inDays;
    double x(DateTime day) => span == 0
        ? chart.center.dx
        : chart.left + day.difference(start).inDays / span * chart.width;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < ticks.length; i++) {
      final ty = y(ticks[i]);
      canvas.drawLine(
        Offset(chart.left, ty),
        Offset(chart.right, ty),
        gridPaint,
      );
      yLabels[i].paint(
        canvas,
        Offset(
          left - BowieSpacing.s2 - yLabels[i].width,
          ty - yLabels[i].height / 2,
        ),
      );
    }

    final labelY = chart.bottom + BowieSpacing.s2;
    if (span == 0) {
      firstX.paint(canvas, Offset(chart.center.dx - firstX.width / 2, labelY));
    } else {
      firstX.paint(
        canvas,
        Offset(max(0, chart.left - firstX.width / 2), labelY),
      );
      lastX.paint(canvas, Offset(chart.right - lastX.width / 2, labelY));
    }

    final offsets = [for (final p in points) Offset(x(p.day), y(p.kg))];
    if (offsets.length > 1) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final offset in offsets.skip(1)) {
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    final dot = Paint()..color = line;
    for (final offset in offsets) {
      canvas.drawCircle(offset, 4, dot);
    }
  }

  @override
  bool shouldRepaint(_WeightPainter old) =>
      old.points != points ||
      old.line != line ||
      old.grid != grid ||
      old.label != label ||
      old.textScaler != textScaler;
}
