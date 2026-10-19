import 'dart:async';

import 'package:careway/data/api.dart';

/// Records calls; each method can be overridden with a handler or an error.
class FakeApi implements CareWayApi {
  final calls = <(String, Object?)>[];
  Object? nextError;
  Completer<void>? payGate;

  BookingRequestResult requestResult = const BookingRequestResult(
    bookingId: 'b-new',
    status: 'pending_caregiver',
  );
  String deliveryId = 'd-new';

  Never _throw() {
    final e = nextError!;
    nextError = null;
    throw e;
  }

  @override
  Future<BookingRequestResult> requestBooking(
    Map<String, dynamic> input,
  ) async {
    calls.add(('requestBooking', input));
    if (nextError != null) _throw();
    return requestResult;
  }

  @override
  Future<String> respondToOffer(String offerId, bool accept) async {
    calls.add(('respondToOffer', {'offerId': offerId, 'accept': accept}));
    if (nextError != null) _throw();
    return accept ? 'accepted' : 'declined';
  }

  @override
  Future<String> autoAcceptBooking(String bookingId) async {
    calls.add(('autoAcceptBooking', bookingId));
    if (nextError != null) _throw();
    return 'accepted';
  }

  @override
  Future<int> payBooking(Map<String, dynamic> input) async {
    calls.add(('payBooking', input));
    if (payGate != null) await payGate!.future;
    if (nextError != null) _throw();
    return 0;
  }

  @override
  Future<CancelResult> cancelBooking(String bookingId) async {
    calls.add(('cancelBooking', bookingId));
    if (nextError != null) _throw();
    return const CancelResult(refundSen: 0, creditSen: 0);
  }

  @override
  Future<String> advanceStep(String bookingId) async {
    calls.add(('advanceStep', bookingId));
    if (nextError != null) _throw();
    return 'picked_up';
  }

  @override
  Future<void> requestRideHome(String bookingId) async {
    calls.add(('requestRideHome', bookingId));
    if (nextError != null) _throw();
  }

  @override
  Future<void> submitSummary(
    String bookingId,
    Map<String, dynamic> summary,
  ) async {
    calls.add(('submitSummary', {'bookingId': bookingId, ...summary}));
    if (nextError != null) _throw();
  }

  @override
  Future<String> requestDelivery(Map<String, dynamic> input) async {
    calls.add(('requestDelivery', input));
    if (nextError != null) _throw();
    return deliveryId;
  }

  @override
  Future<void> payDelivery(String deliveryId, String method) async {
    calls.add(('payDelivery', {'deliveryId': deliveryId, 'method': method}));
    if (nextError != null) _throw();
  }

  @override
  Future<void> seedDemo() async {
    calls.add(('seedDemo', null));
  }

  @override
  Future<void> adminReset() async {
    calls.add(('adminReset', null));
    if (nextError != null) _throw();
  }

  @override
  Future<void> claimPushToken(String token) async {
    calls.add(('claimPushToken', token));
    if (nextError != null) _throw();
  }

  @override
  Future<String> adminRespondOffer(String col, String id, bool accept) async {
    calls.add(('adminRespondOffer', {'col': col, 'id': id, 'accept': accept}));
    if (nextError != null) _throw();
    return accept ? 'accepted' : 'declined';
  }

  @override
  Future<void> adminNotFound(String col, String id) async {
    calls.add(('adminNotFound', {'col': col, 'id': id}));
    if (nextError != null) _throw();
  }

  @override
  Future<String> adminLockGroup(String groupId) async {
    calls.add(('adminLockGroup', groupId));
    if (nextError != null) _throw();
    return 'locked';
  }

  @override
  Future<void> adminAdvanceDelivery(String id, {bool toEnd = false}) async {
    calls.add(('adminAdvanceDelivery', {'id': id, 'toEnd': toEnd}));
    if (nextError != null) _throw();
  }

  @override
  Future<void> adminAdvanceStep(String bookingId) async {
    calls.add(('adminAdvanceStep', bookingId));
    if (nextError != null) _throw();
  }

  @override
  Future<void> releasePushToken(String token) async {
    calls.add(('releasePushToken', token));
    if (nextError != null) _throw();
  }

  List<Object?> argsOf(String name) => [
    for (final (n, a) in calls)
      if (n == name) a,
  ];
}
