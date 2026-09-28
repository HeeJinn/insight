import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'basics.dart';

/// Chart colors, validated for colorblind separation and contrast against
/// the card surface in both modes (dataviz validator: every check passes,
/// CVD ΔE > 30). On-time is blue and late is orange rather than green and
/// orange, which fail protanopia separation.
class ChartColors {
  const ChartColors._();

  static const CupertinoDynamicColor primary =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF007AFF),
        darkColor: Color(0xFF0A84FF),
      );
  static const CupertinoDynamicColor late =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFD06A00),
        darkColor: Color(0xFFD47400),
      );
}

class ChartSeries {
  const ChartSeries(this.label, this.color);

  final String label;
  final Color color;
}

/// A column chart; with more than one series the columns stack, each
/// segment separated by a 2px surface gap.
class ColumnChart extends StatefulWidget {
  const ColumnChart({
    super.key,
    required this.labels,
    required this.values,
    required this.series,
    this.height = 200,
    this.format = _plain,
    this.highlight,
  });

  /// One per column.
  final List<String> labels;

  /// values[column][series].
  final List<List<double>> values;
  final List<ChartSeries> series;
  final double height;
  final String Function(double) format;

  /// Columns drawn in a lighter tone of their color (e.g. the late bins
  /// of an arrival histogram); null for none.
  final bool Function(int column)? highlight;

  static String _plain(double v) => v.round().toString();

  @override
  State<ColumnChart> createState() => _ColumnChartState();
}

class _ColumnChartState extends State<ColumnChart> {
  int? _active;

  static const _axisWidth = 36.0;
  static const _labelBand = 22.0;

  int? _indexAt(double dx, double width) {
    final n = widget.labels.length;
    if (n == 0) return null;
    final plot = width - _axisWidth;
    final i = ((dx - _axisWidth) / (plot / n)).floor();
    return i < 0 || i >= n ? null : i;
  }

