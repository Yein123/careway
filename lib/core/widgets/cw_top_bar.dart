import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          if (showBack) ...[
            SquareIconButton(
              icon: Icons.chevron_left,
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
                if (stepLabel != null) Text(stepLabel!, style: CwText.small),
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
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: CwColors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: color ?? CwColors.ink, semanticLabel: label),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      key: const ValueKey('icon-badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: CwColors.pink,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          fontSize: 10,
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
