import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/design_kit.dart';
import '../../core/widgets/safety_button.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../../data/push.dart';
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

const _phoneIcon =
    '<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a1 1 0 0 1-1 1A16 16 0 0 1 4 5a1 1 0 0 1 1-1z"/>';

/// Small grey section heading ("HELP AND SAFETY", "PAYMENTS").
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: CwColors.muted)),
      );
}

/// White list card with dividers between rows.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.children, this.radius = 20});
  final List<Widget> children;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          color: CwColors.white,
          child: Column(children: [
            for (var i = 0; i < children.length; i++)
              DecoratedBox(
                decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: kLine))),
                child: children[i],
              ),
          ]),
        ),
      );
}

/// Icon tile + title + subtitle + chevron row.
class LinkRow extends StatelessWidget {
  const LinkRow({super.key, required this.icon, required this.title, required this.sub, required this.onTap});
  final String icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: CwColors.lilac, borderRadius: BorderRadius.circular(12)),
              child: Center(child: CwIcon(icon, size: 20, strokeWidth: 2.2, color: CwColors.primaryDark)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: CwColors.muted)),
              ]),
            ),
            const CwIcon(CwIcons.chevronRight, size: 20, strokeWidth: 2.4, color: Color(0xFF9A96AE)),
          ]),
        ),
      );
}

