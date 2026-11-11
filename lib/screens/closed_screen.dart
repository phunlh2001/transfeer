import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/market_session.dart';
import '../utils/app_version.dart';
import '../utils/format.dart';
import '../utils/market_hours.dart';
import '../widgets/app_background.dart';
import '../widgets/lottie_view.dart';
import '../widgets/update_sheet.dart';
import 'portfolio_screen.dart';

/// Shown outside trading hours. Makes no API calls.
class ClosedScreen extends StatefulWidget {
  const ClosedScreen({super.key});

  @override
  State<ClosedScreen> createState() => _ClosedScreenState();
}

class _ClosedScreenState extends State<ClosedScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// "09:00", "ngày mai lúc 09:00" or "Thứ Hai lúc 09:00".
  String _when(DateTime next, DateTime now) {
    final time = DateFormat('HH:mm').format(next);
    final today = DateTime.utc(now.year, now.month, now.day);
    final day = DateTime.utc(next.year, next.month, next.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'lúc $time';
    if (diff == 1) return 'ngày mai lúc $time';
    return '${weekdayVi(next.weekday)} lúc $time';
  }

  (String, String) _copy(MarketSession s) {
    final when = _when(s.nextOpenAt, s.now);
    return switch (s.phase) {
      MarketPhase.beforeOpen => ('Sắp mở cửa', 'Phiên giao dịch bắt đầu $when'),
      MarketPhase.lunchBreak => ('Nghỉ trưa', 'Giao dịch tiếp tục $when'),
      MarketPhase.weekend => ('Cuối tuần vui vẻ!', 'Thị trường mở cửa lại vào $when'),
      MarketPhase.afterClose => ('Thị trường đã đóng cửa', 'Hẹn gặp lại bạn $when'),
      _ => ('Tạm dừng cập nhật', 'Đang ép trạng thái đóng cửa (chế độ debug)'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<MarketSession>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final (title, subtitle) = _copy(s);
    var left = s.nextOpenAt.difference(s.now);
    if (left.isNegative) left = Duration.zero;
    String two(int n) => n.toString().padLeft(2, '0');
    final days = left.inDays;
    final countdown =
        '${two(left.inHours % 24)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  Row(children: [
                    Text('Transfeer',
                        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Kiểm tra cập nhật',
                      onPressed: () => checkForUpdates(context, manual: true),
                      icon: const Icon(Icons.system_update_rounded),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  const Center(child: LottieView('market_closed', size: 260, height: 225)),
                  const SizedBox(height: 8),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16, height: 1.4)),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      child: Column(children: [
                        Text('Giá sẽ cập nhật trở lại sau',
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
                        const SizedBox(height: 6),
                        if (days > 0)
                          Text('$days ngày',
                              style: tt.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800, color: cs.primary)),
                        Text(countdown,
                            style: tt.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.primary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            )),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PortfolioPage()),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.account_balance_wallet_rounded),
                    label: const Text('Xem tài sản của tôi'),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.schedule_rounded, size: 20, color: cs.primary),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('Giờ giao dịch (sàn HOSE, Thứ Hai – Thứ Sáu)',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final (i, label) in tradingSessionsLabel.indexed)
                            Chip(
                              avatar: Icon(
                                  i == 0 ? Icons.wb_sunny_rounded : Icons.wb_twilight_rounded,
                                  size: 18),
                              label: Text('${i == 0 ? 'Sáng' : 'Chiều'}  $label',
                                  style: const TextStyle(fontSize: 15)),
                            ),
                        ]),
                        const SizedBox(height: 10),
                        Text(
                            'Theo giờ Việt Nam. Ngoài giờ giao dịch, ứng dụng tạm dừng cập nhật giá.',
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 14, height: 1.4)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<String>(
                    future: appVersion(),
                    builder: (_, snap) => Text(
                      snap.hasData ? 'Phiên bản ${snap.data}' : '',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
