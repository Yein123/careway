import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/design_kit.dart';
import '../../data/models/family.dart';
import '../../data/providers.dart';
import '../visits/live_visit_screen.dart' show callNumber;
import 'patient_form.dart';

/// Saves a patient for the signed-in user's family, stamping who and when.
Future<String> savePatientForFamily(WidgetRef ref, Patient p) {
  final fid = ref.read(familyIdProvider)!;
  final uid = ref.read(authStateProvider).value ?? '';
  final stamped = p.copyWith(updatedAt: ref.read(clockProvider)().toUtc(), updatedBy: uid);
  return ref.read(familyRepoProvider).savePatient(fid, stamped);
}

/// New patient form (pid == 'new').
class NewPatientScreen extends ConsumerWidget {
  const NewPatientScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => CwPage(
        title: 'Add someone you care for',
        children: [
          const Text('Save them once and pick them in one tap when you book.', style: CwText.muted),
          const Gap(16),
          PatientForm(
            full: true,
            onSave: (p) async {
              await savePatientForFamily(ref, p);
              if (context.mounted) context.canPop() ? context.pop() : context.go('/family');
            },
          ),
        ],
      );
}

/// 11 · Patient profile (Profile.dc.html): view and edit.
class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({super.key, required this.patientId});
  final String patientId;

  @override
  ConsumerState<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final patient = ref.watch(patientProvider(widget.patientId));
    final family = ref.watch(familyProvider).value;
    final user = ref.watch(currentUserProvider).value;
    final now = ref.watch(clockProvider)();
    return DesignScaffold(
      gap: 18,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        PageHeader(title: _editing ? 'Edit profile' : 'Patient profile', help: true),
        AsyncView<Patient?>(
          value: patient,
          onRetry: () => ref.invalidate(patientProvider(widget.patientId)),
          isEmpty: (p) => p == null,
          empty: const EmptyState(icon: Icons.person_off_outlined, title: 'Profile not found'),
          data: (p) => _editing ? _edit(p!, family, user?.name) : _view(p!, family, user?.name, now),
        ),
      ],
    );
  }

  Widget _header(Patient p, Family? family, DateTime now) {
    final keeper = family?.memberNames[p.updatedBy];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        CircleAvatarText(p.initials, size: 52, tone: personTone(0), fontSize: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p.name}, ${p.age}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            if (p.updatedAt != null) ...[
              const SizedBox(height: 2),
              Text(
                '${keeper == null ? 'Updated' : 'Kept by $keeper ·'} updated ${agoLabel(p.updatedAt!, now)}',
                style: const TextStyle(fontSize: 12, color: CwColors.muted),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _edit(Patient p, Family? family, String? editor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(p, family, ref.read(clockProvider)()),
      const SizedBox(height: 18),
      Text('Editing as ${editor ?? 'guardian'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: CwColors.muted)),
      const SizedBox(height: 14),
      PatientForm(
        initial: p,
        full: true,
        saveLabel: 'Save profile',
        onCancel: () => setState(() => _editing = false),
        onSave: (updated) async {
          await savePatientForFamily(ref, updated);
          if (mounted) setState(() => _editing = false);
        },
      ),
    ]);
  }

  Widget _view(Patient p, Family? family, String? me, DateTime now) {
    final first = p.name.split(' ').first;
    Widget group(String title, Widget child, {String? note}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionLabel(title),
          const SizedBox(height: 8),
          child,
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(note, style: const TextStyle(fontSize: 11, height: 1.4, color: CwColors.muted)),
          ],
        ]);
    Widget card(List<Widget> rows) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            for (var i = 0; i < rows.length; i++)
              Container(
                decoration: BoxDecoration(border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: kLine))),
                child: rows[i],
              ),
          ]),
        );
    Widget kv(String k, String v, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: const TextStyle(fontSize: 13, color: CwColors.muted)),
            const SizedBox(width: 12),
            Expanded(child: Text(v, textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color))),
          ]),
        );
    Widget contact(String label, String phone) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 12, color: CwColors.muted)),
                const SizedBox(height: 2),
                Text(phone, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
            ),
            Semantics(
              button: true,
              label: 'Call ${label.split(' · ').last}',
              excludeSemantics: true,
              child: Material(
                color: CwColors.lilac,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => callNumber(context, phone),
                  child: const SizedBox(width: 44, height: 44, child: Center(child: CwIcon(CwIcons.phone, size: 18, strokeWidth: 2.2, color: CwColors.primaryDark))),
                ),
              ),
            ),
          ]),
        );
    Widget toggle(String label, bool value, Patient Function(bool) apply) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            const SizedBox(width: 10),
            CwSwitch(value: value, label: label, onChanged: (v) => savePatientForFamily(ref, apply(v))),
          ]),
        );

    final medical = [
      if (p.conditions.trim().isNotEmpty) kv('Conditions', p.conditions),
      if (p.surgery.trim().isNotEmpty) kv('Past surgery', p.surgery),
      if (p.allergy.trim().isNotEmpty) kv('Allergy', p.allergy, color: CwColors.pink),
      if (p.medicines.trim().isNotEmpty) kv('Medicines', p.medicines),
      if (p.clinics.trim().isNotEmpty) kv('Regular clinics', p.clinics),
    ];
    final contacts = [
      if (p.phone.isNotEmpty) contact('Patient · $first', p.phone),
      for (final c in p.contacts) contact('${c.role} · ${c.name}', c.phone),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(p, family, now),
      const SizedBox(height: 18),
      group(
        'Contact numbers',
        contacts.isEmpty
            ? card([const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No numbers saved yet.', style: TextStyle(fontSize: 13, color: CwColors.muted)))])
            : card(contacts),
      ),
      const SizedBox(height: 18),
      group('Care needs', card([kv('Mobility', p.mobility.label), kv('Extra help', p.extraHelp.isEmpty ? 'None' : p.extraHelp.join(', '))])),
      const SizedBox(height: 18),
      group(
        'Medical history',
        medical.isEmpty
            ? card([const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Nothing added yet.', style: TextStyle(fontSize: 13, color: CwColors.muted)))])
            : card(medical),
        note: 'Entered by the family. The helper does not give medical advice.',
      ),
      if (p.talkNotes.isNotEmpty) ...[
        const SizedBox(height: 18),
        group(
          'How to talk with $first',
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(14)),
            child: Text(p.talkNotes, style: const TextStyle(fontSize: 13, height: 1.5)),
          ),
        ),
      ],
      const SizedBox(height: 18),
      group(
        'Privacy and updates',
        card([
          toggle('Show profile to the assigned helper only', p.helperOnly, (v) => p.copyWith(helperOnly: v)),
          toggle('Send visit updates${me == null ? '' : ' to ${me.split(' ').first}'}', p.sendUpdates, (v) => p.copyWith(sendUpdates: v)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Link MySejahtera visit summary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CwColors.muted)),
                  SizedBox(height: 2),
                  Text('Available once MOH allows consent-based sharing', style: TextStyle(fontSize: 11, color: CwColors.muted)),
                ]),
              ),
              Tag('Coming soon', background: CwColors.lilac, color: CwColors.primaryDark, padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 26),
      SizedBox(
        height: 64,
        child: FilledButton(
          onPressed: () => setState(() => _editing = true),
          style: FilledButton.styleFrom(
            backgroundColor: CwColors.white,
            foregroundColor: CwColors.primary,
            side: const BorderSide(color: CwColors.primary, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            textStyle: const TextStyle(fontFamily: cwFont, fontSize: 17, fontWeight: FontWeight.w800),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            CwIcon('<path d="M4 20h4L19 9l-4-4L4 16z"/>', size: 18, strokeWidth: 2.4, color: CwColors.primary),
            SizedBox(width: 8),
            Text('Edit profile'),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      NoteRow(
        text: 'Only $first and members of the ${family?.name ?? 'family'} group can edit this profile. Helpers can view it during a visit but cannot change it.',
      ),
    ]);
  }
}
