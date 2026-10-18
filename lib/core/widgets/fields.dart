import 'package:flutter/material.dart';

import '../icons.dart';
import '../theme.dart';

/// Label above a text field, as in the design's `.cw-lab` inputs.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.fieldKey,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.prefix,
    this.onChanged,
    this.maxLines = 1,
    this.optional = false,
    this.textInputAction,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final Key? fieldKey;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? prefix;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final bool optional;
  final TextInputAction? textInputAction;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            style: CwText.label,
            children: [
              if (optional)
                const TextSpan(
                  text: '  (optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: CwColors.muted,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prefix != null) ...[
              Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: CwColors.white,
                  border: Border.all(color: CwColors.line, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  prefix!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: TextField(
                key: fieldKey,
                controller: controller,
                obscureText: obscure,
                keyboardType: keyboardType,
                onChanged: onChanged,
                maxLines: obscure ? 1 : maxLines,
                textInputAction: textInputAction,
                style: const TextStyle(fontSize: 15, color: CwColors.ink),
                decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Square tick box used for agreements and checklists.
class CwCheckRow extends StatelessWidget {
  const CwCheckRow({
    super.key,
    required this.checked,
    required this.onChanged,
    required this.child,
    this.boxKey,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final Widget child;
  final Key? boxKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      child: InkWell(
        key: boxKey,
        borderRadius: BorderRadius.circular(10),
        onTap: () => onChanged(!checked),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: checked ? CwColors.primary : CwColors.white,
                  border: Border.all(
                    color: checked ? CwColors.primary : const Color(0xFFC9C4D9),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: checked
                    ? const Center(
                        child: CwIcon(
                          CwIcons.check,
                          size: 14,
                          strokeWidth: 3,
                          color: CwColors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
