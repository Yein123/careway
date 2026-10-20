import 'dart:async';

import 'package:careway/data/models/booking.dart';
import 'package:careway/data/models/caregiver.dart';
import 'package:careway/data/models/delivery.dart';
import 'package:careway/data/models/family.dart';
import 'package:careway/data/models/group.dart';
import 'package:careway/data/models/notification.dart';
import 'package:careway/data/models/offer.dart';
import 'package:careway/data/models/user.dart';
import 'package:careway/data/providers.dart';
import 'package:careway/features/admin/admin_providers.dart';
import 'package:careway/data/repos/auth_repo.dart';
import 'package:careway/data/repos/booking_repo.dart';
import 'package:careway/data/repos/family_repo.dart';
import 'package:careway/data/repos/notification_repo.dart';
import 'package:careway/data/repos/user_repo.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// A list of items that re-emits to watchers on every change.
class Live<T> {
  Live([List<T>? initial]) : items = [...?initial];

  final List<T> items;
  final _changes = StreamController<void>.broadcast(sync: true);

  Stream<R> watch<R>(R Function(List<T>) select) => Stream.multi((c) {
    c.add(select(items));
    final sub = _changes.stream.listen((_) => c.add(select(items)));
    c.onCancel = sub.cancel;
  });

  void set(List<T> next) {
    items
      ..clear()
      ..addAll(next);
    _changes.add(null);
  }

  void upsert(T item, bool Function(T) same) {
    final i = items.indexWhere(same);
    if (i >= 0) {
      items[i] = item;
    } else {
      items.add(item);
    }
    _changes.add(null);
  }
}

class FakeAuthRepo implements AuthRepo {
  FakeAuthRepo({String? uid, this.passwords = const {}}) : _uid = Live([uid]);

  final Live<String?> _uid;
  final Map<String, String> passwords;
  final List<String> signUps = [];
  int signOuts = 0;

  @override
  Stream<String?> get authState => _uid.watch((l) => l.first);

  @override
  String? get currentUid => _uid.items.first;

  void setUid(String? uid) => _uid.set([uid]);

  @override
  Future<String> signIn(String email, String password) async {
    if (passwords[email] != password) {
      throw const AuthFailure('Email or password is incorrect.');
    }
    setUid('uid-$email');
    return 'uid-$email';
  }

  @override
  Future<String> signUp(String email, String password) async {
    signUps.add(email);
    setUid('uid-$email');
    return 'uid-$email';
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    setUid(null);
  }

  final List<String> resets = [];

  @override
  Future<void> sendPasswordReset(String email) async => resets.add(email);
}

class FakeUserRepo implements UserRepo {
  FakeUserRepo([List<AppUser>? users]) : users = Live(users);
  final Live<AppUser> users;
  final List<(String, Map<String, dynamic>)> updates = [];

  @override
  Stream<AppUser?> watch(String uid) => users.watch((l) {
    for (final u in l) {
      if (u.uid == uid) return u;
    }
    return null;
  });

  @override
  Future<void> create(AppUser user) async =>
      users.upsert(user, (u) => u.uid == user.uid);

  @override
  Future<void> update(String uid, Map<String, dynamic> fields) async {
    updates.add((uid, fields));
    final i = users.items.indexWhere((u) => u.uid == uid);
    if (i < 0) return;
    final merged = {...users.items[i].toMap()};
    fields.forEach((k, v) {
      // Support 'settings.textScale' style dotted keys.
      final parts = k.split('.');
      Map<String, dynamic> target = merged;
      for (final p in parts.take(parts.length - 1)) {
        target = target[p] = Map<String, dynamic>.from(target[p] as Map? ?? {});
      }
      target[parts.last] = v;
    });
    users.upsert(AppUser.fromMap(uid, merged), (u) => u.uid == uid);
  }
}

class FakeCaregiverRepo implements CaregiverRepo {
  FakeCaregiverRepo([List<CaregiverProfile>? cgs]) : cgs = Live(cgs);
  final Live<CaregiverProfile> cgs;

  @override
  Stream<CaregiverProfile?> watch(String uid) => cgs.watch((l) {
    for (final c in l) {
      if (c.uid == uid) return c;
    }
    return null;
  });

  @override
  Future<void> setOnDuty(String uid, bool onDuty) async {
    final c = cgs.items.firstWhere((c) => c.uid == uid);
    cgs.upsert(
      CaregiverProfile.fromMap(uid, {...c.toMap(), 'onDuty': onDuty}),
      (x) => x.uid == uid,
    );
  }
}

