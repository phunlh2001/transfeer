import 'package:flutter/material.dart';

import '../models/etf_quote.dart';
import '../theme.dart';
import '../utils/format.dart';

class StatGrid extends StatelessWidget {
  final EtfQuote q;
  const StatGrid({super.key, required this.q});

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, IconData, Color?)>[
      ('Cao nhất', fmtNum(q.high), Icons.north_east_rounded, MarketColors.forPrice(q.high, q)),
      ('Thấp nhất', fmtNum(q.low), Icons.south_east_rounded, MarketColors.forPrice(q.low, q)),
      ('Khối lượng', fmtNum(q.volume), Icons.bar_chart_rounded, null),
      ('Giá trị', fmtCompactVnd(q.value), Icons.payments_rounded, null),
    ];
    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth > 560 ? 4 : 2;
      const gap = 12.0;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final it in items)
            SizedBox(width: w, child: _Tile(it.$1, it.$2, it.$3, it.$4)),
        ],
      );
    });
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  const _Tile(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (color ?? cs.primary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color ?? cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16, color: color)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
