import 'package:flutter/material.dart';

import '../theme.dart';

class CwCard extends StatelessWidget {
  const CwCard({
    super.key,
    required this.child,
    this.color,
    this.selected = false,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
  });

  final Widget child;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final border = Border.all(
      color: selected ? CwColors.primary : (borderColor ?? CwColors.line),
      width: 2,
    );
    return Material(
      color: color ?? (selected ? CwColors.lilac : CwColors.white),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(borderRadius: radius, border: border),
          child: child,
        ),
      ),
    );
  }
}
