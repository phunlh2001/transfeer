import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/portfolio_store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/portfolio.dart';
import '../widgets/app_background.dart';
import '../widgets/lottie_view.dart';

final _date = DateFormat('dd/MM/yyyy');

/// "Tài sản" tab:
///  1. current total (entered once, editable),
///  2. DCA purchases added on top (weekly/monthly buys),
///  3. gain/loss and a 5–10 year projection with a weekly/monthly DCA plan.
///
/// Uses [livePrice] when the market is open, otherwise the last price saved by
/// [PortfolioStore] (no API calls are made from here).
class PortfolioScreen extends StatefulWidget {
  final double? livePrice;
  final DateTime? livePriceAt;
  const PortfolioScreen({super.key, this.livePrice, this.livePriceAt});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final _amountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  bool _synced = false;
  bool _showAllBuys = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  void _syncFields(PortfolioStore s) {
    if (_synced || !s.loaded) return;
    _synced = true;
    _amountCtrl.text = s.dcaAmount > 0 ? fmtNum(s.dcaAmount) : '';
    _rateCtrl.text = s.rateOverridePct == null ? '' : fmtRate(s.rateOverridePct!);
  }

  void _setAmount(PortfolioStore s, double v) {
    final t = v > 0 ? fmtNum(v) : '';
    _amountCtrl.value =
        TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
    s.setDcaAmount(v);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<PortfolioStore>();
    final cs = Theme.of(context).colorScheme;
    if (!s.loaded) return const Center(child: CircularProgressIndicator());
    _syncFields(s);

    final live = widget.livePrice != null;
    final price = widget.livePrice ?? s.lastPrice;
    final priceAt = live ? widget.livePriceAt : s.lastPriceAt;
    final h = s.holding;
    final hasHolding = h != null && h.isValid;
    final perf = (hasHolding && price != null) ? evaluate(h, price, DateTime.now(), s.buys) : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tài sản của tôi',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Theo dõi tiền vốn, lãi/lỗ và dự phóng tài sản của bạn.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 8),
          const LottieView('growth', size: 84),
        ]),
        const SizedBox(height: 16),
        if (!hasHolding)
          _EmptyCard(
            onEnterTotal: () => _editTotal(context, s, price),
            onFirstBuy: () => _addBuy(context, s, price),
          )
        else ...[
          _SummaryCard(
            holding: h,
            perf: perf,
            onEdit: () => _editTotal(context, s, price),
          ),
          const SizedBox(height: 8),
          _PriceSource(live: live, price: price, at: priceAt),
          const SizedBox(height: 16),
          _buysCard(context, s, price),
          const SizedBox(height: 16),
          _projectionCard(context, s, h, perf),
        ],
      ],
    );
  }

  // ------------------------------------------------------------ DCA log
  Widget _buysCard(BuildContext context, PortfolioStore s, double? price) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final buys = s.buys;
    final total = buys.fold<double>(0, (a, b) => a + b.cost);
    final shown = _showAllBuys ? buys : buys.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.shopping_cart_checkout_rounded, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Mua thêm (DCA)',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            buys.isEmpty
                ? 'Mỗi lần mua thêm hằng tuần/hằng tháng, hãy ghi lại ở đây. '
                    'Số tiền và số CCQ sẽ được cộng vào tổng tài sản.'
                : '${buys.length} lần mua · tổng ${fmtVnd(total)}',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _addBuy(context, s, price),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm lần mua', style: TextStyle(fontSize: 16)),
            ),
          ),
          if (buys.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final (i, b) in shown.indexed) ...[
              if (i > 0) const Divider(height: 1),
              _BuyTile(b, onDelete: () => _confirmDelete(context, s, b)),
            ],
            if (buys.length > 5)
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _showAllBuys = !_showAllBuys),
                  child: Text(_showAllBuys ? 'Thu gọn' : 'Xem tất cả (${buys.length})'),
                ),
              ),
          ],
        ]),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, PortfolioStore s, Purchase b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá lần mua này?'),
        content: Text(
            '${fmtNum(b.units)} CCQ × ${fmtVnd(b.price)} ngày ${_date.format(b.date)}.\n'
            'Số tiền ${fmtVnd(b.cost)} và ${fmtNum(b.units)} CCQ sẽ được trừ khỏi tổng tài sản.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: MarketColors.down),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok == true) await s.removePurchase(b);
  }

  // ------------------------------------------------------------ projection
  Widget _projectionCard(
      BuildContext context, PortfolioStore s, Holding h, Performance? perf) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final f = s.dcaFreq;
    final autoPct = perf?.annualRate == null ? null : perf!.annualRate! * 100;
    final ratePct = s.rateOverridePct ?? autoPct;
    final rateError = ratePct != null && (ratePct < -90 || ratePct > 200)
        ? 'Hãy nhập trong khoảng -90% đến 200%'
        : null;
    final presets = f == DcaFrequency.weekly ? const [500e3, 1e6, 2e6] : const [1e6, 2e6, 5e6, 10e6];

    String? helper;
    if (s.rateOverridePct == null && autoPct != null) {
      helper = 'Đang dùng mức tăng trưởng của bạn. Nhập số khác để thay đổi.';
    } else if (s.rateOverridePct == null && autoPct == null) {
      helper = h.since == null
          ? 'Thêm ngày bắt đầu đầu tư (bấm ✎ ở thẻ tài sản) để ứng dụng tự tính, hoặc tự nhập % ở đây.'
          : 'Cần ít nhất $minDays ngày đầu tư để tự tính. Bạn có thể tự nhập % ở đây.';
    }

    final proj = (perf != null && ratePct != null && rateError == null)
        ? project(
            startValue: perf.value,
            startContributed: h.invested,
            amount: s.dcaAmount,
            annualRate: ratePct / 100,
            years: s.years,
            perYear: f.perYear,
          )
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.trending_up_rounded, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Dự phóng tài sản',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 16),

          // DCA plan
          Text('Kế hoạch mua định kỳ (DCA)',
              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<DcaFrequency>(
              segments: [
                for (final x in DcaFrequency.values)
                  ButtonSegment(value: x, label: Text(x.label, style: const TextStyle(fontSize: 15))),
              ],
              selected: {f},
              showSelectedIcon: false,
              onSelectionChanged: (v) => s.setDcaFreq(v.first),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            onChanged: (t) => s.setDcaAmount(parseVnd(t)),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: 'Số tiền mua mỗi ${f.unit}',
              hintText: '0',
              prefixIcon: const Icon(Icons.savings_rounded),
              suffixText: '₫',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(
              label: const Text('Không mua thêm', style: TextStyle(fontSize: 15)),
              selected: s.dcaAmount == 0,
              onSelected: (_) => _setAmount(s, 0),
            ),
            for (final p in presets)
              ChoiceChip(
                label: Text(fmtWordsVnd(p), style: const TextStyle(fontSize: 15)),
                selected: s.dcaAmount == p,
                onSelected: (_) => _setAmount(s, p),
              ),
          ]),
          const SizedBox(height: 20),

          // growth rate
          TextField(
            controller: _rateCtrl,
            keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))],
            onChanged: (t) => s.setRateOverride(parsePercent(t)),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: 'Tăng trưởng mỗi năm',
              hintText: autoPct != null ? fmtRate(autoPct) : 'VD: 10',
              prefixIcon: const Icon(Icons.percent_rounded),
              suffixText: '%/năm',
              helperText: helper,
              helperMaxLines: 3,
              errorText: rateError,
            ),
          ),
          if (s.rateOverridePct != null && autoPct != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  _rateCtrl.clear();
                  s.setRateOverride(null);
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text('Dùng mức của tôi (${fmtRate(autoPct)}%/năm)'),
              ),
            ),
          if (s.rateOverridePct == null && perf?.isShortPeriod == true) ...[
            const SizedBox(height: 10),
            const _Notice(
              'Bạn mới đầu tư chưa đến 1 năm nên mức tăng trưởng này có thể chưa sát thực tế. '
              'Hãy cân nhắc tự nhập một mức hợp lý hơn.',
            ),
          ],
          const SizedBox(height: 20),

          // horizon
          Text('Thời gian', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var y = 5; y <= 10; y++)
              ChoiceChip(
                label: Text('$y năm', style: const TextStyle(fontSize: 15)),
                selected: s.years == y,
                onSelected: (_) => s.setYears(y),
              ),
          ]),
          const SizedBox(height: 20),

          if (proj == null)
            Text(
              perf == null
                  ? 'Cần có giá FUESSV30 để dự phóng. Hãy mở ứng dụng trong giờ giao dịch một lần.'
                  : 'Nhập mức tăng trưởng mỗi năm để xem dự phóng.',
              style: TextStyle(color: cs.onSurfaceVariant),
            )
          else ...[
            _ProjectionHero(proj: proj, years: s.years),
            const SizedBox(height: 12),
            _Line('Tổng vốn góp', fmtVnd(proj.contributed), icon: Icons.account_balance_wallet_rounded),
            const Divider(height: 1),
            _Line('Trong đó mua thêm', fmtVnd(s.dcaAmount * f.perYear * s.years),
                icon: Icons.savings_rounded),
            const Divider(height: 1),
            _Line(
              'Lợi nhuận dự kiến',
              '${fmtSigned(proj.profit)} ₫ (${fmtPct(proj.profitPct)})',
              icon: Icons.auto_graph_rounded,
              color: proj.profit >= 0 ? MarketColors.up : MarketColors.down,
            ),
            const SizedBox(height: 16),
            _ProjectionChart(proj: proj),
            const SizedBox(height: 12),
            Text(
              'Chỉ mang tính tham khảo: giả định tài sản tăng đều ${fmtRate(ratePct!)}%/năm, '
              'mua thêm vào cuối mỗi ${f.unit}, chưa tính phí giao dịch và thuế.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, height: 1.4),
            ),
          ],
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------- sheets
  Future<void> _editTotal(BuildContext context, PortfolioStore s, double? price) async {
    final result = await showModalBottomSheet<_TotalResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TotalSheet(initial: s.holding, price: price, buyCount: s.buys.length),
    );
    if (result == null) return;
    if (result.clear) {
      await s.clear();
    } else {
      await s.setHolding(result.holding!);
    }
  }

  Future<void> _addBuy(BuildContext context, PortfolioStore s, double? price) async {
    final b = await showModalBottomSheet<Purchase>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BuySheet(price: price, defaultAmount: s.dcaAmount),
    );
    if (b != null) await s.addPurchase(b);
  }
}

