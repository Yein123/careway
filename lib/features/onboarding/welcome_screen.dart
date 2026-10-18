import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/art.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/design_kit.dart';

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
            padding: const EdgeInsets.fromLTRB(28, 56, 28, 40),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 96),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const CwLogo(),
                    const SizedBox(height: 44),
                    SvgPicture.string(
                      welcomeHeroSvg,
                      width: 300,
                      height: 300,
                      semanticsLabel: 'A CareWay helper walks an older woman with a cane to the clinic',
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Welcome to CareWay',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 30, height: 1.2, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Affordable, trusted help to get your family to and through their medical visits.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, height: 1.5, color: CwColors.muted),
                    ),
                    const SizedBox(height: 24),
                    ExcludeSemantics(
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(width: 24, height: 6, decoration: BoxDecoration(color: CwColors.primary, borderRadius: BorderRadius.circular(3))),
                        for (var i = 0; i < 2; i++) ...[
                          const SizedBox(width: 6),
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: CwColors.lilacLine, borderRadius: BorderRadius.circular(3))),
                        ],
                      ]),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 58,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => context.go('/start'),
                        style: FilledButton.styleFrom(
                          backgroundColor: CwColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(fontFamily: cwFont, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Get started'),
                          SizedBox(width: 12),
                          CwIcon(CwIcons.arrowRight, size: 22, strokeWidth: 2.2, color: CwColors.white),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Already have an account?', style: TextStyle(fontSize: 15, color: CwColors.muted)),
                        TextButton(
                          onPressed: () => context.go('/signin'),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                          child: const Text('Sign in', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    LinkButton(
                      label: "I'm a CareWay caregiver",
                      color: CwColors.teal,
                      height: 36,
                      fontSize: 13,
                      onPressed: () => context.go('/cg/signin'),
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