class FakeFamilyRepo implements FamilyRepo {
  FakeFamilyRepo({List<Family>? families, Map<String, List<Patient>>? patients})
    : families = Live(families),
      patients = Live([
        for (final e in (patients ?? {}).entries)
          for (final p in e.value) (e.key, p),
      ]);

  final Live<Family> families;
  final Live<(String, Patient)> patients;
  final List<Patient> saved = [];
  int _ids = 0;

  /// Called with (adminUid, familyId) so the user's familyId can be linked.
  void Function(String uid, String fid)? onFamilyCreated;

  @override
  Stream<Family?> watchFamily(String fid) => families.watch((l) {
    for (final f in l) {
      if (f.id == fid) return f;
    }
    return null;
  });

  @override
  Stream<List<Patient>> watchPatients(String fid) => patients.watch(
    (l) => [
      for (final (f, p) in l)
        if (f == fid) p,
    ],
  );

  @override
  Stream<Patient?> watchPatient(String fid, String pid) => patients.watch((l) {
    for (final (f, p) in l) {
      if (f == fid && p.id == pid) return p;
    }
    return null;
  });

  @override
  Future<String> createFamily({
    required String name,
    required String adminUid,
    required String adminName,
  }) async {
    final id = 'fam${++_ids}';
    families.upsert(
      Family(
        id: id,
        name: name,
        adminUid: adminUid,
        memberUids: [adminUid],
        memberNames: {adminUid: adminName},
      ),
      (f) => f.id == id,
    );
    onFamilyCreated?.call(adminUid, id);
    return id;
  }

  @override
  Future<String> savePatient(String fid, Patient patient) async {
    final id = patient.id.isEmpty ? 'p${++_ids}' : patient.id;
    final p = Patient.fromMap(id, patient.toMap());
    saved.add(p);
    patients.upsert((fid, p), (e) => e.$1 == fid && e.$2.id == id);
    return id;
  }
}

class FakeBookingRepo implements BookingRepo {
  FakeBookingRepo([List<Booking>? bookings]) : bookings = Live(bookings);
  final Live<Booking> bookings;
  final List<(String, Rating)> ratings = [];

  void put(Booking b) => bookings.upsert(b, (x) => x.id == b.id);

  @override
  Stream<List<Booking>> watchForFamily(String fid) => bookings.watch(
    (l) => [
      for (final b in l)
        if (b.familyId == fid) b,
    ],
  );

  @override
  Stream<Booking?> watch(String id) => bookings.watch((l) {
    for (final b in l) {
      if (b.id == id) return b;
    }
    return null;
  });

  @override
  Stream<List<Booking>> watchForCaregiver(String uid) => bookings.watch(
    (l) => [
      for (final b in l)
        if (b.caregiverId == uid) b,
    ],
  );

  @override
  Future<void> rate(String id, Rating rating) async {
    ratings.add((id, rating));
    final b = bookings.items.firstWhere((b) => b.id == id);
    put(Booking.fromMap(id, {...b.toMap(), 'rating': rating.toMap()}));
  }
}

class FakeGroupRepo implements GroupRepo {
  FakeGroupRepo([List<Group>? groups]) : groups = Live(groups);
  final Live<Group> groups;

  @override
  Stream<List<Group>> watchForDay({
    required String hospitalId,
    required String date,
  }) => groups.watch(
    (l) => [
      for (final g in l)
        if (g.hospitalId == hospitalId && g.date == date) g,
    ],
  );

  @override
  Stream<Group?> watch(String id) => groups.watch((l) {
    for (final g in l) {
      if (g.id == id) return g;
    }
    return null;
  });
}

class FakeOfferRepo implements OfferRepo {
  FakeOfferRepo([List<Offer>? offers]) : offers = Live(offers);
  final Live<Offer> offers;

  @override
  Stream<List<Offer>> watchOpenForCaregiver(String uid) => offers.watch(
    (l) => [
      for (final o in l)
        if (o.caregiverId == uid && o.status == OfferStatus.offered) o,
    ],
  );
}

class FakeDeliveryRepo implements DeliveryRepo {
  FakeDeliveryRepo([List<MedDelivery>? deliveries])
    : deliveries = Live(deliveries);
  final Live<MedDelivery> deliveries;
  final List<(String, Rating)> ratings = [];

  void put(MedDelivery d) => deliveries.upsert(d, (x) => x.id == d.id);

  @override
  Stream<List<MedDelivery>> watchForFamily(String fid) => deliveries.watch(
    (l) => [
      for (final d in l)
        if (d.familyId == fid) d,
    ],
  );

