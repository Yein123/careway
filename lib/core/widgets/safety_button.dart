import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import 'cw_top_bar.dart';

/// Shield button that opens Help and safety in the Account tab.
class SafetyButton extends StatelessWidget {
  const SafetyButton({super.key});

  @override
  Widget build(BuildContext context) => SquareIconButton(
    icon: Icons.shield_outlined,
    label: 'Help and safety',
    color: CwColors.pink,
    onTap: () => context.go('/account?section=safety'),
  );
}
