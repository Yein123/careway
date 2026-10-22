import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../icons.dart';
import '../theme.dart';
import 'cw_top_bar.dart';
import 'safety_button.dart';

/// Pieces that repeat across the design's phone screens.

const lockIcon = '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>';
const kLine = Color(0xFFEFECF6);
const kInk2 = Color(0xFF3D3955);

/// Surface page: scrolling body (20/20/16 padding, fixed gap) and an optional
/// white bottom bar with a 24 px top radius.
class DesignScaffold extends StatelessWidget {
  const DesignScaffold({
    super.key,
    required this.children,
    this.bottom,
    this.gap = 16,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 16),
    this.background = CwColors.surface,
  });

  final List<Widget> children;
  final Widget? bottom;
  final double gap;
  final EdgeInsets padding;
  final Color background;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Column(children: [
            Expanded(
              // Not a lazy ListView: forms scrolled off screen keep what was typed.
              // Tapping outside a field or scrolling closes the keyboard.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  padding: padding,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) SizedBox(height: gap),
                      children[i],
                    ],
                  ]),
                ),
              ),
            ),
            if (bottom != null) BottomBar(child: bottom!),
          ]),
        ),
      );
}

class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        decoration: const BoxDecoration(
          color: CwColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: child,
      );
}

/// Back button, title, subtitle and an optional help shield.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.help = false,
    this.trailing,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool help;
  final Widget? trailing;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Row(children: [
        if (showBack) ...[
          SquareIconButton(
            svg: CwIcons.back,
            label: 'Back',
            onTap: onBack ?? () => context.canPop() ? context.pop() : context.go('/home'),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CwColors.muted)),
            ],
          ]),
        ),
        if (help) ...[
          const SizedBox(width: 12),
          SquareIconButton(svg: CwIcons.shield, label: 'Help and safety', color: CwColors.primary, onTap: () => showHelpSheet(context)),
        ],
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ]);
}

/// Segmented progress bar (6 px bars, 6 px gaps).
class StepBars extends StatelessWidget {
  const StepBars({super.key, required this.count, required this.filled, this.color = CwColors.primary, this.empty = const Color(0xFFE4DCFB)});
  final int count;
  final int filled;
  final Color color;
  final Color empty;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Row(children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(height: 6, decoration: BoxDecoration(color: i < filled ? color : empty, borderRadius: BorderRadius.circular(3))),
            ),
          ],
        ]),
      );
}

/// Coloured summary card (overline, badge, title, detail lines).
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.color, required this.overline, required this.title, required this.lines, this.badge});
  final Color color;
  final String overline;
  final String? badge;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text(overline, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Color(0xD9FFFFFF))),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0x2EFFFFFF), borderRadius: BorderRadius.circular(8)),
                child: Text(badge!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: CwColors.white)),
              ),
          ]),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CwColors.white)),
          const SizedBox(height: 10),
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
              child: Text(lines[i], style: const TextStyle(fontSize: 13, height: 1.4, color: CwColors.white)),
            ),
        ]),
      );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.size = 14});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800));
}

/// White price table with a bold total row.
class PriceTable extends StatelessWidget {
  const PriceTable({super.key, required this.lines, required this.totalLabel, required this.total, this.totalColor = CwColors.primaryDark});
  final List<(String, String)> lines;
  final String totalLabel;
  final String total;
  final Color totalColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          for (final (k, v) in lines)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(k, style: const TextStyle(fontSize: 13, color: CwColors.muted))),
                const SizedBox(width: 12),
                Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              Expanded(child: Text(totalLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              Text(total, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: totalColor)),
            ]),
          ),
        ]),
      );
}

/// Label/value rows on a white card (summary tables).
class InfoTable extends StatelessWidget {
  const InfoTable({super.key, required this.rows, this.radius = 20, this.fontSize = 14});
  final List<(String, Widget)> rows;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(radius)),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: kLine))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rows[i].$1, style: TextStyle(fontSize: fontSize, color: CwColors.muted)),
                const SizedBox(width: 12),
                Expanded(child: Align(alignment: Alignment.centerRight, child: rows[i].$2)),
              ]),
            ),
        ]),
      );
}

Widget infoValue(String v, {Color? color, FontWeight weight = FontWeight.w700, double size = 14}) =>
    Text(v, textAlign: TextAlign.right, style: TextStyle(fontSize: size, fontWeight: weight, color: color));

/// Full-width primary action.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = CwColors.primary,
    this.foreground = CwColors.white,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.height = 56,
    this.fontSize = 17,
    this.radius = 16,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color foreground;
  final String? icon;
  final String? trailingIcon;
  final bool loading;
  final double height;
  final double fontSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final fg = enabled || loading ? foreground : CwColors.muted;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foreground,
          disabledBackgroundColor: loading ? color : const Color(0xFFEFECF6),
          disabledForegroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: TextStyle(fontFamily: cwFont, fontSize: fontSize, fontWeight: FontWeight.w800),
        ),
        child: loading
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[CwIcon(icon!, size: 18, strokeWidth: 2.4, color: fg), const SizedBox(width: 10)],
                Flexible(child: Text(label, textAlign: TextAlign.center)),
                if (trailingIcon != null) ...[const SizedBox(width: 10), CwIcon(trailingIcon!, size: 22, strokeWidth: 2.2, color: fg)],
              ]),
      ),
    );
  }
}

/// Plain text action under a primary button.
class LinkButton extends StatelessWidget {
  const LinkButton({super.key, required this.label, required this.onPressed, this.color = CwColors.primaryDark, this.height = 48, this.fontSize = 15});
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: TextStyle(fontFamily: cwFont, fontSize: fontSize, fontWeight: FontWeight.w800),
          ),
          child: Text(label),
        ),
      );
}

/// Small icon + muted note (e.g. the lock line under payment).
class NoteRow extends StatelessWidget {
  const NoteRow({super.key, required this.text, this.icon = lockIcon});
  final String text;
  final String icon;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: CwIcon(icon, size: 16, strokeWidth: 2.2, color: CwColors.muted)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.45, color: CwColors.muted))),
      ]);
}

/// Pill badge.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, required this.background, required this.color, this.fontSize = 11, this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4)});
  final String text;
  final Color background;
  final Color color;
  final double fontSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: color)),
      );
}

/// The design's 50×30 toggle switch.
class CwSwitch extends StatelessWidget {
  const CwSwitch({super.key, required this.value, required this.onChanged, required this.label, this.color = CwColors.primary});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: value,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 50,
            height: 30,
            padding: const EdgeInsets.all(3),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(color: value ? color : const Color(0xFFD6D3E0), borderRadius: BorderRadius.circular(15)),
            child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: CwColors.white, shape: BoxShape.circle)),
          ),
        ),
      );
}

/// 22 px radio ring with a 10 px dot.
class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.on, this.color = CwColors.primary});
  final bool on;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? color : const Color(0xFFC9C4D9), width: 2)),
        child: Center(
          child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: on ? color : Colors.transparent)),
        ),
      );
}

/// Selectable card with a 2 px border (lilac when on).
class SelectCard extends StatelessWidget {
  const SelectCard({
    super.key,
    required this.on,
    required this.child,
    this.onTap,
    this.radius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.accent = CwColors.primary,
    this.onColor = CwColors.lilac,
    this.offColor = CwColors.white,
  });

  final bool on;
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsets padding;
  final Color accent;
  final Color onColor;
  final Color offColor;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: on,
        button: onTap != null,
        child: Material(
          color: on ? onColor : offColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: on ? accent : CwColors.line, width: 2)),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}
