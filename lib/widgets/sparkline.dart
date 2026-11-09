import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/etf_quote.dart';
import '../state/etf_controller.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Line chart of prices polled during this session, with the reference line.
class Sparkline extends StatelessWidget {
  final List<PricePoint> points;
  final EtfQuote q;
  const Sparkline({super.key, required this.points, required this.q});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = MarketColors.forPrice(q.price, q);
    final spots = [
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].price)
    ];
    final prices = [...points.map((p) => p.price), q.ref];
    var minY = prices.reduce((a, b) => a < b ? a : b);
    var maxY = prices.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.2).clamp(50.0, double.infinity);
    minY -= pad;
    maxY += pad;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Live session',
                  style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${points.length} ticks · every 5s',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: points.length < 2
                  ? Center(
                      child: Text('Collecting data…',
                          style: TextStyle(color: cs.onSurfaceVariant)))
                  : LineChart(
                      LineChartData(
                        minY: minY,
                        maxY: maxY,
                        minX: 0,
                        maxX: (points.length - 1).toDouble(),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        extraLinesData: ExtraLinesData(horizontalLines: [
                          HorizontalLine(
                            y: q.ref,
                            color: MarketColors.ref.withValues(alpha: 0.6),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                        ]),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => cs.inverseSurface,
                            getTooltipItems: (spots) => [
                              for (final s in spots)
                                LineTooltipItem(
                                  '${fmtNum(s.y)}\n${fmtTime(points[s.x.toInt()].time)}',
                                  TextStyle(
                                      color: cs.onInverseSurface,
                                      fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            curveSmoothness: 0.2,
                            color: color,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  color.withValues(alpha: 0.25),
                                  color.withValues(alpha: 0.0)
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(milliseconds: 250),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
