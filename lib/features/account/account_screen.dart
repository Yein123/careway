import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/step_label.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../visits/live_visit_screen.dart' show callNumber;

const faqs = [
  ('What if the appointment runs late?',
      'The helper waits with the group, and the ride home is called when the patient is ready at the pharmacy. Waiting is never charged.'),
  ('What if no group is found?',
      'Nothing is charged. You can start a new group (you still ride, capped at RM 40), switch to a one-to-one escort, or join the waitlist.'),
  ('Who can see the patient’s profile?',
      'Only the helper assigned to that visit, and only while the visit is active. Co-riders see just the shared destination.'),
  ('When do I pay for a shared ride?',
      'Only after the helper accepts. If more neighbours join before the group locks 24 hours before pickup, the difference comes back to you automatically.'),
];

/// 13 · Account · help and safety (Account.dc.html)
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.section});

  /// 'safety' scrolls to Help and safety (from the shield button).
  final String? section;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _safetyKey = GlobalKey();
  int? _openFaq;

  @override
  void initState() {
    super.initState();
    if (widget.section == 'safety') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _safetyKey.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
      });
    }
  }

  Future<void> _edit(AppUser u) async {
    final name = TextEditingController(text: u.name);
    final phone = TextEditingController(text: u.phone);
    final area = TextEditingController(text: u.area);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Edit your details', style: CwText.h2),
          const SizedBox(height: 14),
          LabeledField(label: 'Full name', controller: name),
          const SizedBox(height: 12),
          LabeledField(label: 'Phone number', controller: phone, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          LabeledField(label: 'Home area', controller: area),
          const SizedBox(height: 16),
          CwButton(label: 'Save', onPressed: () => Navigator.pop(ctx, true)),
          CwButton(label: 'Cancel', kind: CwButtonKind.text, onPressed: () => Navigator.pop(ctx, false)),
        ]),
      ),
    );
    if (saved == true && name.text.trim().isNotEmpty) {
      await ref.read(userRepoProvider).update(u.uid, {'name': name.text.trim(), 'phone': phone.text.trim(), 'area': area.text.trim()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(currentUserProvider).value;
    final family = ref.watch(familyProvider).value;
    Widget link(IconData icon, String title, String sub, String path) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CwCard(
            onTap: () => context.push(path),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(icon, color: CwColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: CwText.bodyBold),
                  Text(sub, style: CwText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const Icon(Icons.chevron_right, color: CwColors.muted),
            ]),
          ),
        );

    return CwPage(
      title: 'Account',
      showBack: false,
      children: [
        if (u != null)
          CwCard(
            child: Row(children: [
              Avatar(u.initials, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name, style: CwText.h3),
                  Text([u.phone, u.area].where((s) => s.isNotEmpty).join(' · '), style: CwText.small),
                  Text(u.email, style: CwText.small),
                  if (family != null && family.adminUid == u.uid) Text('Admin · ${family.name}', style: CwText.small),
                ]),
              ),
              TextButton(onPressed: () => _edit(u), child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w800))),
            ]),
          ),
        const Gap(22),
        StepLabel('Help and safety', key: _safetyKey, color: CwColors.pink),
        const Gap(8),
        CwCard(
          color: CwColors.pinkSoft,
          borderColor: CwColors.pinkSoft,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Emergency at home?', style: CwText.h3),
            const SizedBox(height: 4),
            const Text('Hospital Sungai Buloh · Nearest ER · 24 hours · ~10 km', style: CwText.small),
            const SizedBox(height: 10),
            CwButton(label: 'Call 999', color: CwColors.pink, onPressed: () => callNumber(context, '999')),
            CwButton(
              label: 'Call CareWay coordinator',
              kind: CwButtonKind.text,
              color: CwColors.pink,
              onPressed: () => callNumber(context, '+60 3-0000 0000'),
            ),
            const Text('[Support hours]', textAlign: TextAlign.center, style: CwText.small),
          ]),
        ),
        const Gap(12),
        const SectionTitle('Our safety promise'),
        for (final t in const [
          'Helpers come from licensed partner agencies, background-checked',
          'Trained in first aid and patient handling, and insured',
          'Only the assigned helper sees the patient profile',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.verified_user_outlined, size: 18, color: CwColors.success),
              const SizedBox(width: 8),
              Expanded(child: Text(t, style: CwText.body)),
            ]),
          ),
        const Gap(12),
        const SectionTitle('Common questions'),
        for (var i = 0; i < faqs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CwCard(
              onTap: () => setState(() => _openFaq = _openFaq == i ? null : i),
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(faqs[i].$1, style: CwText.bodyBold)),
                  Icon(_openFaq == i ? Icons.remove : Icons.add, color: CwColors.primary),
                ]),
                if (_openFaq == i) Padding(padding: const EdgeInsets.only(top: 6), child: Text(faqs[i].$2, style: CwText.muted)),
              ]),
            ),
          ),
        const Gap(18),
        const StepLabel('Payments'),
        const Gap(8),
        link(Icons.account_balance_wallet_outlined, 'Payment methods',
            u?.paymentMethods.firstOrNull?.label ?? 'Add a method', '/account/payments'),
        link(Icons.receipt_long_outlined, 'Receipts', 'Visit receipts and refunds', '/account/receipts'),
        link(Icons.place_outlined, 'Saved places',
            u?.savedPlaces.isEmpty ?? true ? 'Add your home' : '${u!.savedPlaces.first.label} · ${u.savedPlaces.first.address}', '/account/places'),
        const Gap(18),
        const StepLabel('Settings'),
        const Gap(8),
        link(Icons.notifications_none_rounded, 'Notifications', 'Visit updates, reminders', '/account/notifications'),
        link(Icons.text_fields_rounded, 'Language', '${u?.settings.language ?? 'English'} · text size ${_sizeName(u?.settings.textScale ?? 1)}',
            '/account/language'),
        link(Icons.lock_outline, 'Privacy', 'Who can see patient profiles', '/account/privacy'),
        const Gap(18),
        CwButton(
          label: 'Sign out',
          kind: CwButtonKind.secondary,
          color: CwColors.pink,
          onPressed: () => ref.read(authRepoProvider).signOut(),
        ),
        const Gap(10),
        const Text('CareWay for Sime Darby Property townships · version 0.1', textAlign: TextAlign.center, style: CwText.small),
      ],
    );
  }
}

const textSizes = [('Normal', 1.0), ('Large', 1.15), ('Extra large', 1.3)];

String _sizeName(double s) => textSizes.firstWhere((t) => t.$2 == s, orElse: () => textSizes.first).$1.toLowerCase();
