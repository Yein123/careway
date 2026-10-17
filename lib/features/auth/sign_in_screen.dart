import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/cw_top_bar.dart';
import '../../core/widgets/fields.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../data/repos/auth_repo.dart';

/// 0b · Sign in (SignIn.dc.html) and C1 · Caregiver sign in (CgLogin.dc.html).
/// Navigation after success is handled by the router's role redirect.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.caregiver = false});
  final bool caregiver;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Color get _accent => widget.caregiver ? CwColors.teal : CwColors.primary;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepoProvider).signIn(_email.text, _pass.text);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!emailPattern.hasMatch(_email.text.trim())) {
      setState(
        () => _error = 'Enter your email above, then tap Forgot password.',
      );
      return;
    }
    try {
      await ref.read(authRepoProvider).sendPasswordReset(_email.text);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Check your email for a link to reset your password.'),
        ),
      );
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cg = widget.caregiver;
    final canSubmit =
        emailPattern.hasMatch(_email.text.trim()) && _pass.text.isNotEmpty;
    return Scaffold(
      backgroundColor: CwColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SquareIconButton(
                  icon: Icons.chevron_left,
                  label: 'Back',
                  onTap: () => context.go('/'),
                ),
              ),
              const SizedBox(height: 20),
              if (cg) ...[
                CwLogo(color: CwColors.teal, label: 'CAREGIVER'),
                const SizedBox(height: 24),
                const Text(
                  'Your jobs, patients and updates in one place',
                  style: CwText.h1,
                ),
                const SizedBox(height: 8),
                const Text(
                  'For helpers and escorts from CareWay partner agencies.',
                  style: CwText.muted,
                ),
              ] else ...[
                const Text('Welcome back', style: CwText.h1),
                const SizedBox(height: 8),
                const Text(
                  "Sign in to book and follow your family's visits.",
                  style: CwText.muted,
                ),
              ],
              const SizedBox(height: 24),
              LabeledField(
                label: 'Email',
                controller: _email,
                fieldKey: const ValueKey('si-email'),
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: 'Password',
                controller: _pass,
                fieldKey: const ValueKey('si-pass'),
                obscure: !_show,
                onChanged: (_) => setState(() {}),
                suffix: IconButton(
                  tooltip: _show ? 'Hide password' : 'Show password',
                  icon: Icon(
                    _show
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _reset,
                  style: TextButton.styleFrom(foregroundColor: _accent),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(
                    color: CwColors.pink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              CwButton(
                label: 'Sign in',
                color: _accent,
                loading: _busy,
                onPressed: canSubmit ? _signIn : null,
              ),
              const SizedBox(height: 16),
              if (cg)
                const Text(
                  'New to CareWay? Your agency sends you an invite.',
                  textAlign: TextAlign.center,
                  style: CwText.muted,
                )
              else ...[
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('New to CareWay?', style: CwText.muted),
                    TextButton(
                      onPressed: () => context.go('/start'),
                      child: const Text(
                        'Get started',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/cg/signin'),
                  style: TextButton.styleFrom(foregroundColor: CwColors.teal),
                  child: const Text(
                    "I'm a CareWay caregiver",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              if (kDebugMode) const _DemoAccounts(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Debug-only helper for the emulator demo.
class _DemoAccounts extends ConsumerStatefulWidget {
  const _DemoAccounts();

  @override
  ConsumerState<_DemoAccounts> createState() => _DemoAccountsState();
}

class _DemoAccountsState extends ConsumerState<_DemoAccounts> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CwColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DEMO (debug builds only)', style: CwText.overline),
          const SizedBox(height: 6),
          const Text(
            'Guardian: aisyah@careway.demo\nHelpers: farid@ · nurul@ · meiling@ · ravi@careway.demo\nPassword: careway123',
            style: CwText.small,
          ),
          TextButton(
            onPressed: () async {
              setState(() => _status = 'Loading…');
              try {
                await ref.read(careWayApiProvider).seedDemo();
                if (mounted) setState(() => _status = 'Demo data loaded.');
              } catch (e) {
                if (mounted) setState(() => _status = friendlyError(e));
              }
            },
            child: const Text('Load demo data'),
          ),
          if (_status != null) Text(_status!, style: CwText.small),
        ],
      ),
    );
  }
}
