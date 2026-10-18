import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

enum TimelineState { done, current, upcoming }

class TimelineStep {
  const TimelineStep(this.label, this.at, this.state, {this.detail});

  final String label;
  final DateTime? at;
  final TimelineState state;
  final String? detail;
}

/// Vertical step list as drawn in the design: filled dot when done, thick
/// ring for the current step, thin ring for upcoming ones.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({
    super.key,
    required this.steps,
    this.accent = CwColors.primary,
    this.ring = CwColors.lilacLine,
  });

  final List<TimelineStep> steps;
  final Color accent;

  /// Ring colour for upcoming steps.
  final Color ring;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _Row(step: steps[i], last: i == steps.length - 1, accent: accent, ring: ring),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.step, required this.last, required this.accent, required this.ring});

  final TimelineStep step;
  final bool last;
  final Color accent;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final done = step.state == TimelineState.done;
    final current = step.state == TimelineState.current;
    final Widget dot = done
        ? Container(width: 18, height: 18, decoration: BoxDecoration(color: accent, shape: BoxShape.circle))
        : current
            ? Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(color: CwColors.white, shape: BoxShape.circle, border: Border.all(color: accent, width: 4)),
              )
            : Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: CwColors.white, shape: BoxShape.circle, border: Border.all(color: ring, width: 2)),
              );
    final sub = step.at != null ? DateFormat('h:mm a').format(step.at!.toLocal()) : step.detail;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                dot,
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      constraints: const BoxConstraints(minHeight: 30),
                      color: done ? accent : CwColors.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: step.state == TimelineState.upcoming ? FontWeight.w700 : FontWeight.w800,
                      color: step.state == TimelineState.upcoming ? const Color(0xFF8E8AA3) : CwColors.ink,
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(fontSize: 12, color: CwColors.muted)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
