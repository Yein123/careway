import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/step_label.dart';
import '../../data/models/family.dart';
import '../../data/providers.dart';
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
    return CwPage(
      title: _editing ? 'Edit profile' : 'Patient profile',
      children: [
        AsyncView<Patient?>(
          value: patient,
          onRetry: () => ref.invalidate(patientProvider(widget.patientId)),
          isEmpty: (p) => p == null,
          empty: const EmptyState(icon: Icons.person_off_outlined, title: 'Profile not found'),
          data: (p) => _editing ? _edit(p!, family, user?.name) : _view(p!, family, now),
        ),
      ],
    );
  }

  Widget _edit(Patient p, Family? family, String? editor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CwCard(
        color: CwColors.lilac,
        borderColor: CwColors.lilacLine,
        child: Text(
          'Only ${p.name.split(' ').first} and members of the ${family?.name ?? 'family'} group can edit this profile. '
          'Helpers can view it during a visit but cannot change it.',
          style: CwText.small,
        ),
      ),
      const Gap(8),
      Text('Editing as ${editor ?? 'guardian'}', style: CwText.small),
      const Gap(16),
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

  Widget _view(Patient p, Family? family, DateTime now) {
    Widget row(String k, String v) => v.trim().isEmpty ? const SizedBox.shrink() : KeyValueRow(k, v);
    final keeper = family?.memberNames[p.updatedBy];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Avatar(p.initials, size: 64, background: CwColors.pinkSoft, color: CwColors.pink),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p.name}, ${p.age}', style: CwText.h2),
            if (p.updatedAt != null)
              Text(
                '${keeper == null ? 'Updated' : 'Kept by $keeper ·'} updated ${agoLabel(p.updatedAt!, now)}',
                style: CwText.small,
              ),
          ]),
        ),
      ]),
      const Gap(20),
      const SectionTitle('Contact numbers'),
      CwCard(
        child: Column(children: [
          if (p.phone.isNotEmpty) KeyValueRow('Patient · ${p.name.split(' ').first}', p.phone),
          for (final c in p.contacts) KeyValueRow('${c.role} · ${c.name}', c.phone),
          if (p.phone.isEmpty && p.contacts.isEmpty) const Text('No numbers saved yet.', style: CwText.muted),
        ]),
      ),
      const Gap(16),
      const SectionTitle('Care needs'),
      CwCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          KeyValueRow('Mobility', p.mobility.label),
          const Gap(6),
          const Text('Extra help', style: CwText.muted),
          const Gap(6),
          p.extraHelp.isEmpty
              ? const Text('None', style: CwText.bodyBold)
              : Wrap(spacing: 6, runSpacing: 6, children: [for (final e in p.extraHelp) CwBadge(e)]),
        ]),
      ),
      const Gap(16),
      const SectionTitle('Medical history'),
      CwCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          row('Conditions', p.conditions),
          row('Past surgery', p.surgery),
          row('Allergy', p.allergy),
          row('Medicines', p.medicines),
          row('Regular clinics', p.clinics),
          const Gap(6),
          const Text('Entered by the family. The helper does not give medical advice.', style: CwText.small),
        ]),
      ),
      if (p.talkNotes.isNotEmpty) ...[
        const Gap(16),
        SectionTitle('How to talk with ${p.name.split(' ').first}'),
        CwCard(child: Text(p.talkNotes, style: CwText.body)),
      ],
      const Gap(16),
      const SectionTitle('Privacy and updates'),
      CwCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KeyValueRow('Show profile to the assigned helper only', p.helperOnly ? 'On' : 'Off'),
          KeyValueRow('Send visit updates', p.sendUpdates ? 'On' : 'Off'),
          const Gap(6),
          const Row(children: [
            Expanded(child: Text('Link MySejahtera visit summary', style: CwText.muted)),
            CwBadge('COMING SOON', color: CwColors.muted, background: CwColors.surface),
          ]),
        ]),
      ),
      const Gap(20),
      CwButton(label: 'Edit profile', onPressed: () => setState(() => _editing = true)),
    ]);
  }
}
