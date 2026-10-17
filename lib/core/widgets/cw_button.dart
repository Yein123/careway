import 'package:flutter/material.dart';

import '../theme.dart';

enum CwButtonKind { primary, secondary, text }

class CwButton extends StatelessWidget {
  const CwButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = CwButtonKind.primary,
    this.color,
    this.trailing,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final CwButtonKind kind;
  final Color? color;
  final IconData? trailing;

  /// Shows a spinner and ignores taps (prevents double submit).
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? CwColors.primary;
    final Widget child = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: kind == CwButtonKind.primary ? CwColors.white : accent,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(label, textAlign: TextAlign.center)),
              if (trailing != null) ...[const SizedBox(width: 10), Icon(trailing, size: 22)],
            ],
          );
    const shape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16)));
    const textStyle = TextStyle(fontFamily: cwFont, fontSize: 17, fontWeight: FontWeight.w800);
    final action = loading ? null : onPressed;
    switch (kind) {
      case CwButtonKind.primary:
        return SizedBox(
          height: 56,
          width: double.infinity,
          child: FilledButton(
            onPressed: action,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: CwColors.white,
              disabledBackgroundColor: loading ? accent : CwColors.line,
              disabledForegroundColor: loading ? CwColors.white : CwColors.muted,
              shape: shape,
              textStyle: textStyle,
            ),
            child: child,
          ),
        );
      case CwButtonKind.secondary:
        return SizedBox(
          height: 52,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: action,
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: const BorderSide(color: CwColors.line, width: 2),
              backgroundColor: CwColors.white,
              shape: shape,
              textStyle: textStyle.copyWith(fontSize: 15),
            ),
            child: child,
          ),
        );
      case CwButtonKind.text:
        return SizedBox(
          height: 48,
          width: double.infinity,
          child: TextButton(
            onPressed: action,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              shape: shape,
              textStyle: textStyle.copyWith(fontSize: 15),
            ),
            child: child,
          ),
        );
    }
  }
}
