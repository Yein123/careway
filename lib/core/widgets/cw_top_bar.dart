import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../icons.dart';
import '../theme.dart';

/// Screen header: back button, title and optional step label, as in the design.
class CwTopBar extends StatelessWidget {
  const CwTopBar({
    super.key,
    required this.title,
    this.stepLabel,
    this.showBack = true,
    this.action,
    this.onBack,
  });

  final String title;
  final String? stepLabel;
  final bool showBack;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          if (showBack) ...[
            SquareIconButton(
              svg: CwIcons.back,
              label: 'Back',
              onTap:
                  onBack ??
                  () => context.canPop() ? context.pop() : context.go('/'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: CwText.h2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (stepLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    stepLabel!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CwColors.muted),
                  ),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    this.icon,
    this.svg,
    required this.label,
    this.onTap,
    this.color,
    this.badge,
    this.size = 44,
    this.background = CwColors.white,
  });

  final IconData? icon;

  /// A [CwIcons] glyph, drawn instead of [icon].
  final String? svg;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final int? badge;
  final double size;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (svg != null)
                  CwIcon(
                    svg!,
                    size: svg == CwIcons.back ? 20 : 22,
                    strokeWidth: svg == CwIcons.back ? 2.4 : 2,
                    color: color ?? CwColors.ink,
                    semanticLabel: label,
                  )
                else
                  Icon(icon, color: color ?? CwColors.ink, semanticLabel: label),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      key: const ValueKey('icon-badge'),
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: CwColors.pink,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: CwColors.white, width: 2),
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: CwColors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
