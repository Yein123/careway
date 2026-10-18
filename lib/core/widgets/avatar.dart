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

/// Per-person colour pairs used for family avatars in the design
/// (pink, teal, amber), picked by position in the family list.
const _tones = [
  (Color(0xFFFCE4EB), Color(0xFFC2365E)),
  (Color(0xFFDDF2F7), Color(0xFF127A94)),
  (Color(0xFFFDEBD9), Color(0xFFB35A12)),
  (Color(0xFFE4DCFB), Color(0xFF4B32B8)),
];

(Color, Color) personTone(int index) => _tones[index % _tones.length];

/// Round initials badge (the design's circular avatars).
class CircleAvatarText extends StatelessWidget {
  const CircleAvatarText(this.initials, {super.key, required this.size, required this.tone, this.fontSize});

  final String initials;
  final double size;
  final (Color, Color) tone;
  final double? fontSize;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tone.$1, shape: BoxShape.circle),
        child: Text(initials, style: TextStyle(fontSize: fontSize ?? size * 0.36, fontWeight: FontWeight.w800, color: tone.$2)),
      );
}
