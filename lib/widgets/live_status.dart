import 'package:flutter/material.dart';

import '../state/etf_controller.dart';
import '../utils/format.dart';

/// "● LIVE · Updated 10:21:05" plus a ring counting down to the next poll.
class LiveStatus extends StatelessWidget {
  final EtfController c;
  const LiveStatus({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ok = c.error == null && c.quote != null;
    final color = ok ? const Color(0xFF16C784) : cs.error;
    return Row(
      children: [
        _PulseDot(color: color),
        const SizedBox(width: 8),
        Text(ok ? 'TRỰC TIẾP' : (c.quote == null ? 'ĐANG KẾT NỐI' : 'MẤT KẾT NỐI'),
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            c.lastUpdated == null ? '' : 'Cập nhật lúc ${fmtTime(c.lastUpdated!)}',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (c.lastTickAt != null)
          _Countdown(
            key: ValueKey(c.lastTickAt),
            duration: EtfController.interval,
          ),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _a,
        builder: (_, _) => Stack(alignment: Alignment.center, children: [
          Container(
            width: 6 + 8 * _a.value,
            height: 6 + 8 * _a.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.35 * (1 - _a.value)),
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
          ),
        ]),
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  final Duration duration;
  const _Countdown({super.key, required this.duration});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: duration,
      builder: (_, v, _) => SizedBox(
        width: 22,
        height: 22,
        child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(
            value: v,
            strokeWidth: 2.5,
            backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
          ),
          Text('${(v * duration.inSeconds).ceil()}',
              style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
