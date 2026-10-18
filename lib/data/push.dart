import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'providers.dart';

class PushMessage {
  const PushMessage(this.title, this.body, this.link);
  final String title, body;
  final String link;
}

/// Everything platform-specific about push, so [PushService] is testable.
abstract class PushPlatform {
  Future<bool> requestPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Stream<PushMessage> get onForeground;
  Stream<String> get onOpenedLink;
  Future<String?> initialLink();
  Future<void> showLocal(PushMessage m);
}

const _channel = AndroidNotificationChannel(
  'careway_updates',
  'CareWay updates',
  importance: Importance.high,
);

class FirebasePushPlatform implements PushPlatform {
  FirebasePushPlatform(this._fm, this._local);
  final FirebaseMessaging _fm;
  final FlutterLocalNotificationsPlugin _local;
  final _tapped = StreamController<String>.broadcast();
  Future<void>? _init;

  Future<void> _ensureInit() => _init ??= () async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) {
        final link = r.payload;
        if (link != null && link.isNotEmpty) _tapped.add(link);
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }();

  static String _link(RemoteMessage m) => (m.data['link'] as String?) ?? '';

  @override
  Future<bool> requestPermission() async {
    await _ensureInit();
    final s = await _fm.requestPermission();
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  // The server sends to FCM registration tokens, so use getToken/onTokenRefresh
  // rather than the newer installation-ID based register() API.
  @override
  // ignore: deprecated_member_use
  Future<String?> getToken() => _fm.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _fm.onTokenRefresh;

  @override
  Stream<PushMessage> get onForeground => FirebaseMessaging.onMessage.map(
    (m) => PushMessage(
      m.notification?.title ?? 'CareWay',
      m.notification?.body ?? '',
      _link(m),
    ),
  );

  @override
  Stream<String> get onOpenedLink => Stream.multi((c) {
    final a = FirebaseMessaging.onMessageOpenedApp
        .map(_link)
        .listen(c.add);
    final b = _tapped.stream.listen(c.add);
    c.onCancel = () {
      a.cancel();
      b.cancel();
    };
  });

  @override
  Future<String?> initialLink() async {
    final m = await _fm.getInitialMessage();
    return m == null ? null : _link(m);
  }

  @override
  Future<void> showLocal(PushMessage m) async {
    await _ensureInit();
    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: m.title,
      body: m.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: m.link,
    );
  }
}

/// Registers this device's push token against the signed-in account.
class PushService {
  PushService(this._platform, this._api, this._go);
  final PushPlatform _platform;
  final CareWayApi _api;
  final void Function(String link) _go;

  String? _token;
  final _subs = <StreamSubscription<Object?>>[];

  Future<void> onSignedIn() async {
    _cancelSubs();
    try {
      if (!await _platform.requestPermission()) return;
      _token = await _platform.getToken();
      if (_token != null) await _api.claimPushToken(_token!);
    } catch (e) {
      debugPrint('push: could not register token: $e');
    }
    _subs.addAll([
      _platform.onTokenRefresh.listen((t) async {
        _token = t;
        try {
          await _api.claimPushToken(t);
        } catch (e) {
          debugPrint('push: could not claim refreshed token: $e');
        }
      }),
      _platform.onForeground.listen(_platform.showLocal),
      _platform.onOpenedLink.listen(_open),
    ]);
    final initial = await _platform.initialLink();
    if (initial != null) _open(initial);
  }

  void _open(String link) {
    if (link.isNotEmpty) _go(link);
  }

  Future<void> beforeSignOut() async {
    final t = _token;
    if (t == null) return;
    try {
      await _api.releasePushToken(t);
    } catch (_) {}
  }

  void _cancelSubs() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  void dispose() => _cancelSubs();
}

/// Releases this device's push token, then signs out.
Future<void> signOutEverywhere(WidgetRef ref) async {
  await ref.read(pushServiceProvider)?.beforeSignOut();
  await ref.read(authRepoProvider).signOut();
}
