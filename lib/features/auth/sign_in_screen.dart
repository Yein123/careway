import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/cw_button.dart';

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
  bool _remember = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

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
    final fields = <Widget>[
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
            _show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: CwColors.muted,
          ),
          onPressed: () => setState(() => _show = !_show),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          _error!,
          style: const TextStyle(
            color: CwColors.pink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ];

    if (cg) return _caregiver(fields, canSubmit);

    return Scaffold(
      backgroundColor: CwColors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 52),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SquareIconButton(
                        svg: CwIcons.back,
                        background: CwColors.surface,
                        label: 'Back',
                        onTap: () => context.go('/'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Sign in to book and follow your family's visits.",
                      style: TextStyle(fontSize: 15, color: CwColors.muted),
                    ),
                    const SizedBox(height: 20),
                    ...fields,
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: CwCheckRow(
                            checked: _remember,
                            onChanged: (v) => setState(() => _remember = v),
                            child: const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                'Keep me signed in',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _reset,
                          style: TextButton.styleFrom(
                            foregroundColor: CwColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CwButton(
                      label: 'Sign in',
                      loading: _busy,
                      onPressed: canSubmit ? _signIn : null,
                    ),
                    if (kDebugMode) const _DemoAccounts(),
                    const Spacer(),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'New to CareWay?',
                          style: TextStyle(fontSize: 15, color: CwColors.muted),
                        ),
                        TextButton(
                          onPressed: () => context.go('/start'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: const Text(
                            'Get started',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => context.go('/cg/signin'),
                      style: TextButton.styleFrom(
                        foregroundColor: CwColors.teal,
                      ),
                      child: const Text(
                        "I'm a CareWay caregiver",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// C1 · Caregiver sign in: teal screen with the form on a white card.
  Widget _caregiver(List<Widget> fields, bool canSubmit) => Scaffold(
    backgroundColor: CwColors.teal,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 56, 28, 36),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight - 92),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/careway-caregiver-icon-512.png',
                          width: 44,
                          height: 44,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CareWay',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: CwColors.white,
                            ),
                          ),
                          Text(
                            'CAREGIVER',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: Color(0xD9FFFFFF),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.go('/'),
                        style: TextButton.styleFrom(
                          foregroundColor: CwColors.white,
                        ),
                        child: const Text(
                          'Back',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  const Text(
                    'Your jobs, patients and updates in one place',
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: CwColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'For helpers and escorts from CareWay partner agencies.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xE6FFFFFF),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: CwColors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...fields,
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _reset,
                            style: TextButton.styleFrom(
                              foregroundColor: CwColors.teal,
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        CwButton(
                          label: 'Sign in',
                          color: CwColors.teal,
                          loading: _busy,
                          onPressed: canSubmit ? _signIn : null,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'New to CareWay? Your agency sends you an invite.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5B6F75),
                          ),
                        ),
                        if (kDebugMode) const _DemoAccounts(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// Debug-only helper for the emulator demo.
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
            'Guardian: parent@gmail.com · user@gmail.com · self@gmail.com\nCaregiver: caregiver@gmail.com (+ farid@ · nurul@ · meiling@careway.demo)\nPassword: careway123',
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
