import 'package:flutter/material.dart';

import '../theme.dart';

/// Selectable pill used for options like mobility, time slots and languages.
class CwChip extends StatelessWidget {
  const CwChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: selected ? CwColors.lilac : CwColors.white,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? CwColors.primary : CwColors.line,
                width: 2,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: !enabled
                    ? CwColors.muted.withValues(alpha: 0.5)
                    : (selected ? CwColors.primaryDark : CwColors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small coloured status pill (e.g. LEVEL 1, LIVE NOW).
class CwBadge extends StatelessWidget {
  const CwBadge(
    this.text, {
    super.key,
    this.color = CwColors.primaryDark,
    this.background = CwColors.lilac,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: color,
      ),
    ),
  );
}
