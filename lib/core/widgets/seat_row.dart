import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

const _seatColors = [
  (CwColors.pinkSoft, CwColors.pink),
  (CwColors.tealSoft, CwColors.teal),
  (CwColors.amberSoft, CwColors.amber),
];

/// Three overlapping seat circles for a group ride; taken seats show the
/// rider's initials, free seats a dashed ring.
class SeatRow extends StatelessWidget {
  const SeatRow({super.key, required this.initials, this.size = 28});

  final List<String?> initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 3 - 12,
      height: size,
      child: Stack(
        children: List.generate(3, (i) {
          final who = i < initials.length ? initials[i] : null;
          final (bg, fg) = _seatColors[i];
          return Positioned(
            left: (size - 6) * i,
            top: 0,
            child: Container(
              key: who == null ? const ValueKey('seat-empty') : null,
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: who == null ? CwColors.white : bg,
                border: Border.all(color: CwColors.white, width: 2),
              ),
              child: who == null
                  ? CustomPaint(
                      size: Size.square(size - 8),
                      painter: _DashedRing(),
                    )
                  : Text(
                      who,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
            ),
          );
        }),
      ),
    );
  }
}

class _DashedRing extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9C4D9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final r = size.width / 2 - 1;
    final c = size.center(Offset.zero);
    const dashes = 8;
    for (var i = 0; i < dashes; i++) {
      final start = i * 2 * math.pi / dashes;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        math.pi / dashes,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
