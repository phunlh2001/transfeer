import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/etf_controller.dart';
import '../theme.dart';
import '../utils/calculator.dart';
import '../utils/format.dart';
import '../widgets/lottie_view.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with AutomaticKeepAliveClientMixin {
  final _ctrl = TextEditingController();
  static const _presets = [1e6, 5e6, 10e6, 50e6, 100e6];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setAmount(double v) {
    final t = fmtNum(v);
    _ctrl.value = TextEditingValue(
        text: t, selection: TextSelection.collapsed(offset: t.length));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.watch<EtfController>();
    final q = c.quote;
    final cs = Theme.of(context).colorScheme;
    final money = parseVnd(_ctrl.text);
    final r = q == null ? null : calcUnits(money, q.price);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Mua được bao nhiêu chứng chỉ quỹ?',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Nhập tổng số tiền (VND) bạn muốn đầu tư vào quỹ FUESSV30.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 8),
          const LottieView('coins', size: 84),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsFormatter()],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText: '0',
            labelText: 'Số tiền đầu tư',
            prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
            suffixText: '₫',
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() {});
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in _presets)
            ActionChip(
              label: Text(fmtWordsVnd(p), style: const TextStyle(fontSize: 15)),
              onPressed: () => _setAmount(p),
            ),
        ]),
        const SizedBox(height: 20),
        if (q == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(children: [
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 16),
                Expanded(
                    child: Text(c.error ?? 'Đang tải giá mới nhất…',
                        style: TextStyle(color: cs.onSurfaceVariant))),
              ]),
            ),
          )
        else ...[
          _ResultHero(units: r!.units, active: money > 0),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(children: [
                _Row('Giá trung bình mỗi CCQ',
                    r.avgPerUnit == null ? '—' : fmtVnd(r.avgPerUnit!),
                    icon: Icons.functions_rounded),
                const Divider(height: 1),
                _Row('Tổng tiền mua', fmtVnd(r.cost), icon: Icons.shopping_bag_rounded),
                const Divider(height: 1),
                _Row('Tiền còn dư', fmtVnd(r.leftover),
                    icon: Icons.savings_rounded),
              ]),
            ),
          ),
          if (money > 0 && r.units == 0) ...[
            const SizedBox(height: 12),
            Card(
              color: MarketColors.ref.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: MarketColors.ref),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        'Bạn cần thêm ${fmtVnd(r.shortfall)} để mua được 1 CCQ.'),
                  ),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Icon(Icons.bolt_rounded, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Tính theo giá hiện tại ${fmtVnd(q.price)}'
                '${c.lastUpdated == null ? '' : ' · lúc ${fmtTime(c.lastUpdated!)}'}'
                ' · chưa gồm phí giao dịch',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ),
          ]),
        ],
      ],
    );
  }
}

class _ResultHero extends StatelessWidget {
  final int units;
  final bool active;
  const _ResultHero({required this.units, required this.active});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primary,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Số chứng chỉ quỹ mua được',
              style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.8))),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(end: units.toDouble()),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            builder: (_, v, _) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                active ? fmtNum(v) : '0',
                style: TextStyle(
                  color: cs.onPrimary,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          Text('CCQ FUESSV30',
              style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.8))),
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Row(this.label, this.value, {required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
      ]),
    );
  }
}
