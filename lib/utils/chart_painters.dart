import 'package:flutter/material.dart';

class LineChartPainter extends CustomPainter {
  final List<double> values;
  final double minValue;
  final double maxValue;
  final Color lineColor;
  final List<String>? timeLabels;

  LineChartPainter({
    required this.values,
    required this.minValue,
    required this.maxValue,
    required this.lineColor,
    this.timeLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const bottomPadding = 16.0;
    const leftPadding = 30.0;
    final chartWidth = size.width - leftPadding;
    final chartHeight = size.height - bottomPadding;
    final range = maxValue - minValue;

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.5
      ..isAntiAlias = true;

    for (var i = 0; i < 3; i++) {
      final y = chartHeight * i / 2;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Min / max labels
    const labelStyle = TextStyle(color: Colors.white38, fontSize: 10);

    final maxTp = TextPainter(
      text: TextSpan(text: maxValue.toStringAsFixed(1), style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    maxTp.paint(canvas, const Offset(0, 0));

    final minTp = TextPainter(
      text: TextSpan(text: minValue.toStringAsFixed(1), style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    minTp.paint(canvas, Offset(0, chartHeight - minTp.height));

    // Build points
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = leftPadding +
          (values.length == 1
              ? chartWidth / 2
              : chartWidth * i / (values.length - 1));
      final normalized = range == 0 ? 0.5 : (values[i] - minValue) / range;
      final y = chartHeight - (normalized * chartHeight);
      points.add(Offset(x, y));
    }

    // Fill area under line
    final fillPath = Path()..moveTo(points.first.dx, chartHeight);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, chartHeight);
    fillPath.close();

    final fillPaint = Paint()
      ..color = lineColor.withOpacity(0.1)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(fillPath, fillPaint);

    // Polyline
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Data point circles
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final p in points) {
      canvas.drawCircle(p, 3, dotPaint);
    }

    // Time labels
    if (timeLabels != null && timeLabels!.isNotEmpty) {
      final firstTp = TextPainter(
        text: TextSpan(text: timeLabels!.first, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      firstTp.paint(canvas, Offset(leftPadding, chartHeight + 2));

      if (timeLabels!.length > 1) {
        final lastTp = TextPainter(
          text: TextSpan(text: timeLabels!.last, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          textDirection: TextDirection.ltr,
        )..layout();
        lastTp.paint(canvas, Offset(size.width - lastTp.width, chartHeight + 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double maxValue;
  final Color barColor;

  BarChartPainter({
    required this.values,
    required this.labels,
    required this.maxValue,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const topPadding = 14.0;
    const bottomPadding = 14.0;
    final chartHeight = size.height - topPadding - bottomPadding;

    // Baseline
    final baselinePaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.5
      ..isAntiAlias = true;
    final baselineY = topPadding + chartHeight;
    canvas.drawLine(Offset(0, baselineY), Offset(size.width, baselineY), baselinePaint);

    final barWidth = size.width / (values.length * 1.5);
    final totalSlotWidth = size.width / values.length;

    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (var i = 0; i < values.length; i++) {
      final centerX = totalSlotWidth * i + totalSlotWidth / 2;
      final barLeft = centerX - barWidth / 2;
      final normalized = maxValue == 0 ? 0.0 : values[i] / maxValue;
      final barHeight = normalized * chartHeight;
      final barTop = baselineY - barHeight;

      final rrect = RRect.fromRectAndCorners(
        Rect.fromLTWH(barLeft, barTop, barWidth, barHeight),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(rrect, barPaint);

      // Value label above bar
      final valueTp = TextPainter(
        text: TextSpan(
          text: values[i].toInt().toString(),
          style: const TextStyle(color: Colors.white54, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      valueTp.paint(canvas, Offset(centerX - valueTp.width / 2, barTop - valueTp.height - 1));

      // Bottom label
      if (i < labels.length) {
        final labelTp = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        labelTp.paint(canvas, Offset(centerX - labelTp.width / 2, baselineY + 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