// =============================================================== widgets

class _EmptyCard extends StatelessWidget {
  final VoidCallback onEnterTotal;
  final VoidCallback onFirstBuy;
  const _EmptyCard({required this.onEnterTotal, required this.onFirstBuy});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const LottieView('coins', size: 120),
          const SizedBox(height: 8),
          Text('Bắt đầu theo dõi tài sản',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Nhập tổng số tiền bạn đã đầu tư và số CCQ FUESSV30 đang có. '
            'Sau đó, mỗi lần mua thêm bạn chỉ cần ghi lại. Dữ liệu chỉ lưu trên máy của bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onEnterTotal,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Nhập tài sản hiện có', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onFirstBuy,
            child: const Text('Chưa có? Ghi lại lần mua đầu tiên'),
          ),
        ]),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Holding holding;
  final Performance? perf;
  final VoidCallback onEdit;
  const _SummaryCard({required this.holding, required this.perf, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const on = AppTheme.onHero;
    final p = perf;
    final up = (p?.gain ?? 0) >= 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: AppTheme.heroGradient(cs),
      ),
      padding: const EdgeInsets.fromLTRB(22, 10, 8, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Giá trị hiện tại',
                style: TextStyle(color: on.withValues(alpha: 0.85), fontSize: 15)),
          ),
          IconButton(
            tooltip: 'Sửa tổng tài sản',
            onPressed: onEdit,
            icon: Icon(Icons.edit_rounded, color: on),
          ),
        ]),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            p == null ? '—' : fmtVnd(p.value),
            style: TextStyle(
              color: on,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (p != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 18, color: up ? MarketColors.up : MarketColors.down),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${up ? 'Lãi' : 'Lỗ'} ${fmtNum(p.gain.abs())} ₫ (${fmtPct(p.gainPct)})',
                  style: TextStyle(
                    color: up ? const Color(0xFF0E8A5C) : MarketColors.down,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ]),
          ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Row(children: [
            _Mini('Tổng tiền vốn', fmtCompactVnd(holding.invested), on),
            _Mini('Số CCQ', fmtNum(holding.units), on),
            _Mini('Giá vốn TB', fmtNum(holding.avgCost), on),
          ]),
        ),
        if (p?.annualRate != null) ...[
          const SizedBox(height: 14),
          Text(
            'Tăng trưởng bình quân ${p!.annualRate! < 0 ? '−' : '+'}'
            '${fmtRate((p.annualRate! * 100).abs())}%/năm'
            '${holding.since == null ? '' : ' kể từ ${_date.format(holding.since!)}'}',
            style: TextStyle(color: on.withValues(alpha: 0.9), fontSize: 14),
          ),
        ],
      ]),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Mini(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 13)),
          const SizedBox(height: 2),
          Text(value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      );
}

