import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/etf_quote.dart';

class AppTheme {
  // Bright "fresh finance" palette: sky blue = trust, teal = growth, gold = money.
  static const Color brand = Color(0xFF0284C7); // sky blue
  static const Color growth = Color(0xFF0D9488); // teal
  static const Color gold = Color(0xFFF59E0B); // gold

  /// Hero cards / logo tile: vivid blue → teal in both modes; put WHITE text
  /// on it ([onHero]).
  static LinearGradient heroGradient(ColorScheme cs) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brand, growth],
      );
  static const Color onHero = Colors.white;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    // Accent colours: the exact vivid brand values in light mode; in dark mode
    // the lighter "fidelity" tone of each, so they stay vivid on navy.
    // Containers (selected tab, tonal buttons, chips) use the soft tonal-spot
    // tints so they read as light washes instead of heavy blocks.
    ColorScheme soft(Color c) => ColorScheme.fromSeed(seedColor: c, brightness: b);
    ColorScheme vivid(Color c) => ColorScheme.fromSeed(
        seedColor: c, brightness: b, dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
    Color accent(Color c) => dark ? vivid(c).primary : c;
    Color onAccent(Color c) => dark ? vivid(c).onPrimary : Colors.white;

    final scheme = soft(brand).copyWith(
      primary: accent(brand),
      onPrimary: onAccent(brand),
      secondary: accent(growth),
      onSecondary: onAccent(growth),
      secondaryContainer: soft(growth).primaryContainer,
      onSecondaryContainer: soft(growth).onPrimaryContainer,
      tertiary: accent(gold),
      onTertiary: dark ? vivid(gold).onPrimary : Colors.black,
      tertiaryContainer: soft(gold).primaryContainer,
      onTertiaryContainer: soft(gold).onPrimaryContainer,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
    final cardColor = dark
        ? const Color(0xFF10223A).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.92);

    return base.copyWith(
      textTheme: GoogleFonts.beVietnamProTextTheme(base.textTheme),
      scaffoldBackgroundColor: dark ? const Color(0xFF08131F) : const Color(0xFFF6FAFE),
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
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
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
