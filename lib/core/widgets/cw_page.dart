import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../art.dart';
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
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
              child: SingleChildScrollView(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            if (bottom != null)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  color: CwColors.white,
                  border: Border(top: BorderSide(color: CwColors.line)),
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
  const CwLogo({super.key, this.color = CwColors.primary, this.label});
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SvgPicture.string(logoSvg, width: 24, height: 24),
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
