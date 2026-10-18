import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Stroke icons copied from the design canvas (24×24 viewBox, inner markup only).
class CwIcons {
  static const back = '<path d="m15 6-6 6 6 6"/>';
  static const chevronRight = '<path d="m9 6 6 6-6 6"/>';
  static const arrowRight = '<path d="M5 12h14"/><path d="m13 6 6 6-6 6"/>';
  static const bell =
      '<path d="M6 9a6 6 0 0 1 12 0c0 6 2.5 7.5 2.5 7.5h-17S6 15 6 9z"/><path d="M10 20a2.2 2.2 0 0 0 4 0"/>';
  static const pin =
      '<path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>';
  static const pinAlt =
      '<path d="M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11z"/><circle cx="12" cy="10" r="2.5"/>';
  static const home = '<path d="M4 11 12 4l8 7v9H4z"/>';
  static const calendar =
      '<rect x="4" y="5" width="16" height="15" rx="3"/><path d="M4 10h16M9 3v4M15 3v4"/>';
  static const family =
      '<circle cx="9" cy="8" r="3"/><path d="M3 20a6 6 0 0 1 12 0"/><circle cx="17" cy="9" r="2.5"/><path d="M16 14.5a5 5 0 0 1 5 5"/>';
  static const person =
      '<circle cx="12" cy="8" r="3.5"/><path d="M5 20a7 7 0 0 1 14 0"/>';
  static const clock =
      '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>';
  static const check = '<path d="m5 12 5 5 9-10"/>';
  static const phone =
      '<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a1 1 0 0 1-1 1A16 16 0 0 1 4 5a1 1 0 0 1 1-1z"/>';
  static const shield =
      '<path d="M12 3 5 6v5c0 4.5 3 8 7 10 4-2 7-5.5 7-10V6z"/><path d="M12 9v4M12 16h.01"/>';
  static const group =
      '<circle cx="8" cy="6" r="2.5"/><circle cx="16" cy="6" r="2.5"/><path d="M4 20v-4a4 4 0 0 1 8 0v4"/><path d="M12 20v-4a4 4 0 0 1 8 0v4"/>';
  static const escort =
      '<circle cx="9" cy="6" r="2.5"/><path d="M5 20v-5a4 4 0 0 1 8 0v5"/><path d="M15 11l2 2 4-4"/>';
  static const medicine =
      '<rect x="7" y="3" width="10" height="4" rx="1"/><path d="M6 7h12v12a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2z"/><path d="M12 11v6M9 14h6"/>';
  static const profile =
      '<rect x="4" y="3" width="16" height="18" rx="3"/><path d="M8 8h8M8 12h8M8 16h5"/>';
  static const receipt =
      '<path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6M9 12h6"/>';
  static const hospital =
      '<rect x="4" y="4" width="16" height="16" rx="4"/><path d="M12 8v8M8 12h8"/>';
  static const plus = '<path d="M12 5v14M5 12h14"/>';
  static const close = '<path d="M6 6l12 12M18 6 6 18"/>';
  static const star =
      '<path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.3-4.1 5.9-.9z"/>';
}

/// Renders a [CwIcons] glyph with the design's stroke style.
class CwIcon extends StatelessWidget {
  const CwIcon(
    this.body, {
    super.key,
    this.size = 24,
    this.color = const Color(0xFF1E1B2E),
    this.strokeWidth = 2,
    this.fill,
    this.semanticLabel,
  });

  final String body;
  final double size;
  final Color color;
  final double strokeWidth;
  final Color? fill;
  final String? semanticLabel;

  static String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    final f = fill == null ? 'none' : hex(fill!);
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="$f" '
        'stroke="${hex(color)}" stroke-opacity="${color.a}" stroke-width="$strokeWidth" '
        'stroke-linecap="round" stroke-linejoin="round">$body</svg>';
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
