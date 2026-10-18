import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/tab_bars.dart';

/// Guardian tabs: Home, Visits, Family, Account.
class GuardianShell extends StatelessWidget {
  const GuardianShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: CwColors.surface,
    body: shell,
    bottomNavigationBar: GuardianTabBar(
      currentIndex: shell.currentIndex,
      onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
    ),
  );
}

/// Caregiver tabs: Today, Schedule, Patients, Account.
class CaregiverShell extends StatelessWidget {
  const CaregiverShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: CwColors.surface,
    body: shell,
    bottomNavigationBar: CaregiverTabBar(
      currentIndex: shell.currentIndex,
      onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
    ),
  );
}
