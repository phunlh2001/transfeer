import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/etf_quote.dart';

class AppTheme {
  static const Color seed = Color(0xFF5B5BF7); // indigo → violet family

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: b,
      tertiary: const Color(0xFF8B5CF6),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
    final cardColor = dark
        ? const Color(0xFF1A1C2E).withValues(alpha: 0.82)
        : Colors.white.withValues(alpha: 0.86);

    return base.copyWith(
      textTheme: GoogleFonts.beVietnamProTextTheme(base.textTheme),
      scaffoldBackgroundColor: dark ? const Color(0xFF0B0D14) : const Color(0xFFF4F5FB),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : scheme.primary.withValues(alpha: 0.08),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.primary, width: 2),
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