class _BuyTile extends StatelessWidget {
  final Purchase b;
  final VoidCallback onDelete;
  const _BuyTile(this.b, {required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.add_shopping_cart_rounded, size: 18, color: cs.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('+${fmtNum(b.units)} CCQ × ${fmtNum(b.price)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text('${_date.format(b.date)} · ${fmtVnd(b.cost)}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ]),
        ),
        IconButton(
          tooltip: 'Xoá lần mua',
          onPressed: onDelete,
          icon: Icon(Icons.delete_outline_rounded, color: cs.onSurfaceVariant),
        ),
      ]),
    );
  }
}

class _PriceSource extends StatelessWidget {
  final bool live;
  final double? price;
  final DateTime? at;
  const _PriceSource({required this.live, required this.price, required this.at});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final String text;
    if (price == null) {
      text = 'Chưa có giá FUESSV30. Mở ứng dụng trong giờ giao dịch để lấy giá.';
    } else if (live) {
      text = 'Theo giá trực tiếp ${fmtVnd(price!)}${at == null ? '' : ' · lúc ${fmtTime(at!)}'}';
    } else {
      text = 'Theo giá gần nhất ${fmtVnd(price!)}'
          '${at == null ? '' : ' · ${DateFormat('HH:mm, dd/MM').format(at!)}'}';
    }
    return Row(children: [
      Icon(live ? Icons.bolt_rounded : Icons.history_rounded, size: 16, color: cs.onSurfaceVariant),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
    ]);
  }
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MarketColors.ref.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, color: MarketColors.ref, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4))),
        ]),
      );
}

