import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/art.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_top_bar.dart';
import '../../core/widgets/fields.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../../data/repos/auth_repo.dart';

const _slides = [
  (
    'Add who you care for',
    'Save Mum, Dad or your child once: mobility, medical notes, allergies and contacts. Your family group can help keep it up to date.',
  ),
  (
    'Book a visit in a minute',
    'Pick the patient, hospital, date and time. Choose a shared ride with a helper, or a one-to-one escort for the whole visit.',
  ),
  (
    'Follow the visit live',
    "See pickup, arrival and the ride home with the van plate number. Get a short summary and the doctor's instructions afterwards.",
  ),
];

/// 0a · Get started: how it works + create account (GetStarted.dc.html)
class GetStartedScreen extends ConsumerStatefulWidget {
  const GetStartedScreen({super.key});

  @override
  ConsumerState<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends ConsumerState<GetStartedScreen> {
  int _i = 0;
  bool _agree = true;
  bool _busy = false;
  String? _error;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _area = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool get _onForm => _i >= _slides.length;

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      emailPattern.hasMatch(_email.text.trim()) &&
      _phone.text.replaceAll(RegExp(r'\D'), '').length >= 8 &&
      _pass.text.length >= 8 &&
      _agree;

  @override
  void dispose() {
    for (final c in [_name, _phone, _area, _email, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    // Capture everything before awaiting: the router may redirect away mid-way.
    final auth = ref.read(authRepoProvider);
    final users = ref.read(userRepoProvider);
    final families = ref.read(familyRepoProvider);
    final router = ref.read(routerProvider);
    final name = _name.text.trim();
    try {
      final uid = await auth.signUp(_email.text.trim(), _pass.text);
      await users.create(
        AppUser(
          uid: uid,
          name: name,
          email: _email.text.trim(),
          phone: '+60 ${_phone.text.trim()}',
          area: _area.text.trim(),
          role: UserRole.guardian,
        ),
      );
      await families.createFamily(
        name: "${name.split(' ').first}'s family",
        adminUid: uid,
        adminName: name,
      );
      router.go('/family');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CwColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  SquareIconButton(
                    icon: Icons.chevron_left,
                    label: 'Back',
                    onTap: () =>
                        _i == 0 ? context.go('/') : setState(() => _i--),
                  ),
                  Expanded(
                    child: Text(
                      _onForm ? 'Last step' : '${_i + 1} of ${_slides.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CwColors.muted,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: _onForm
                        ? null
                        : TextButton(
                            onPressed: () =>
                                setState(() => _i = _slides.length),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: CwColors.primaryDark,
                            ),
                            child: const Text(
                              'Skip',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: _onForm ? _form() : _slide()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slide() {
    final (title, body) = _slides[_i];
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 8),
                SvgPicture.string(
                  onboardingArtSvgs[_i],
                  width: 220,
                  height: 220,
                ),
                const SizedBox(height: 16),
                Text('STEP ${_i + 1}', style: CwText.overline),
                const SizedBox(height: 12),
                Text(title, textAlign: TextAlign.center, style: CwText.h1),
                const SizedBox(height: 12),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: CwColors.muted,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var j = 0; j < _slides.length; j++)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: j == _i ? 24 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: j == _i
                              ? CwColors.primary
                              : CwColors.lilacLine,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        CwButton(
          label: _i == _slides.length - 1 ? 'Create my account' : 'Next',
          onPressed: () => setState(() => _i++),
        ),
      ],
    );
  }

  Widget _form() {
    void changed(String _) => setState(() {});
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Create your account', style: CwText.h1),
          const SizedBox(height: 6),
          const Text(
            "Next you'll set up your family group and add who you care for.",
            style: CwText.muted,
          ),
          const SizedBox(height: 18),
          LabeledField(
            label: 'Your name',
            controller: _name,
            fieldKey: const ValueKey('gs-name'),
            hint: 'e.g. Aisyah binti Hassan',
            onChanged: changed,
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Phone number',
            controller: _phone,
            fieldKey: const ValueKey('gs-phone'),
            hint: '12-345 6789',
            prefix: '+60',
            keyboardType: TextInputType.phone,
            onChanged: changed,
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Township',
            controller: _area,
            fieldKey: const ValueKey('gs-area'),
            hint: 'e.g. Elmina, Shah Alam',
            optional: true,
            onChanged: changed,
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Email',
            controller: _email,
            fieldKey: const ValueKey('gs-email'),
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            onChanged: changed,
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Create a password',
            controller: _pass,
            fieldKey: const ValueKey('gs-pass'),
            hint: 'At least 8 characters',
            obscure: true,
            onChanged: changed,
          ),
          const SizedBox(height: 10),
          CwCheckRow(
            boxKey: const ValueKey('gs-agree'),
            checked: _agree,
            onChanged: (v) => setState(() => _agree = v),
            child: const Text(
              'I agree to the Terms and Privacy Policy, including how patient details are shared with assigned helpers.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF3D3955),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                color: CwColors.pink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 20),
          CwButton(
            label: 'Create account',
            loading: _busy,
            onPressed: _valid ? _create : null,
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Already have an account?', style: CwText.muted),
              TextButton(
                onPressed: () => context.go('/signin'),
                child: const Text(
                  'Sign in',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
