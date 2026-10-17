import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';

class CareWayApp extends ConsumerWidget {
  const CareWayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'CareWay',
      debugShowCheckedModeBanner: false,
      theme: CwTheme.light(),
      routerConfig: ref.watch(routerProvider),
      // Phone-shaped layout on wide screens (web).
      builder: (context, child) => ColoredBox(
        color: const Color(0xFFE9E6F2),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: child,
          ),
        ),
      ),
    );
  }
}