  @override
  Widget build(BuildContext context) {
    final surface = InsightColors.card.resolveFrom(context);
    final grid = InsightColors.separator.resolveFrom(context);
    final ink = InsightColors.secondaryLabel.resolveFrom(context);

    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final totals = [
          for (final v in widget.values) v.fold(0.0, (a, b) => a + b),
        ];
        final ceiling = _niceCeiling(totals.fold(0.0, math.max));

        final chart = CustomPaint(
          size: Size(width, widget.height + _labelBand),
          painter: _ColumnPainter(
            labels: widget.labels,
            values: widget.values,
            colors: [for (final s in widget.series) s.color],
            ceiling: ceiling,
            active: _active,
            highlight: widget.highlight,
            surface: surface,
            grid: grid,
            ink: ink,
            format: widget.format,
            textStyle: InsightText.caption1.copyWith(
              color: ink,
              fontFeatures: InsightText.tabular,
            ),
            axisWidth: _axisWidth,
            labelBand: _labelBand,
          ),
        );

        final active = _active;
        return Semantics(
          label: _describe(totals),
          child: MouseRegion(
            onHover: (e) {
              final i = _indexAt(e.localPosition.dx, width);
              if (i != _active) setState(() => _active = i);
            },
            onExit: (_) => setState(() => _active = null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final i = _indexAt(d.localPosition.dx, width);
                HapticFeedback.selectionClick();
                setState(() => _active = i == _active ? null : i);
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  chart,
                  if (active != null)
                    _Tooltip(
                      anchorX:
                          _axisWidth +
                          (width - _axisWidth) /
                              widget.labels.length *
                              (active + 0.5),
                      width: width,
                      title: widget.labels[active],
                      rows: [
                        for (var s = 0; s < widget.series.length; s++)
                          (
                            widget.series[s],
                            widget.format(widget.values[active][s]),
                          ),
                      ],
                      total: widget.series.length > 1
                          ? widget.format(totals[active])
                          : null,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _describe(List<double> totals) {
    if (totals.isEmpty) return 'No data';
    final maxI = totals.indexOf(totals.reduce(math.max));
    return '${widget.labels.length} columns. Highest: ${widget.labels[maxI]}, '
        '${widget.format(totals[maxI])}.';
  }
}

class _ColumnPainter extends CustomPainter {
  _ColumnPainter({
    required this.labels,
    required this.values,
    required this.colors,
    required this.ceiling,
    required this.active,
    required this.highlight,
    required this.surface,
    required this.grid,
    required this.ink,
    required this.format,
    required this.textStyle,
    required this.axisWidth,
    required this.labelBand,
  });

  final List<String> labels;
  final List<List<double>> values;
  final List<Color> colors;
  final double ceiling;
  final int? active;
  final bool Function(int)? highlight;
  final Color surface;
  final Color grid;
  final Color ink;
  final String Function(double) format;
  final TextStyle textStyle;
  final double axisWidth;
  final double labelBand;

  @override
  void paint(Canvas canvas, Size size) {
    final plotHeight = size.height - labelBand;
    final plotWidth = size.width - axisWidth;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    // Hairline grid at quarters, labelled on the left.
    for (var t = 0; t <= 4; t++) {
      final y = plotHeight - plotHeight * t / 4;
      canvas.drawLine(Offset(axisWidth, y), Offset(size.width, y), gridPaint);
      _text(
        canvas,
        format(ceiling * t / 4),
        Offset(axisWidth - 6, y),
        align: TextAlign.right,
      );
    }

    final n = labels.length;
    if (n == 0) return;
    final slot = plotWidth / n;
    final barWidth = math.min(24.0, slot * 0.62);
    // Thin the x labels so they never collide.
    final every = math.max(1, (n / math.max(1, plotWidth ~/ 52)).ceil());

    for (var i = 0; i < n; i++) {
      final cx = axisWidth + slot * (i + 0.5);
      final dimmed = active != null && active != i;
      var base = plotHeight;
      final stack = values[i];
      final lastNonZero = stack.lastIndexWhere((v) => v > 0);
      for (var s = 0; s < stack.length; s++) {
        final v = stack[s];
        if (v <= 0) continue;
        final h = ceiling == 0 ? 0.0 : plotHeight * v / ceiling;
        // 2px surface gap between stacked segments.
        final top = base - h;
        final segBottom = s == 0 ? base : base - 2;
        if (segBottom - top <= 0) {
          base = top;
          continue;
        }
        var color = colors[s];
        if (highlight != null && highlight!(i)) {
          color = Color.lerp(color, surface, 0.35)!;
        }
        if (dimmed) color = color.withValues(alpha: 0.4);
        final rect = Rect.fromLTRB(
          cx - barWidth / 2,
          top,
          cx + barWidth / 2,
          segBottom,
        );
        final radius = s == lastNonZero
            ? const Radius.circular(4)
            : Radius.zero;
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius),
          Paint()..color = color,
        );
        base = top;
      }
      if (i % every == 0 || i == n - 1 && n <= 12) {
        _text(
          canvas,
          labels[i],
          Offset(cx, plotHeight + labelBand / 2 + 2),
          align: TextAlign.center,
          bold: active == i,
        );
      }
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor, {
    required TextAlign align,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: bold
            ? textStyle.copyWith(fontWeight: FontWeight.w600)
            : textStyle,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => anchor.dx - painter.width,
      TextAlign.center => anchor.dx - painter.width / 2,
      _ => anchor.dx,
    };
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(_ColumnPainter old) =>
      old.values != values ||
      old.active != active ||
      old.ceiling != ceiling ||
      old.surface != surface ||
      old.colors != colors;
}

/// A single-series line with a light area wash; hover or tap shows a
/// crosshair and the value.
class LineChart extends StatefulWidget {
  const LineChart({
    super.key,
    required this.labels,
    required this.values,
    required this.color,
    required this.seriesLabel,
    this.height = 160,
    this.format = ColumnChart._plain,
  });

  final List<String> labels;

  /// Null where there's no data; the line breaks there.
  final List<double?> values;
  final Color color;
  final String seriesLabel;
  final double height;
  final String Function(double) format;

  @override
  State<LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  int? _active;

  static const _axisWidth = 44.0;
  static const _labelBand = 22.0;

  int? _indexAt(double dx, double width) {
    final n = widget.labels.length;
    if (n == 0) return null;
    final i = ((dx - _axisWidth) / ((width - _axisWidth) / n)).floor();
    if (i < 0 || i >= n || widget.values[i] == null) return null;
    return i;
  }

  @override
  Widget build(BuildContext context) {
    final ink = InsightColors.secondaryLabel.resolveFrom(context);
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final present = widget.values.whereType<double>();
        final ceiling = _niceCeiling(
          present.isEmpty ? 0 : present.reduce(math.max),
        );
        final active = _active;
        return MouseRegion(
          onHover: (e) {
            final i = _indexAt(e.localPosition.dx, width);
            if (i != _active) setState(() => _active = i);
          },
          onExit: (_) => setState(() => _active = null),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final i = _indexAt(d.localPosition.dx, width);
              setState(() => _active = i == _active ? null : i);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: Size(width, widget.height + _labelBand),
                  painter: _LinePainter(
                    labels: widget.labels,
                    values: widget.values,
                    color: widget.color,
                    ceiling: ceiling,
                    active: active,
                    surface: InsightColors.card.resolveFrom(context),
                    grid: InsightColors.separator.resolveFrom(context),
                    format: widget.format,
                    textStyle: InsightText.caption1.copyWith(
                      color: ink,
                      fontFeatures: InsightText.tabular,
                    ),
                    axisWidth: _axisWidth,
                    labelBand: _labelBand,
                  ),
                ),
                if (active != null)
                  _Tooltip(
                    anchorX:
                        _axisWidth +
                        (width - _axisWidth) /
                            widget.labels.length *
                            (active + 0.5),
                    width: width,
                    title: widget.labels[active],
                    rows: [
                      (
                        ChartSeries(widget.seriesLabel, widget.color),
                        widget.format(widget.values[active]!),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.labels,
    required this.values,
    required this.color,
    required this.ceiling,
    required this.active,
    required this.surface,
    required this.grid,
    required this.format,
    required this.textStyle,
    required this.axisWidth,
    required this.labelBand,
  });

  final List<String> labels;
  final List<double?> values;
  final Color color;
  final double ceiling;
  final int? active;
  final Color surface;
  final Color grid;
  final String Function(double) format;
  final TextStyle textStyle;
  final double axisWidth;
  final double labelBand;

  @override
  void paint(Canvas canvas, Size size) {
    final plotHeight = size.height - labelBand;
    final plotWidth = size.width - axisWidth;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var t = 0; t <= 4; t++) {
      final y = plotHeight - plotHeight * t / 4;
      canvas.drawLine(Offset(axisWidth, y), Offset(size.width, y), gridPaint);
      _paintText(
        canvas,
        format(ceiling * t / 4),
        Offset(axisWidth - 6, y),
        right: true,
      );
    }
    final n = labels.length;
    if (n == 0) return;
    final slot = plotWidth / n;
    Offset point(int i) => Offset(
      axisWidth + slot * (i + 0.5),
      plotHeight - (ceiling == 0 ? 0 : plotHeight * values[i]! / ceiling),
    );

    // Contiguous runs of data, each drawn as its own line and wash.
    final runs = <List<int>>[];
    for (var i = 0; i < n; i++) {
      if (values[i] == null) continue;
      if (runs.isEmpty || runs.last.last != i - 1) {
        runs.add([i]);
      } else {
        runs.last.add(i);
      }
    }
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final run in runs) {
      final path = Path()..moveTo(point(run.first).dx, point(run.first).dy);
      for (final i in run.skip(1)) {
        path.lineTo(point(i).dx, point(i).dy);
      }
      final area = Path.from(path)
        ..lineTo(point(run.last).dx, plotHeight)
        ..lineTo(point(run.first).dx, plotHeight)
        ..close();
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.1));
      canvas.drawPath(path, line);
      if (run.length == 1) {
        canvas.drawCircle(point(run.first), 3, Paint()..color = color);
      }
    }

    final every = math.max(1, (n / math.max(1, plotWidth ~/ 52)).ceil());
    for (var i = 0; i < n; i += every) {
      _paintText(
        canvas,
        labels[i],
        Offset(axisWidth + slot * (i + 0.5), plotHeight + labelBand / 2 + 2),
        center: true,
      );
    }

    final a = active;
    if (a != null && values[a] != null) {
      final p = point(a);
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, plotHeight),
        gridPaint..color = grid,
      );
      // 8px marker with a 2px surface ring.
      canvas.drawCircle(p, 6, Paint()..color = surface);
      canvas.drawCircle(p, 4, Paint()..color = color);
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool right = false,
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final dx = right
        ? anchor.dx - painter.width
        : center
        ? anchor.dx - painter.width / 2
        : anchor.dx;
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values ||
      old.active != active ||
      old.ceiling != ceiling ||
      old.color != color;
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({
    required this.anchorX,
    required this.width,
    required this.title,
    required this.rows,
    this.total,
  });

  final double anchorX;
  final double width;
  final String title;
  final List<(ChartSeries, String)> rows;
  final String? total;

  static const _boxWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    final label = InsightColors.label.resolveFrom(context);
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    final left = (anchorX - _boxWidth / 2).clamp(
      0.0,
      math.max(0.0, width - _boxWidth),
    );
    return Positioned(
      left: left.toDouble(),
      top: -8,
      width: _boxWidth,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: InsightColors.elevatedCard.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: InsightText.footnote.copyWith(
                  color: secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              for (final (series, value) in rows)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: series.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          series.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: InsightText.footnote.copyWith(color: label),
                        ),
                      ),
                      Text(
                        value,
                        style: InsightText.footnote.copyWith(
                          color: label,
                          fontWeight: FontWeight.w600,
                          fontFeatures: InsightText.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
              if (total != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total',
                          style: InsightText.footnote.copyWith(
                            color: secondary,
                          ),
                        ),
                      ),
                      Text(
                        total!,
                        style: InsightText.footnote.copyWith(
                          color: label,
                          fontWeight: FontWeight.w600,
                          fontFeatures: InsightText.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Swatch-and-label keys; shown whenever a chart has two or more series.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.series});

  final List<ChartSeries> series;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final s in series)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: s.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                s.label,
                style: InsightText.footnote.copyWith(
                  color: InsightColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// A titled chart card with a switch to the same data as a table, so no
/// value is only reachable through color or hover.
class ChartCard extends StatefulWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.chart,
    required this.tableHeaders,
    required this.tableRows,
    this.subtitle,
    this.legend,
  });

  final String title;
  final String? subtitle;
  final Widget chart;
  final Widget? legend;
  final List<String> tableHeaders;
  final List<List<String>> tableRows;

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    final label = InsightColors.label.resolveFrom(context);
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    return InsightCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: InsightText.headline.copyWith(color: label),
                      ),
                      if (widget.subtitle != null)
                        Text(
                          widget.subtitle!,
                          style: InsightText.footnote.copyWith(
                            color: secondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              FillIconButton(
                icon: _table
                    ? CupertinoIcons.chart_bar_alt_fill
                    : CupertinoIcons.table,
                semanticLabel: _table ? 'Show Chart' : 'Show Table',
                size: 32,
                onPressed: () => setState(() => _table = !_table),
              ),
            ],
          ),
          if (widget.legend != null && !_table) ...[
            const SizedBox(height: 8),
            widget.legend!,
          ],
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _table
                ? _DataTable(
                    headers: widget.tableHeaders,
                    rows: widget.tableRows,
                  )
                : widget.chart,
          ),
        ],
      ),
    );
  }
}

class _DataTable extends StatelessWidget {
  const _DataTable({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final label = InsightColors.label.resolveFrom(context);
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    final separator = InsightColors.separator.resolveFrom(context);
    Widget row(List<String> cells, {bool header = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 0 ? 2 : 1,
              child: Text(
                cells[i],
                textAlign: i == 0 ? TextAlign.start : TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: InsightText.footnote.copyWith(
                  color: header ? secondary : label,
                  fontWeight: header ? FontWeight.w600 : FontWeight.w400,
                  fontFeatures: InsightText.tabular,
                ),
              ),
            ),
        ],
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: SingleChildScrollView(
        child: Column(
          children: [
            row(headers, header: true),
            for (final r in rows) ...[
              Container(height: 0.5, color: separator),
              row(r),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rounds [max] up to 1, 2, 2.5 or 5 × 10ⁿ so gridlines land on clean
/// numbers; at least 4 so a small chart still has four integer steps.
double _niceCeiling(double max) {
  if (max <= 4) return 4;
  final exp = math.pow(10, (math.log(max) / math.ln10).floor()).toDouble();
  for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (m * exp >= max) return m * exp;
  }
  return 10 * exp;
}
