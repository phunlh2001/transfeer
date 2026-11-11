import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/app_version.dart';
import '../widgets/app_background.dart';
import '../widgets/lottie_view.dart';

/// ~1s branded loading screen shown on launch.
class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  final Duration minDuration;
  const SplashScreen({
    super.key,
    required this.onDone,
    this.minDuration = const Duration(milliseconds: 1100),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final v = appVersion().then((v) {
      if (mounted) setState(() => _version = v);
    });
    await Future.wait([v, Future<void>.delayed(widget.minDuration)]);
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(children: [
            const Spacer(flex: 3),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: AppTheme.heroGradient(cs),
                boxShadow: [
                  BoxShadow(
                      color: cs.primary.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 10)),
                ],
              ),
              child: const Icon(Icons.show_chart_rounded, color: Colors.white, size: 52),
            ),
            const SizedBox(height: 20),
            Text('Transfeer',
                style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Theo dõi quỹ ETF FUESSV30',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 28),
            const LottieView('loading', size: 120, height: 80),
            const Spacer(flex: 4),
            AnimatedOpacity(
              opacity: _version.isEmpty ? 0 : 1,
              duration: const Duration(milliseconds: 250),
              child: Text('Phiên bản $_version',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}