class _ProjectionHero extends StatelessWidget {
  final Projection proj;
  final int years;
  const _ProjectionHero({required this.proj, required this.years});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sau $years năm, tài sản dự kiến',
            style: TextStyle(color: cs.onPrimaryContainer.withValues(alpha: 0.85), fontSize: 15)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            fmtVnd(proj.finalValue),
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text('≈ ${fmtWordsVnd(proj.finalValue)} đồng',
            style: TextStyle(color: cs.onPrimaryContainer.withValues(alpha: 0.85))),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color? color;
  const _Line(this.label, this.value, {required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 12),
        Flexible(flex: 2, child: Text(label, style: TextStyle(color: cs.onSurfaceVariant))),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
        ),
      ]),
    );
  }
}

class _ProjectionChart extends StatelessWidget {
  final Projection proj;
  const _ProjectionChart({required this.proj});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pts = proj.points;
    final maxY = pts.map((p) => p.value > p.contributed ? p.value : p.contributed).reduce((a, b) => a > b ? a : b);
    final minY = pts.map((p) => p.value < p.contributed ? p.value : p.contributed).reduce((a, b) => a < b ? a : b);

    Widget legend(Color c, String t, {bool dashed = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 14,
            height: dashed ? 2 : 4,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 6),
          Text(t, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 16, children: [
        legend(cs.primary, 'Tài sản dự kiến'),
        legend(cs.outline, 'Tiền vốn góp', dashed: true),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: pts.last.year.toDouble(),
            minY: minY < 0 ? minY * 1.1 : 0,
            maxY: maxY * 1.1,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: cs.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 56,
                  getTitlesWidget: (v, meta) {
                    if (v == meta.max || v == meta.min) return const SizedBox.shrink();
                    return Text(fmtCompactVnd(v),
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11));
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 26,
                  getTitlesWidget: (v, meta) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(v == 0 ? 'Nay' : 'N${v.toInt()}',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  ),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => cs.inverseSurface,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      s.barIndex == 0
                          ? '${s.x == 0 ? 'Hiện tại' : 'Năm ${s.x.toInt()}'}\nTài sản: ${fmtCompactVnd(s.y)}'
                          : 'Vốn: ${fmtCompactVnd(s.y)}',
                      TextStyle(color: cs.onInverseSurface, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [for (final p in pts) FlSpot(p.year.toDouble(), p.value)],
                isCurved: true,
                curveSmoothness: 0.2,
                color: cs.primary,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [cs.primary.withValues(alpha: 0.25), cs.primary.withValues(alpha: 0.0)],
                  ),
                ),
              ),
              LineChartBarData(
                spots: [for (final p in pts) FlSpot(p.year.toDouble(), p.contributed)],
                color: cs.outline,
                barWidth: 2,
                dashArray: [6, 4],
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 300),
        ),
      ),
    ]);
  }
}

