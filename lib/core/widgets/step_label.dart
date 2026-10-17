import 'package:flutter/material.dart';

import '../theme.dart';

class StepLabel extends StatelessWidget {
  const StepLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: CwText.overline.copyWith(color: color));
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(text, style: CwText.h3)),
        ?trailing,
      ],
    ),
  );
}

/// Label/value row used in summaries and price breakdowns.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {super.key, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: bold ? CwText.bodyBold : CwText.muted),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(value, textAlign: TextAlign.right, style: bold ? CwText.h3 : CwText.bodyBold),
        ),
      ],
    ),
  );
}
