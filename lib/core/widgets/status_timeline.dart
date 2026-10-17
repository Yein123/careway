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

class StatusTimeline extends StatelessWidget {
  const StatusTimeline({
    super.key,
    required this.steps,
    this.accent = CwColors.primary,
  });

  final List<TimelineStep> steps;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _Row(step: steps[i], last: i == steps.length - 1, accent: accent),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.step, required this.last, required this.accent});

  final TimelineStep step;
  final bool last;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final done = step.state == TimelineState.done;
    final current = step.state == TimelineState.current;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? accent
                      : (current ? CwColors.white : CwColors.surface),
                  border: Border.all(
                    color: done || current ? accent : CwColors.line,
                    width: current ? 3 : 2,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check, size: 14, color: CwColors.white)
                    : null,
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    color: done ? accent : CwColors.line,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                      color: step.state == TimelineState.upcoming
                          ? CwColors.muted
                          : CwColors.ink,
                    ),
                  ),
                  if (step.at != null)
                    Text(
                      DateFormat('h:mm a').format(step.at!),
                      style: CwText.small,
                    )
                  else if (step.detail != null)
                    Text(step.detail!, style: CwText.small),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
