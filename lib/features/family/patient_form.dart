import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/step_label.dart';
import '../../data/models/family.dart';
import '../../domain/needs.dart';

const relationships = ['Parent', 'Spouse', 'Child', 'Grandparent', 'Relative', 'Myself', 'Others'];
const extraHelpOptions = [
  'Hearing',
  'Vision',
  'Memory or confusion',
  'Translate for doctor',
  'Toilet help',
  'Collect medicine',
  'Fill in forms',
];

/// Patient details form (Book step 1 "Patient details", Profile edit mode).
/// [full] adds medical history, how to talk, and privacy.
class PatientForm extends StatefulWidget {
  const PatientForm({
    super.key,
    this.initial,
    this.full = false,
    this.saveLabel = 'Save',
    required this.onSave,
    this.onCancel,
  });

  final Patient? initial;
  final bool full;
  final String saveLabel;
  final Future<void> Function(Patient) onSave;
  final VoidCallback? onCancel;

  @override
  State<PatientForm> createState() => _PatientFormState();
}

class _PatientFormState extends State<PatientForm> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _age = TextEditingController(text: widget.initial == null ? '' : '${widget.initial!.age}');
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _conditions = TextEditingController(text: widget.initial?.conditions);
  late final _surgery = TextEditingController(text: widget.initial?.surgery);
  late final _allergy = TextEditingController(text: widget.initial?.allergy);
  late final _medicines = TextEditingController(text: widget.initial?.medicines);
  late final _clinics = TextEditingController(text: widget.initial?.clinics);
  late final _talk = TextEditingController(text: widget.initial?.talkNotes);
  late String _relationship = widget.initial?.relationship ?? 'Parent';
  late Mobility _mobility = widget.initial?.mobility ?? Mobility.independent;
  late final Set<String> _extra = {...?widget.initial?.extraHelp};
  late bool _helperOnly = widget.initial?.helperOnly ?? true;
  late bool _sendUpdates = widget.initial?.sendUpdates ?? true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _age, _phone, _conditions, _surgery, _allergy, _medicines, _clinics, _talk]) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _ageValue {
    final a = int.tryParse(_age.text.trim());
    return a != null && a >= 0 && a <= 120 ? a : null;
  }

  bool get _valid => _name.text.trim().isNotEmpty && _ageValue != null;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final base = widget.initial ?? Patient(id: '', name: '', age: 0);
    final p = base.copyWith(
      name: _name.text.trim(),
      age: _ageValue,
      relationship: _relationship,
      phone: _phone.text.trim(),
      mobility: _mobility,
      extraHelp: _extra.toList(),
      conditions: _conditions.text.trim(),
      surgery: _surgery.text.trim(),
      allergy: _allergy.text.trim(),
      medicines: _medicines.text.trim(),
      clinics: _clinics.text.trim(),
      talkNotes: _talk.text.trim(),
      helperOnly: _helperOnly,
      sendUpdates: _sendUpdates,
    );
    try {
      await widget.onSave(p);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't save. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    void changed(String _) => setState(() {});
    Widget gap([double h = 14]) => SizedBox(height: h);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(label: 'Full name (as in MyKad)', controller: _name, fieldKey: const ValueKey('pf-name'), onChanged: changed),
        gap(),
        LabeledField(
          label: 'Age',
          controller: _age,
          fieldKey: const ValueKey('pf-age'),
          keyboardType: TextInputType.number,
          onChanged: changed,
        ),
        gap(),
        const Text('Relationship to you', style: CwText.label),
        gap(6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in relationships)
            CwChip(label: r, selected: r == _relationship, onTap: () => setState(() => _relationship = r)),
        ]),
        gap(),
        LabeledField(
          label: "Patient's phone number",
          controller: _phone,
          fieldKey: const ValueKey('pf-phone'),
          keyboardType: TextInputType.phone,
          optional: true,
        ),
        gap(),
        const Text('Mobility', style: CwText.label),
        gap(6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in Mobility.values)
            CwChip(label: m.label, selected: m == _mobility, onTap: () => setState(() => _mobility = m)),
        ]),
        gap(),
        const Text.rich(TextSpan(text: 'Extra help needed', style: CwText.label, children: [
          TextSpan(text: '  (optional)', style: TextStyle(fontWeight: FontWeight.w500, color: CwColors.muted)),
        ])),
        gap(6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in extraHelpOptions)
            CwChip(
              label: e,
              selected: _extra.contains(e),
              onTap: () => setState(() => _extra.contains(e) ? _extra.remove(e) : _extra.add(e)),
            ),
        ]),
        if (widget.full) ...[
          gap(22),
          const SectionTitle('Medical history'),
          LabeledField(label: 'Conditions', controller: _conditions, maxLines: 2, optional: true),
          gap(),
          LabeledField(label: 'Past surgery', controller: _surgery, optional: true),
          gap(),
          LabeledField(label: 'Allergy', controller: _allergy, optional: true),
          gap(),
          LabeledField(label: 'Medicines', controller: _medicines, optional: true),
          gap(),
          LabeledField(label: 'Regular clinics', controller: _clinics, optional: true),
          gap(),
          const Text('Entered by the family. The helper does not give medical advice.', style: CwText.small),
          gap(22),
          const SectionTitle('How to talk with them'),
          LabeledField(
            label: 'Language, hearing, what helps',
            controller: _talk,
            maxLines: 3,
            optional: true,
            hint: 'e.g. Speaks Malay. Face her and speak slowly.',
          ),
          gap(22),
          const SectionTitle('Privacy and updates'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _helperOnly,
            onChanged: (v) => setState(() => _helperOnly = v),
            title: const Text('Show profile to the assigned helper only', style: CwText.bodyBold),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _sendUpdates,
            onChanged: (v) => setState(() => _sendUpdates = v),
            title: const Text('Send visit updates to me', style: CwText.bodyBold),
          ),
        ],
        if (_error != null) ...[
          gap(10),
          Text(_error!, style: const TextStyle(color: CwColors.pink, fontWeight: FontWeight.w700)),
        ],
        gap(20),
        CwButton(label: widget.saveLabel, loading: _busy, onPressed: _valid ? _save : null),
        if (widget.onCancel != null) ...[
          gap(8),
          CwButton(label: 'Cancel', kind: CwButtonKind.text, onPressed: widget.onCancel),
        ],
      ],
    );
  }
}
