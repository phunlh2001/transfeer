import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../utils/market_hours.dart';

/// Tracks whether HOSE is in a trading session and notifies on changes.
///
/// Re-checks precisely at each session boundary, every 30s as a safety net,
/// and whenever the app returns to the foreground.
///
/// Debug builds accept `--dart-define=FORCE_MARKET=open|closed` to test both
/// states at any time of day.
class MarketSession extends ChangeNotifier with WidgetsBindingObserver {
  static const String _force = String.fromEnvironment('FORCE_MARKET');

  final DateTime Function() _clock;
  Timer? _periodic;
  Timer? _boundary;

  late MarketPhase phase;
  late bool isOpen;

  MarketSession({DateTime Function()? clock}) : _clock = clock ?? vnNow {
    _compute();
    _periodic = Timer.periodic(const Duration(seconds: 30), (_) => check());
    _scheduleBoundary();
    WidgetsBinding.instance.addObserver(this);
  }

  DateTime get now => _clock();
  DateTime get nextOpenAt => nextOpen(now);
  DateTime? get sessionEndsAt => sessionEnd(now);
  bool get isForced => kDebugMode && (_force == 'open' || _force == 'closed');

  void _compute() {
    phase = phaseOf(now);
    if (kDebugMode && _force == 'open') {
      isOpen = true;
    } else if (kDebugMode && _force == 'closed') {
      isOpen = false;
    } else {
      isOpen = isTradingTime(now);
    }
  }

  void check() {
    final oldPhase = phase;
    final oldOpen = isOpen;
    _compute();
    if (oldPhase != phase || oldOpen != isOpen) notifyListeners();
  }

  void _scheduleBoundary() {
    _boundary?.cancel();
    final wait = nextBoundary(now).difference(now) + const Duration(milliseconds: 500);
    _boundary = Timer(wait, () {
      check();
      _scheduleBoundary();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      check();
      _scheduleBoundary();
    }
  }

  @override
  void dispose() {
    _periodic?.cancel();
    _boundary?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
