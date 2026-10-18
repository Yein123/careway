import 'dart:async';

import 'package:careway/data/providers.dart';
import 'package:careway/data/push.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_api.dart';
import '../fakes/fake_repos.dart';

class FakePushPlatform implements PushPlatform {
  String? token = 'tok-1';
  bool granted = true;
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<String>.broadcast();
  String? initial;
  final shown = <PushMessage>[];

  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<String?> getToken() async => token;
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Stream<PushMessage> get onForeground => foreground.stream;
  @override
  Stream<String> get onOpenedLink => opened.stream;
  @override
  Future<String?> initialLink() async => initial;
  @override
  Future<void> showLocal(PushMessage m) async => shown.add(m);
}

void main() {
  late FakePushPlatform platform;
  late FakeApi api;
  late List<String> went;
  late PushService service;

  setUp(() {
    platform = FakePushPlatform();
    api = FakeApi();
    went = [];
    service = PushService(platform, api, went.add);
  });
  tearDown(() => service.dispose());

  test('onSignedIn claims the token', () async {
    await service.onSignedIn();
    expect(api.argsOf('claimPushToken'), ['tok-1']);
  });

  test('token refresh claims the new token', () async {
    await service.onSignedIn();
    platform.refresh.add('tok-2');
    await Future<void>.delayed(Duration.zero);
    expect(api.argsOf('claimPushToken'), ['tok-1', 'tok-2']);
  });

  test('foreground message is shown locally', () async {
    await service.onSignedIn();
    platform.foreground.add(const PushMessage('Hi', 'Body', '/x'));
    await Future<void>.delayed(Duration.zero);
    expect(platform.shown.single.title, 'Hi');
  });

  test('opened notification navigates to its link', () async {
    await service.onSignedIn();
    platform.opened.add('/bookings/b1');
    platform.opened.add('');
    await Future<void>.delayed(Duration.zero);
    expect(went, ['/bookings/b1']);
  });

  test('beforeSignOut releases the token', () async {
    await service.onSignedIn();
    await service.beforeSignOut();
    expect(api.argsOf('releasePushToken'), ['tok-1']);
  });

  test('beforeSignOut swallows API errors', () async {
    await service.onSignedIn();
    api.nextError = Exception('boom');
    await service.beforeSignOut();
    expect(api.argsOf('releasePushToken'), ['tok-1']);
  });

  test('a stale token from the previous account is never released', () async {
    await service.onSignedIn(); // account A, tok-1
    await service.beforeSignOut();
    platform.granted = false;
    await service.onSignedIn(); // account B, permission denied
    await service.beforeSignOut();
    expect(api.argsOf('releasePushToken'), ['tok-1']);
  });

  test('concurrent onSignedIn attaches a single set of subscriptions', () async {
    final a = service.onSignedIn();
    final b = service.onSignedIn();
    await Future.wait([a, b]);
    platform.foreground.add(const PushMessage('Hi', 'Body', ''));
    await Future<void>.delayed(Duration.zero);
    expect(platform.shown, hasLength(1));
  });

  testWidgets('signOutEverywhere releases the token before signing out', (
    tester,
  ) async {
    final order = <String>[];
    final auth = _OrderedAuth(order);
    final tapi = _OrderedApi(order);
    final svc = PushService(platform, tapi, (_) {});
    await svc.onSignedIn();
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepoProvider.overrideWithValue(auth),
          pushServiceProvider.overrideWithValue(svc),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await signOutEverywhere(captured);
    expect(order, ['release:tok-1', 'signOut']);
    svc.dispose();
  });
}

class _OrderedAuth extends FakeAuthRepo {
  _OrderedAuth(this.order);
  final List<String> order;
  @override
  Future<void> signOut() async {
    order.add('signOut');
    await super.signOut();
  }
}

class _OrderedApi extends FakeApi {
  _OrderedApi(this.order);
  final List<String> order;
  @override
  Future<void> releasePushToken(String token) async {
    order.add('release:$token');
    await super.releasePushToken(token);
  }
}