// ============================================================ sheet bits

/// Bottom-sheet frame: title, subtitle, scrollable body, Cancel/primary row.
class _Sheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? leading; // e.g. a delete button
  final String primaryLabel;
  final VoidCallback? onPrimary;
  const _Sheet({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Fields scroll; the action row stays pinned at the bottom (above the keyboard).
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: leading),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
              const SizedBox(width: 8),
              FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime? value;
  final String emptyLabel;
  final String label;
  final ValueChanged<DateTime> onPicked;
  const _DateField(
      {required this.value, required this.emptyLabel, required this.label, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(2014),
          lastDate: now,
          helpText: label,
          cancelText: 'Huỷ',
          confirmText: 'Chọn',
        );
        if (d != null) onPicked(d);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        alignment: Alignment.centerLeft,
      ),
      icon: const Icon(Icons.event_rounded),
      label: Text(value == null ? emptyLabel : '$label: ${_date.format(value!)}',
          style: const TextStyle(fontSize: 15)),
    );
  }
}

TextField _vndField(TextEditingController c,
        {required String label,
        required IconData icon,
        String suffix = '₫',
        bool autofocus = false,
        required VoidCallback onChanged}) =>
    TextField(
      controller: c,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [ThousandsFormatter()],
      onChanged: (_) => onChanged(),
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), suffixText: suffix),
    );

// ------------------------------------------------------- total (editable)

class _TotalResult {
  final Holding? holding;
  final bool clear;
  const _TotalResult(this.holding) : clear = false;
  const _TotalResult.clear()
      : holding = null,
        clear = true;
}

class _TotalSheet extends StatefulWidget {
  final Holding? initial;
  final double? price;
  final int buyCount;
  const _TotalSheet({required this.initial, required this.price, required this.buyCount});

  @override
  State<_TotalSheet> createState() => _TotalSheetState();
}

class _TotalSheetState extends State<_TotalSheet> {
  late final _invested = TextEditingController(
      text: widget.initial == null ? '' : fmtNum(widget.initial!.invested));
  late final _units = TextEditingController(
      text: widget.initial == null ? '' : fmtNum(widget.initial!.units));
  late DateTime? _since = widget.initial?.since;

