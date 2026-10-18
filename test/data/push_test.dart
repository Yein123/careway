import 'dart:async';

import 'package:careway/data/push.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_api.dart';

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
}
