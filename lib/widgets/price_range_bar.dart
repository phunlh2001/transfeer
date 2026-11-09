import 'package:flutter/material.dart';

import '../models/etf_quote.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Floor ↔ ceiling bar showing the day's low–high band, the reference
/// marker and the current price.
class PriceRangeBar extends StatelessWidget {
  final EtfQuote q;
  const PriceRangeBar({super.key, required this.q});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final span = (q.ceiling - q.floor);
    double pos(double v) => span <= 0 ? 0.5 : ((v - q.floor) / span).clamp(0.0, 1.0);
    final priceColor = MarketColors.forPrice(q.price, q);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's range",
                style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth;
              return SizedBox(
                height: 28,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 11,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: const LinearGradient(colors: [
                          MarketColors.floor,
                          MarketColors.down,
                          MarketColors.ref,
                          MarketColors.up,
                          MarketColors.ceiling,
                        ]),
                      ),
                    ),
                  ),
                  // low-high band
                  Positioned(
                    left: w * pos(q.low),
                    width: (w * (pos(q.high) - pos(q.low))).clamp(2.0, w),
                    top: 8,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  // ref marker
                  Positioned(
                    left: w * pos(q.ref) - 1,
                    top: 4,
                    child: Container(width: 2, height: 20, color: MarketColors.ref),
                  ),
                  // price marker
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    left: w * pos(q.price) - 9,
                    top: 5,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: priceColor,
                        border: Border.all(color: cs.surface, width: 3),
                        boxShadow: [
                          BoxShadow(color: priceColor.withValues(alpha: 0.5), blurRadius: 8)
                        ],
                      ),
                    ),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 10),
            Row(children: [
              _Label('Floor', q.floor, MarketColors.floor),
              const Spacer(),
              _Label('Ref', q.ref, MarketColors.ref, center: true),
              const Spacer(),
              _Label('Ceiling', q.ceiling, MarketColors.ceiling, end: true),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String title;
  final double v;
  final Color color;
  final bool center;
  final bool end;
  const _Label(this.title, this.v, this.color, {this.center = false, this.end = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: end
          ? CrossAxisAlignment.end
          : center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(fmtNum(v), style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