/// 13 · Account · help and safety (Account.dc.html)
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.section});

  /// 'safety' scrolls to Help and safety.
  final String? section;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _safetyKey = GlobalKey();
  int? _openFaq = 0;
  bool _editing = false;
  bool _saved = false;
  bool _saving = false;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _area = TextEditingController();

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

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _area.dispose();
    super.dispose();
  }

  void _startEdit(AppUser u) {
    _name.text = u.name;
    _phone.text = u.phone;
    _area.text = u.area;
    setState(() {
      _editing = true;
      _saved = false;
    });
  }

  Future<void> _save(AppUser u) async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(userRepoProvider).update(u.uid, {'name': _name.text.trim(), 'phone': _phone.text.trim(), 'area': _area.text.trim()});
      if (mounted) {
        setState(() {
          _editing = false;
          _saved = true;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController c, {TextInputType? type, bool enabled = true}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: CwColors.muted)),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            enabled: enabled,
            keyboardType: type,
            style: const TextStyle(fontSize: 15, color: CwColors.ink),
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(currentUserProvider).value;
    final family = ref.watch(familyProvider).value;
    const white90 = Color(0xE6FFFFFF);

    final children = <Widget>[
      const Text('Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      if (u != null && !_editing)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: CwColors.primary, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: CwColors.white, shape: BoxShape.circle),
              child: Text(u.initials, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CwColors.white)),
                const SizedBox(height: 2),
                Text([u.phone, u.area].where((s) => s.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 13, color: white90)),
                const SizedBox(height: 2),
                Text(u.email, style: const TextStyle(fontSize: 12, color: white90)),
                if (family != null) ...[
                  const SizedBox(height: 2),
                  Text('${family.adminUid == u.uid ? 'Admin' : 'Member'} · ${family.name}', style: const TextStyle(fontSize: 12, color: white90)),
                ],
              ]),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: TextButton(
                onPressed: () => _startEdit(u),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0x33FFFFFF),
                  foregroundColor: CwColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontFamily: cwFont, fontSize: 13, fontWeight: FontWeight.w800),
                ),
                child: const Text('Edit'),
              ),
            ),
          ]),
        ),
      if (u != null && !_editing && _saved)
        Transform.translate(
          offset: const Offset(0, -8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: CwColors.successSoft, borderRadius: BorderRadius.circular(12)),
            child: const Text('Profile updated', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1D6B45))),
          ),
        ),
      if (u != null && _editing)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CwColors.white,
            border: Border.all(color: CwColors.primary, width: 2),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Edit your details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _field('Full name', _name),
            const SizedBox(height: 12),
            _field('Phone number', _phone, type: TextInputType.phone),
            const SizedBox(height: 12),
            _field('Email', TextEditingController(text: u.email), enabled: false),
            const SizedBox(height: 12),
            _field('Home area', _area),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                flex: 10,
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _editing = false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kInk2,
                      side: const BorderSide(color: CwColors.line, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontFamily: cwFont, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 16,
                child: BigButton(label: 'Save', height: 50, fontSize: 15, radius: 14, loading: _saving, onPressed: () => _save(u)),
              ),
            ]),
          ]),
        ),
      GroupLabel('Help and safety', key: _safetyKey),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: CwColors.white,
          border: Border.all(color: CwColors.pink, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: CwColors.pinkSoft, borderRadius: BorderRadius.circular(10)),
              child: const Center(child: CwIcon(CwIcons.plus, size: 20, strokeWidth: 2.6, color: CwColors.pink)),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('Emergency at home?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFA02A4C)))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hospital Sungai Buloh', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Nearest ER · 24 hours · ~10 km', style: TextStyle(fontSize: 12, color: CwColors.muted)),
              ]),
            ),
            const SizedBox(width: 10),
            _CallPill(label: 'Call ER', background: CwColors.pink, foreground: CwColors.white, onTap: () => callNumber(context, emergencyNumber)),
          ]),
          const SizedBox(height: 12),
          _CallPill(
            label: 'Call for urgent escort',
            background: CwColors.pinkSoft,
            foreground: const Color(0xFFA02A4C),
            expand: true,
            onTap: () => callNumber(context, coordinatorNumber),
          ),
        ]),
      ),
      Material(
        color: CwColors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => callNumber(context, coordinatorNumber),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: CwColors.lilac, borderRadius: BorderRadius.circular(12)),
                child: const Center(
                  child: CwIcon('<path d="M4 12a8 8 0 0 1 16 0v5a2 2 0 0 1-2 2h-2v-6h4M4 13h4v6H6a2 2 0 0 1-2-2z"/>', size: 20, strokeWidth: 2.2, color: CwColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Call CareWay coordinator', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('[Support hours]', style: TextStyle(fontSize: 12, color: CwColors.muted)),
                ]),
              ),
              const CwIcon(CwIcons.chevronRight, size: 20, strokeWidth: 2.4, color: Color(0xFF9A96AE)),
            ]),
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Our safety promise', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          for (final t in const [
            'Helpers come from licensed partner agencies, background-checked',
            'Trained in first aid and patient handling, and insured',
            'Only the assigned helper sees the patient profile',
          ]) ...[
            const SizedBox(height: 10),
            Row(children: [
              const CwIcon(CwIcons.check, size: 18, strokeWidth: 2.6, color: CwColors.teal),
              const SizedBox(width: 10),
              Expanded(child: Text(t, style: const TextStyle(fontSize: 13))),
            ]),
          ],
        ]),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Common questions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        for (var i = 0; i < faqs.length; i++) ...[
          const SizedBox(height: 8),
          Material(
            color: CwColors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _openFaq = _openFaq == i ? null : i),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(children: [
                    Expanded(child: Text(faqs[i].$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _openFaq == i ? 0.125 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: const Text('+', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: CwColors.primary)),
                    ),
                  ]),
                ),
                if (_openFaq == i)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Text(faqs[i].$2, style: const TextStyle(fontSize: 12, height: 1.5, color: CwColors.muted)),
                  ),
              ]),
            ),
          ),
        ],
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const GroupLabel('Payments'),
        const SizedBox(height: 8),
        ListCard(children: [
          LinkRow(
            icon: '<rect x="3" y="6" width="18" height="13" rx="3"/><path d="M3 10h18M7 15h4"/>',
            title: 'Payment methods',
            sub: u?.paymentMethods.firstOrNull?.label ?? 'Add a method',
            onTap: () => context.push('/account/payments'),
          ),
          LinkRow(
            icon: '<path d="M4 4h16v16H4z"/><path d="M8 9h8M8 13h8M8 17h5"/>',
            title: 'Receipts',
            sub: 'Visit receipts and refunds',
            onTap: () => context.push('/account/receipts'),
          ),
          LinkRow(
            icon: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
            title: 'Saved places',
            sub: u?.savedPlaces.isEmpty ?? true ? 'Add your home' : '${u!.savedPlaces.first.label} · ${u.savedPlaces.first.address}',
            onTap: () => context.push('/account/places'),
          ),
        ]),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const GroupLabel('Settings'),
        const SizedBox(height: 8),
        ListCard(children: [
          LinkRow(
            icon: '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 8 3 8H3s3-1 3-8"/><path d="M10 20a2 2 0 0 0 4 0"/>',
            title: 'Notifications',
            sub: 'Visit updates, reminders',
            onTap: () => context.push('/account/notifications'),
          ),
          LinkRow(
            icon: lockIcon,
            title: 'Privacy',
            sub: 'Who can see patient profiles',
            onTap: () => context.push('/account/privacy'),
          ),
        ]),
      ]),
      Material(
        color: CwColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => signOutEverywhere(ref),
          child: const SizedBox(
            height: 52,
            child: Center(child: Text('Sign out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFA02A4C)))),
          ),
        ),
      ),
      const Text('CareWay for Sime Darby Property townships · version 0.1', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: CwColors.muted)),
    ];

    return Scaffold(
      backgroundColor: CwColors.surface,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: children[i] is GroupLabel ? 8 : 14),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _CallPill extends StatelessWidget {
  const _CallPill({required this.label, required this.background, required this.foreground, required this.onTap, this.expand = false});
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) => Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                CwIcon(_phoneIcon, size: 16, strokeWidth: 2.4, color: foreground),
                SizedBox(width: expand ? 8 : 6),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: foreground))),
              ]),
            ),
          ),
        ),
      );
}

const textSizes = [('Normal', 1.0), ('Large', 1.15), ('Extra large', 1.3)];

