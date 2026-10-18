import 'package:flutter/material.dart';

import '../theme.dart';

/// Bottom sheet as drawn in the design: white, 28 px top radius, grabber.
Future<T?> showCwSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool grabber = true,
  EdgeInsets padding = const EdgeInsets.fromLTRB(20, 12, 20, 28),
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  backgroundColor: CwColors.white,
  barrierColor: const Color(0x731E1B2E),
  clipBehavior: Clip.antiAlias,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (ctx) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
    child: SingleChildScrollView(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (grabber) ...[const SheetGrabber(), const SizedBox(height: 12)],
          builder(ctx),
        ],
      ),
    ),
  ),
);

class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 44,
      height: 5,
      decoration: BoxDecoration(
        color: CwColors.line,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

/// 40 px lilac square with an ×, used to close sheets.
class SheetCloseButton extends StatelessWidget {
  const SheetCloseButton({super.key, required this.label, this.onTap, this.onPhoto = false});

  final String label;
  final VoidCallback? onTap;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: onPhoto ? const Color(0xEBFFFFFF) : CwColors.lilac,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () => Navigator.of(context).pop(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Text(
              '×',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: onPhoto ? CwColors.ink : CwColors.primaryDark,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Full-width rounded action used inside sheets (16 px padding, 16 radius).
class SheetButton extends StatelessWidget {
  const SheetButton({super.key, required this.label, this.onPressed, this.color = CwColors.primary});

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: enabled ? color : const Color(0xFFEFECF6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: enabled ? CwColors.white : const Color(0xFF9A96AE),
            ),
          ),
        ),
      ),
    );
  }
}
