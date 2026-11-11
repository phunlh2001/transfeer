import 'dart:ui';

import 'package:flutter/material.dart';

/// Soft gradient backdrop with blurred colour blobs (the "illustration" layer
/// behind every screen).
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final a = dark ? 0.26 : 0.22;

    Widget blob(Color c, double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: a)),
        );

    return Stack(children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? const [Color(0xFF12122A), Color(0xFF0B0D14)]
                  : const [Color(0xFFEEF0FF), Color(0xFFF8F9FC)],
            ),
          ),
        ),
      ),
      Positioned(top: -120, right: -80, child: blob(cs.primary, 300)),
      Positioned(top: 160, left: -140, child: blob(cs.secondary, 260)),
      Positioned(bottom: -140, right: -60, child: blob(cs.tertiary, 240)),
      Positioned.fill(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: const SizedBox.expand(),
        ),
      ),
      Positioned.fill(child: child),
    ]);
  }
}
