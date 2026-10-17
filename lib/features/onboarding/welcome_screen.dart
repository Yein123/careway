import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/art.dart';
import '../../core/theme.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_page.dart';

/// 1 · Welcome (Main.dc.html)
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CwColors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 72),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const CwLogo(),
                    const SizedBox(height: 36),
                    SvgPicture.string(
                      welcomeHeroSvg,
                      width: 280,
                      height: 280,
                      semanticsLabel:
                          'A CareWay helper walks an older woman with a cane to the clinic',
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Welcome to CareWay',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Affordable, trusted help to get your family to and through their medical visits.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: CwColors.muted,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    CwButton(
                      label: 'Get started',
                      trailing: Icons.arrow_forward,
                      onPressed: () => context.go('/start'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Already have an account?',
                          style: TextStyle(fontSize: 15, color: CwColors.muted),
                        ),
                        TextButton(
                          onPressed: () => context.go('/signin'),
                          child: const Text(
                            'Sign in',
                            style: TextStyle(fontWeight: FontWeight.w800),
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
                        "I'm a CareWay helper",
                        style: TextStyle(fontWeight: FontWeight.w700),
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
}
