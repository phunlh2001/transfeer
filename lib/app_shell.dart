import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/closed_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'state/etf_controller.dart';
import 'state/market_session.dart';
import 'state/portfolio_store.dart';
import 'widgets/update_sheet.dart';

/// Splash → (market open ? live Home : Closed).
///
/// The [EtfController] only exists while the market is open: when the session
/// ends it is disposed, which stops the 5s polling entirely.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _ready = false;

  void _onSplashDone() {
    setState(() => _ready = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) checkForUpdates(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final open = context.select<MarketSession, bool>((s) => s.isOpen);

    final Widget child;
    if (!_ready) {
      child = SplashScreen(key: const ValueKey('splash'), onDone: _onSplashDone);
    } else if (open) {
      child = ChangeNotifierProvider(
        key: const ValueKey('open'),
        create: (ctx) => EtfController(onPrice: ctx.read<PortfolioStore>().recordPrice),
        child: const HomeScreen(),
      );
    } else {
      child = const ClosedScreen(key: ValueKey('closed'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.98, end: 1.0).animate(a),
          child: c,
        ),
      ),
      child: child,
    );
  }
}