  @override
  Stream<MedDelivery?> watch(String id) => deliveries.watch((l) {
    for (final d in l) {
      if (d.id == id) return d;
    }
    return null;
  });

  @override
  Stream<List<MedDelivery>> watchForCaregiver(String uid) => deliveries.watch(
    (l) => [
      for (final d in l)
        if (d.caregiverId == uid) d,
    ],
  );

  @override
  Future<void> rate(String id, Rating rating) async {
    ratings.add((id, rating));
    final d = deliveries.items.firstWhere((d) => d.id == id);
    put(MedDelivery.fromMap(id, {...d.toMap(), 'rating': rating.toMap()}));
  }
}

class FakeNotificationRepo implements NotificationRepo {
  FakeNotificationRepo([List<AppNotification>? items]) : items = Live(items);
  final Live<AppNotification> items;
  final List<String> marked = [];

  @override
  Stream<List<AppNotification>> watch(String uid) => items.watch((l) => [...l]);

  @override
  Future<void> markRead(String uid, String nid) async {
    marked.add(nid);
    final n = items.items.firstWhere((n) => n.id == nid);
    items.upsert(
      AppNotification.fromMap(nid, {...n.toMap(), 'read': true}),
      (x) => x.id == nid,
    );
  }
}

class FakeReceiptRepo implements ReceiptRepo {
  FakeReceiptRepo([List<Receipt>? items]) : items = Live(items);
  final Live<Receipt> items;

  @override
  Stream<List<Receipt>> watch(String uid) => items.watch(
    (l) => [
      for (final r in l)
        if (r.uid == uid) r,
    ],
  );
}

class FakeAdminRepo implements AdminRepo {
  final bookings = Live<Booking>();
  final deliveries = Live<MedDelivery>();
  final visits = Live<Booking>();

  @override
  Stream<List<Booking>> watchBookings() => bookings.watch((l) => [...l]);

  @override
  Stream<List<MedDelivery>> watchDeliveries() => deliveries.watch((l) => [...l]);

  @override
  Stream<List<Booking>> watchTodayVisits() => visits.watch((l) => [...l]);
}

/// All fakes bundled, with provider overrides for a ProviderScope.
class Fakes {
  Fakes({
    String? uid,
    List<AppUser>? users,
    List<Family>? families,
    Map<String, List<Patient>>? patients,
    List<Booking>? bookings,
    List<Group>? groups,
    List<Offer>? offers,
    List<MedDelivery>? deliveries,
    List<AppNotification>? notifications,
    List<Receipt>? receipts,
    List<CaregiverProfile>? caregivers,
    Map<String, String> passwords = const {},
  }) : auth = FakeAuthRepo(uid: uid, passwords: passwords),
       user = FakeUserRepo(users),
       family = FakeFamilyRepo(families: families, patients: patients),
       booking = FakeBookingRepo(bookings),
       group = FakeGroupRepo(groups),
       offer = FakeOfferRepo(offers),
       delivery = FakeDeliveryRepo(deliveries),
       notification = FakeNotificationRepo(notifications),
       receipt = FakeReceiptRepo(receipts),
       caregiver = FakeCaregiverRepo(caregivers) {
    family.onFamilyCreated = (uid, fid) => user.update(uid, {'familyId': fid});
  }

  final FakeAuthRepo auth;
  final FakeUserRepo user;
  final FakeFamilyRepo family;
  final FakeBookingRepo booking;
  final FakeGroupRepo group;
  final FakeOfferRepo offer;
  final FakeDeliveryRepo delivery;
  final FakeNotificationRepo notification;
  final FakeReceiptRepo receipt;
  final FakeCaregiverRepo caregiver;
  final admin = FakeAdminRepo();

  List<Override> get overrides => [
    authRepoProvider.overrideWithValue(auth),
    pushServiceProvider.overrideWithValue(null),
    userRepoProvider.overrideWithValue(user),
    familyRepoProvider.overrideWithValue(family),
    bookingRepoProvider.overrideWithValue(booking),
    groupRepoProvider.overrideWithValue(group),
    offerRepoProvider.overrideWithValue(offer),
    deliveryRepoProvider.overrideWithValue(delivery),
    notificationRepoProvider.overrideWithValue(notification),
    receiptRepoProvider.overrideWithValue(receipt),
    caregiverRepoProvider.overrideWithValue(caregiver),
    adminRepoProvider.overrideWithValue(admin),
  ];
}
