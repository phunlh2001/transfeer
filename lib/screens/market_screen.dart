import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/etf_controller.dart';
import '../widgets/live_status.dart';
import '../widgets/price_header.dart';
import '../widgets/price_range_bar.dart';
import '../widgets/sparkline.dart';
import '../widgets/stat_grid.dart';

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<EtfController>();
    final q = c.quote;
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          LiveStatus(c: c),
          const SizedBox(height: 12),
          if (c.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.wifi_off_rounded, color: cs.onErrorContainer),
                  title: Text(c.error!, style: TextStyle(color: cs.onErrorContainer)),
                  subtitle: q == null
                      ? null
                      : Text('Đang hiển thị giá gần nhất',
                          style: TextStyle(color: cs.onErrorContainer)),
                  trailing: IconButton(
                    icon: Icon(Icons.refresh_rounded, color: cs.onErrorContainer),
                    onPressed: c.refresh,
                  ),
                ),
              ),
            ),
          if (q == null)
            const _Skeleton()
          else ...[
            PriceHeader(q: q),
            const SizedBox(height: 12),
            PriceRangeBar(q: q),
            const SizedBox(height: 12),
            StatGrid(q: q),
            const SizedBox(height: 12),
            Sparkline(points: List.of(c.history), q: q),
          ],
        ],
      ),
    );
  }
}

class _Skeleton extends StatefulWidget {
  const _Skeleton();
  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    Widget box(double h) => AnimatedBuilder(
          animation: _a,
          builder: (_, _) => Container(
            height: h,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: base.withValues(alpha: 0.05 + 0.06 * _a.value),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
    return Column(children: [box(190), box(110), box(140), box(180)]);
  }
}
