import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final _router = GoRouter(routes: [
  GoRoute(
    path: '/',
    builder: (context, state) =>
        const Scaffold(body: Center(child: Text('Welcome to CareWay'))),
  ),
]);

class CareWayApp extends StatelessWidget {
  const CareWayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CareWay',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
