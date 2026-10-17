import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/fields.dart';
import '../../data/models/booking.dart';

const ratingWords = ['', 'Poor', 'Not great', 'Okay', 'Good', 'Excellent'];
const visitRatingTags = ['On time', 'Patient and kind', 'Clear updates', 'Safe driving', 'Helped at pharmacy', 'Clear instructions'];

/// Stars, tags and optional feedback; returns the Rating when sent.
class RateSheet extends StatefulWidget {
  const RateSheet({super.key, required this.title, required this.subtitle, required this.tags, this.privacyNote});

  final String title;
  final String subtitle;
  final List<String> tags;
  final String? privacyNote;

  /// Shows the sheet; resolves to the rating, or null if dismissed.
  static Future<Rating?> show(BuildContext context, {required String title, required String subtitle, List<String> tags = visitRatingTags, String? privacyNote}) =>
      showModalBottomSheet<Rating>(
        context: context,
        isScrollControlled: true,
        builder: (_) => RateSheet(title: title, subtitle: subtitle, tags: tags, privacyNote: privacyNote),
      );

  @override
  State<RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<RateSheet> {
  int _stars = 0;
  final Set<String> _tags = {};
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.title, style: CwText.h2),
          Text(widget.subtitle, style: CwText.muted),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                key: ValueKey('star-$i'),
                tooltip: '$i star${i == 1 ? '' : 's'}',
                iconSize: 40,
                onPressed: () => setState(() => _stars = i),
                icon: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i <= _stars ? CwColors.star : CwColors.line),
              ),
          ]),
          Text(ratingWords[_stars], textAlign: TextAlign.center, style: CwText.h3),
          if (_stars > 0) ...[
            const SizedBox(height: 14),
            Text(_stars <= 3 ? 'What could be better?' : 'What went well?', style: CwText.label),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in widget.tags)
                CwChip(label: t, selected: _tags.contains(t), onTap: () => setState(() => _tags.contains(t) ? _tags.remove(t) : _tags.add(t))),
            ]),
            const SizedBox(height: 14),
            LabeledField(label: 'Your feedback', controller: _text, maxLines: 3, optional: true),
            if (widget.privacyNote != null) ...[const SizedBox(height: 6), Text(widget.privacyNote!, style: CwText.small)],
          ],
          const SizedBox(height: 16),
          CwButton(
            label: 'Send feedback',
            onPressed: _stars == 0
                ? null
                : () => Navigator.pop(context, Rating(stars: _stars, tags: [for (final t in widget.tags) if (_tags.contains(t)) t], text: _text.text.trim())),
          ),
        ]),
      ),
    );
  }
}
