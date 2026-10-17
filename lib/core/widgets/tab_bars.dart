import 'package:flutter/material.dart';

import '../theme.dart';

class _TabBar extends StatelessWidget {
  const _TabBar({required this.currentIndex, required this.onTap, required this.items, required this.accent});

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<(IconData, String)> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: CwColors.white,
        indicatorColor: accent.withValues(alpha: 0.12),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: cwFont, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        destinations: [
          for (final (icon, label) in items)
            NavigationDestination(icon: Icon(icon), selectedIcon: Icon(icon, color: accent), label: label),
        ],
      ),
    );
  }
}

class GuardianTabBar extends StatelessWidget {
  const GuardianTabBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => _TabBar(
        currentIndex: currentIndex,
        onTap: onTap,
        accent: CwColors.primary,
        items: const [
          (Icons.home_outlined, 'Home'),
          (Icons.event_note_outlined, 'Visits'),
          (Icons.groups_outlined, 'Family'),
          (Icons.person_outline, 'Account'),
        ],
      );
}

class CaregiverTabBar extends StatelessWidget {
  const CaregiverTabBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => _TabBar(
        currentIndex: currentIndex,
        onTap: onTap,
        accent: CwColors.teal,
        items: const [
          (Icons.today_outlined, 'Today'),
          (Icons.calendar_month_outlined, 'Schedule'),
          (Icons.people_outline, 'Patients'),
          (Icons.person_outline, 'Account'),
        ],
      );
}
