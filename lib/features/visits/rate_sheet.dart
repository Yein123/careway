import 'package:flutter/material.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/cw_sheet.dart';
import '../../data/models/booking.dart';

const ratingWords = ['Tap a star', 'Poor', 'Could be better', 'Okay', 'Good', 'Excellent'];
const visitRatingTags = ['On time', 'Patient and kind', 'Clear updates', 'Safe driving', 'Helped at pharmacy', 'Spoke his language'];
const visitLowRatingTags = ['Late pickup', 'Long wait for ride', 'Unclear updates', 'Rushed', 'Driving felt unsafe', 'Other'];

/// Rate sheet from the design: stars → tell us more → thanks.
class RateSheet extends StatefulWidget {
  const RateSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.initials,
    required this.onSubmit,
    this.tags = visitRatingTags,
    this.lowTags = visitLowRatingTags,
    this.privacyNote,
  });

  final String title;
  final String subtitle;
  final String initials;
  final List<String> tags;
  final List<String> lowTags;
  final String? privacyNote;
  final Future<void> Function(Rating) onSubmit;

  /// Shows the sheet; resolves to true once feedback was sent.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String initials,
    required Future<void> Function(Rating) onSubmit,
    List<String> tags = visitRatingTags,
    List<String> lowTags = visitLowRatingTags,
    String? privacyNote,
  }) async {
    var sent = false;
    await showCwSheet<void>(
      context,
      builder: (_) => RateSheet(
        title: title,
        subtitle: subtitle,
        initials: initials,
        tags: tags,
        lowTags: lowTags,
        privacyNote: privacyNote,
        onSubmit: (r) async {
          await onSubmit(r);
          sent = true;
        },
      ),
    );
    return sent;
  }

  @override
  State<RateSheet> createState() => _RateSheetState();
}

enum _Step { stars, feedback, done }

class _RateSheetState extends State<RateSheet> {
  int _stars = 0;
  _Step _step = _Step.stars;
  bool _busy = false;
  final Set<String> _tags = {};
  final _text = TextEditingController();

  bool get _low => _stars > 0 && _stars <= 3;
  List<String> get _tagList => _low ? widget.lowTags : widget.tags;
  String get _line => _stars > 0 ? 'You rated $_stars star${_stars > 1 ? 's' : ''} · ${ratingWords[_stars]}' : 'No stars yet';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await widget.onSubmit(Rating(stars: _stars, tags: [for (final t in _tagList) if (_tags.contains(t)) t], text: _text.text.trim()));
      if (mounted) setState(() => _step = _Step.done);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => switch (_step) {
        _Step.stars => _starsStep(),
        _Step.feedback => _feedbackStep(),
        _Step.done => _doneStep(),
      };

  Widget _starsStep() => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: CwColors.tealSoft, shape: BoxShape.circle),
          child: Text(widget.initials, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CwColors.teal)),
        ),
        const SizedBox(height: 12),
        Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(widget.subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: CwColors.muted)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= 5; i++)
            Padding(
              padding: EdgeInsets.only(left: i == 1 ? 0 : 4),
              child: Semantics(
                button: true,
                selected: i == _stars,
                label: '$i star${i > 1 ? 's' : ''}',
                excludeSemantics: true,
                child: InkResponse(
                  key: ValueKey('star-$i'),
                  onTap: () => setState(() => _stars = i),
                  radius: 26,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Center(
                      child: CwIcon(
                        CwIcons.star,
                        size: 40,
                        strokeWidth: 1.6,
                        fill: i <= _stars ? const Color(0xFFF2B53A) : CwColors.white,
                        color: i <= _stars ? const Color(0xFFE0A020) : const Color(0xFFC9C4D9),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 20,
          child: Text(ratingWords[_stars], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SheetButton(label: 'Next', onPressed: _stars == 0 ? null : () => setState(() => _step = _Step.feedback)),
        ),
      ]);

  Widget _feedbackStep() => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Semantics(
            button: true,
            label: 'Back to stars',
            excludeSemantics: true,
            child: Material(
              color: CwColors.lilac,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _step = _Step.stars),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(child: CwIcon(CwIcons.back, size: 18, strokeWidth: 2.4, color: CwColors.primaryDark)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tell us more', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(_line, style: const TextStyle(fontSize: 12, color: CwColors.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Text(_low ? 'What could be better?' : 'What went well?', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in _tagList) _TagChip(label: t, on: _tags.contains(t), onTap: () => setState(() => _tags.contains(t) ? _tags.remove(t) : _tags.add(t))),
        ]),
        const SizedBox(height: 14),
        const Text.rich(TextSpan(text: 'Your feedback ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800), children: [
          TextSpan(text: '(optional)', style: TextStyle(fontWeight: FontWeight.w600, color: CwColors.muted)),
        ])),
        const SizedBox(height: 6),
        TextField(
          controller: _text,
          minLines: 3,
          maxLines: 3,
          style: const TextStyle(fontSize: 14, color: CwColors.ink),
          decoration: const InputDecoration(
            hintText: 'Tell us about the helper, the ride or the clinic',
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        if (widget.privacyNote != null) ...[
          const SizedBox(height: 6),
          Text(widget.privacyNote!, style: const TextStyle(fontSize: 12, color: CwColors.muted)),
        ],
        const SizedBox(height: 14),
        SheetButton(label: 'Send feedback', onPressed: _busy ? null : _send),
      ]);

  Widget _doneStep() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: CwColors.successSoft, shape: BoxShape.circle),
            child: const Center(child: CwIcon(CwIcons.check, size: 34, strokeWidth: 2.8, color: Color(0xFF1D6B45))),
          ),
          const SizedBox(height: 10),
          const Text('Thanks for your feedback', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(_line, style: const TextStyle(fontSize: 13, color: CwColors.muted)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: SheetButton(label: 'Done', onPressed: () => Navigator.of(context).pop())),
        ]),
      );
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: on,
        child: Material(
          color: on ? CwColors.lilac : CwColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: on ? CwColors.primary : CwColors.line, width: 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                widthFactor: 1,
                child: Text(label,
                    style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? const Color(0xFF3A2591) : CwColors.ink)),
              ),
            ),
          ),
        ),
      );
}
