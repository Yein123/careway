import 'package:flutter/material.dart';

import '../theme.dart';
import 'cw_top_bar.dart';

/// Standard screen: top bar, scrolling content and an optional bottom action
/// area that stays above the keyboard.
class CwPage extends StatelessWidget {
  const CwPage({
    super.key,
    this.title,
    this.stepLabel,
    this.showBack = true,
    this.action,
    this.onBack,
    required this.children,
    this.bottom,
    this.background = CwColors.surface,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
  });

  final String? title;
  final String? stepLabel;
  final bool showBack;
  final Widget? action;
  final VoidCallback? onBack;
  final List<Widget> children;
  final Widget? bottom;
  final Color background;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            if (title != null)
              CwTopBar(
                title: title!,
                stepLabel: stepLabel,
                showBack: showBack,
                action: action,
                onBack: onBack,
              ),
            Expanded(
              // Tapping outside a field or scrolling closes the keyboard.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  padding: padding,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
            if (bottom != null)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                decoration: const BoxDecoration(
                  color: CwColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

/// Vertical spacing between form groups and cards.
class Gap extends StatelessWidget {
  const Gap([this.size = 16, Key? key]) : super(key: key);
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(height: size, width: size);
}

/// CareWay logo mark with wordmark.
class CwLogo extends StatelessWidget {
  const CwLogo({super.key, this.label, this.caregiver = false});
  final String? label;
  final bool caregiver;

  @override
  Widget build(BuildContext context) {
    final color = caregiver ? CwColors.teal : CwColors.primary;
    return _build(color);
  }

  Widget _build(Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          caregiver
              ? 'assets/images/careway-caregiver-icon-512.png'
              : 'assets/images/careway-icon-512-square.png',
          width: 40,
          height: 40,
        ),
      ),
      const SizedBox(width: 10),
      const Text(
        'CareWay',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      if (label != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
        ),
      ],
    ],
  );
}
