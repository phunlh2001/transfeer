import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/etf_controller.dart';
import '../state/market_session.dart';
import '../utils/app_version.dart';
import '../widgets/app_background.dart';
import '../widgets/lottie_view.dart';
import '../widgets/update_sheet.dart';
import 'calculator_screen.dart';
import 'market_screen.dart';
import 'portfolio_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

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
              child: Column(children: [
                const _Header(),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      const MarketScreen(),
                      const CalculatorScreen(),
                      Consumer<EtfController>(
                        builder: (_, c, _) => PortfolioScreen(
                          livePrice: c.quote?.price,
                          livePriceAt: c.lastUpdated,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          FocusScope.of(context).unfocus();
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.show_chart_rounded),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Thị trường',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate_rounded),
            label: 'Quy đổi',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Tài sản',
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final end = context.watch<MarketSession>().sessionEndsAt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primary.withValues(alpha: 0.18),
                cs.secondary.withValues(alpha: 0.18)
              ],
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: const LottieView('chart', size: 44),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Transfeer', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(
              end == null
                  ? 'Quỹ ETF FUESSV30 · HOSE'
                  : 'FUESSV30 · Phiên đến ${DateFormat('HH:mm').format(end)}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (v) {
            if (v == 'update') checkForUpdates(context, manual: true);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'update',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.system_update_rounded),
                title: Text('Kiểm tra cập nhật'),
              ),
            ),
            PopupMenuItem(
              enabled: false,
              child: FutureBuilder<String>(
                future: appVersion(),
                builder: (_, s) => Text('Phiên bản ${s.data ?? '…'}'),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}
