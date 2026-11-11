import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/etf_quote.dart';
import '../services/etf_api.dart';

class PricePoint {
  final DateTime time;
  final double price;
  const PricePoint(this.time, this.price);
}

/// Polls the ETF endpoint every [interval] and exposes the latest quote.
class EtfController extends ChangeNotifier with WidgetsBindingObserver {
  static const Duration interval = Duration(seconds: 5);
  static const int maxHistory = 120;

  final EtfApi _api;

  /// Called after every successful poll (used to remember the last price).
  final void Function(double price, DateTime at)? onPrice;
  Timer? _timer;
  bool _inFlight = false;
  bool _disposed = false;

  EtfQuote? quote;
  DateTime? lastUpdated;
  DateTime? lastTickAt;
  String? error;
  final List<PricePoint> history = [];

  EtfController({EtfApi? api, bool autoStart = true, this.onPrice})
      : _api = api ?? EtfApi() {
    WidgetsBinding.instance.addObserver(this);
    if (autoStart) start();
  }

  bool get isLoading => quote == null && error == null;
  bool get isRunning => _timer != null;

  void start() {
    _timer?.cancel();
    refresh();
    _timer = Timer.periodic(interval, (_) => refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    if (_inFlight) return;
    _inFlight = true;
    lastTickAt = DateTime.now();
    notifyListeners();
    try {
      final q = await _api.fetchQuote();
      if (_disposed) return;
      quote = q;
      lastUpdated = DateTime.now();
      error = null;
      history.add(PricePoint(lastUpdated!, q.price));
      if (history.length > maxHistory) history.removeAt(0);
      onPrice?.call(q.price, lastUpdated!);
    } catch (e) {
      if (_disposed) return;
      error = _friendly(e);
    } finally {
      _inFlight = false;
      if (!_disposed) notifyListeners();
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('TimeoutException')) {
      return 'Máy chủ phản hồi chậm (có thể đang khởi động). Vui lòng chờ…';
    }
    if (s.contains('ClientException') || s.contains('SocketException')) {
      return 'Lỗi kết nối mạng. Vui lòng kiểm tra Internet.';
    }
    return s.replaceFirst(RegExp(r'^\w*Exception: '), '');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_timer == null) start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      stop();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