  @override
  void dispose() {
    _invested.dispose();
    _units.dispose();
    super.dispose();
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá toàn bộ dữ liệu?'),
        content: const Text('Tổng tài sản và lịch sử mua thêm sẽ bị xoá khỏi máy.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: MarketColors.down),
            child: const Text('Xoá hết'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context, const _TotalResult.clear());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final invested = parseVnd(_invested.text);
    final units = parseVnd(_units.text);
    final valid = invested > 0 && units > 0;
    final editing = widget.initial != null && widget.initial!.isValid;

    return _Sheet(
      title: editing ? 'Sửa tổng tài sản' : 'Tài sản hiện có',
      subtitle: widget.buyCount > 0
          ? 'Tổng hiện tại đã gồm ${widget.buyCount} lần mua thêm. '
              'Sửa ở đây chỉ thay đổi tổng, không đổi lịch sử mua.'
          : 'Nhập tổng số tiền bạn đã bỏ vào và số CCQ đang có. Chỉ lưu trên máy của bạn.',
      leading: editing
          ? TextButton(
              onPressed: _confirmClear,
              style: TextButton.styleFrom(foregroundColor: MarketColors.down),
              child: const Text('Xoá dữ liệu'),
            )
          : null,
      primaryLabel: 'Lưu',
      onPrimary: valid
          ? () => Navigator.pop(
              context, _TotalResult(Holding(invested: invested, units: units, since: _since)))
          : null,
      children: [
        _vndField(_invested,
            label: 'Tổng tiền đã đầu tư',
            icon: Icons.account_balance_wallet_rounded,
            autofocus: !editing,
            onChanged: () => setState(() {})),
        const SizedBox(height: 14),
        _vndField(_units,
            label: 'Số CCQ đang có',
            icon: Icons.layers_rounded,
            suffix: 'CCQ',
            onChanged: () => setState(() {})),
        const SizedBox(height: 14),
        _DateField(
          value: _since,
          label: 'Bắt đầu đầu tư',
          emptyLabel: 'Ngày bắt đầu đầu tư (không bắt buộc)',
          onPicked: (d) => setState(() => _since = d),
        ),
        const SizedBox(height: 6),
        Text('Dùng để tính mức tăng trưởng mỗi năm của bạn.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        if (valid) ...[
          const SizedBox(height: 14),
          Text(
            'Giá vốn trung bình: ${fmtVnd(invested / units)}/CCQ'
            '${widget.price == null ? '' : ' · giá hiện tại ${fmtVnd(widget.price!)}'}',
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

// ----------------------------------------------------------- DCA buy sheet

enum _BuyMode { money, units }

class _BuySheet extends StatefulWidget {
  final double? price;
  final double defaultAmount;
  const _BuySheet({required this.price, required this.defaultAmount});

  @override
  State<_BuySheet> createState() => _BuySheetState();
}

class _BuySheetState extends State<_BuySheet> {
  late final _amount =
      TextEditingController(text: widget.defaultAmount > 0 ? fmtNum(widget.defaultAmount) : '');
  final _units = TextEditingController();
  late final _price =
      TextEditingController(text: widget.price == null ? '' : fmtNum(widget.price!));
  DateTime _dateValue = DateTime.now();
  _BuyMode _mode = _BuyMode.money;

  @override
  void dispose() {
    _amount.dispose();
    _units.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final price = parseVnd(_price.text);
    final money = parseVnd(_amount.text);
    final units = _mode == _BuyMode.money ? unitsFor(money, price) : parseVnd(_units.text);
    final cost = units * price;
    final valid = units > 0 && price > 0;
    void refresh() => setState(() {});

    return _Sheet(
      title: 'Thêm lần mua',
      subtitle: 'Ghi lại một lần mua thêm (DCA). Số tiền và số CCQ sẽ được cộng vào tổng tài sản.',
      primaryLabel: 'Thêm',
      onPrimary: valid
          ? () => Navigator.pop(
              context,
              Purchase(
                id: DateTime.now().microsecondsSinceEpoch,
                date: _dateValue,
                price: price,
                units: units,
              ))
          : null,
      children: [
        _DateField(
          value: _dateValue,
          label: 'Ngày mua',
          emptyLabel: 'Ngày mua',
          onPicked: (d) => setState(() => _dateValue = d),
        ),
        const SizedBox(height: 14),
        _vndField(_price, label: 'Giá mua mỗi CCQ', icon: Icons.sell_rounded, onChanged: refresh),
        if (widget.price != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text('Giá gần nhất: ${fmtVnd(widget.price!)}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ),
        const SizedBox(height: 14),
        SegmentedButton<_BuyMode>(
          segments: const [
            ButtonSegment(value: _BuyMode.money, label: Text('Theo số tiền')),
            ButtonSegment(value: _BuyMode.units, label: Text('Theo số CCQ')),
          ],
          selected: {_mode},
          showSelectedIcon: false,
          onSelectionChanged: (v) => setState(() => _mode = v.first),
        ),
        const SizedBox(height: 14),
        if (_mode == _BuyMode.money)
          _vndField(_amount,
              label: 'Số tiền mua',
              icon: Icons.payments_rounded,
              autofocus: widget.defaultAmount == 0 && widget.price != null,
              onChanged: refresh)
        else
          _vndField(_units,
              label: 'Số CCQ mua', icon: Icons.layers_rounded, suffix: 'CCQ', onChanged: refresh),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            !valid
                ? (price <= 0
                    ? 'Nhập giá mua mỗi CCQ.'
                    : _mode == _BuyMode.money && money > 0
                        ? 'Số tiền chưa đủ mua 1 CCQ (cần ${fmtVnd(price)}).'
                        : 'Nhập ${_mode == _BuyMode.money ? 'số tiền' : 'số CCQ'} để xem kết quả.')
                : 'Mua ${fmtNum(units)} CCQ · thành tiền ${fmtVnd(cost)}'
                    '${_mode == _BuyMode.money && money - cost > 0 ? '\nTiền dư: ${fmtVnd(money - cost)}' : ''}',
            style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600, height: 1.4),
          ),
        ),
      ],
    );
  }
}

/// Full-screen page used outside trading hours (opened from the closed screen).
class PortfolioPage extends StatelessWidget {
  const PortfolioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: const Column(children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(padding: EdgeInsets.fromLTRB(4, 4, 0, 0), child: BackButton()),
                ),
                Expanded(child: PortfolioScreen()),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
