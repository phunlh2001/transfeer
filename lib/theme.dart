import 'package:flutter/material.dart';

import 'models/etf_quote.dart';

class AppTheme {
  static const Color seed = Color(0xFF3D5AFE);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          b == Brightness.dark ? const Color(0xFF0E1116) : const Color(0xFFF5F6FA),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: b == Brightness.dark ? const Color(0xFF171B22) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Vietnamese market colour convention.
class MarketColors {
  static const up = Color(0xFF16C784);
  static const down = Color(0xFFEA3943);
  static const ref = Color(0xFFF0B90B);
  static const ceiling = Color(0xFFB45CFF);
  static const floor = Color(0xFF1FB6D9);

  static Color forPrice(double price, EtfQuote q) {
    if (q.ceiling > 0 && price >= q.ceiling) return ceiling;
    if (q.floor > 0 && price <= q.floor) return floor;
    if (price > q.ref) return up;
    if (price < q.ref) return down;
    return ref;
  }
}
