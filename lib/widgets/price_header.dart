import 'package:flutter/material.dart';

import '../models/etf_quote.dart';
import '../theme.dart';
import '../utils/format.dart';

class PriceHeader extends StatelessWidget {
  final EtfQuote q;
  const PriceHeader({super.key, required this.q});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = MarketColors.forPrice(q.price, q);
    final icon = q.change > 0
        ? Icons.arrow_drop_up_rounded
        : q.change < 0
            ? Icons.arrow_drop_down_rounded
            : Icons.remove_rounded;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.02)],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(q.symbol,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(q.exchange,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(q.name, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.15), end: Offset.zero)
                      .animate(a),
                  child: child,
                ),
              ),
              child: Text(
                fmtNum(q.price),
                key: ValueKey(q.price),
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Icon(icon, color: color, size: 28),
              Text(fmtSigned(q.change),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(fmtPct(q.changePct),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Text('VND / unit',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ]),
          ],
        ),
      ),
    );
  }
}
