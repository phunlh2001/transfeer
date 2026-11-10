import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Plays `assets/lottie/<name>.json`. Falls back to an icon if the file is
/// missing or invalid, so swapping animations can never crash the app.
class LottieView extends StatelessWidget {
  final String name;
  final double size;
  final double? height;
  final bool repeat;

  const LottieView(this.name, {super.key, this.size = 120, this.height, this.repeat = true});

  @override
  Widget build(BuildContext context) {
    final h = height ?? size;
    return SizedBox(
      width: size,
      height: h,
      child: Lottie.asset(
        'assets/lottie/$name.json',
        repeat: repeat,
        fit: BoxFit.contain,
        errorBuilder: (context, _, _) => Icon(
          Icons.auto_awesome_rounded,
          size: h * 0.5,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
