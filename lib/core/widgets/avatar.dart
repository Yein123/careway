import 'package:flutter/material.dart';

import '../theme.dart';

/// Rounded initials badge used for patients, helpers and members.
class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.size = 44, this.color = CwColors.primaryDark, this.background = CwColors.lilac});

  final String initials;
  final double size;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(size * 0.32)),
        child: Text(initials, style: TextStyle(fontSize: size * 0.34, fontWeight: FontWeight.w800, color: color)),
      );
}
