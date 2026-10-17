import 'package:flutter/material.dart';

import '../theme.dart';

const _seatColors = [
  (CwColors.pinkSoft, CwColors.pink),
  (CwColors.tealSoft, CwColors.teal),
  (CwColors.amberSoft, CwColors.amber),
];

/// Three seat circles for a group ride; taken seats show the rider's initials.
class SeatRow extends StatelessWidget {
  const SeatRow({super.key, required this.initials});

  final List<String?> initials;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final who = i < initials.length ? initials[i] : null;
        final (bg, fg) = _seatColors[i];
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: who == null
              ? Container(
                  key: const ValueKey('seat-empty'),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: CwColors.lilacLine, width: 2),
                  ),
                )
              : Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
                  child: Text(
                    who,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ),
        );
      }),
    );
  }
}
