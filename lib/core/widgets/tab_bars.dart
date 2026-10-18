import 'package:flutter/material.dart';

import '../icons.dart';
import '../theme.dart';

/// Bottom navigation as drawn in the design: white, 76 px, rounded top.
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.accent,
    required this.idle,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<(String, String)> items;
  final Color accent;
  final Color idle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CwColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < items.length; i++)
                  _TabItem(
                    icon: items[i].$1,
                    label: items[i].$2,
                    active: i == currentIndex,
                    color: i == currentIndex ? accent : idle,
                    onTap: () => onTap(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: active,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 64, minHeight: 56),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CwIcon(icon, color: color, strokeWidth: active ? 2.2 : 2),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class GuardianTabBar extends StatelessWidget {
  const GuardianTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => _TabBar(
    currentIndex: currentIndex,
    onTap: onTap,
    accent: CwColors.primary,
    idle: CwColors.muted,
    items: const [
      (CwIcons.home, 'Home'),
      (CwIcons.calendar, 'Visits'),
      (CwIcons.family, 'Family'),
      (CwIcons.person, 'Account'),
    ],
  );
}

class CaregiverTabBar extends StatelessWidget {
  const CaregiverTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => _TabBar(
    currentIndex: currentIndex,
    onTap: onTap,
    accent: CwColors.teal,
    idle: const Color(0xFF5B6F75),
    items: const [
      (CwIcons.home, 'Today'),
      (CwIcons.calendar, 'Schedule'),
      (CwIcons.family, 'Patients'),
      (CwIcons.person, 'Account'),
    ],
  );
}
