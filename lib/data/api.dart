import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A business-rule failure from a callable, e.g. code 'seat-taken'.
class CareWayException implements Exception {
  const CareWayException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Friendly copy for callable failure codes.
String friendlyError(Object e) {
  if (e is CareWayException) {
    return switch (e.code) {
      'seat-taken' => 'The last seat was just taken.',
      'group-full' => 'This group is full.',
      'offer-expired' => 'This request expired.',
      'off-duty' => 'Go on duty to accept requests.',
      'too-soon' => 'That time has already passed.',
      'level1-not-allowed' => 'This patient needs a Level 2 escort.',
      'no-patient' => 'Add who is going first.',
      'not-payable' => 'This booking is no longer waiting for payment.',
      'addon-unavailable' => e.message,
      'summary-required' => 'Write the visit summary before finishing.',
      'docs-missing' => 'Tick all 3 documents to continue.',
      'not-cancellable' => 'This visit has already started.',
      'unavailable' || 'deadline-exceeded' =>
        'No connection. Check your internet and try again.',
      _ =>
        e.message.isEmpty
            ? 'Something went wrong. Please try again.'
            : e.message,
    };
  }
  return 'Something went wrong. Please try again.';
}

class BookingRequestResult {
  const BookingRequestResult({required this.bookingId, required this.status});
  final String bookingId;
  final String status;
}

class CancelResult {
  const CancelResult({required this.refundSen, required this.creditSen});
  final int refundSen;
  final int creditSen;
}

/// Typed wrappers around the Cloud Functions callables.
abstract class CareWayApi {
  Future<BookingRequestResult> requestBooking(Map<String, dynamic> input);
  Future<String> respondToOffer(String offerId, bool accept);

  /// Returns the amount paid in sen.
  Future<int> payBooking(Map<String, dynamic> input);
  Future<CancelResult> cancelBooking(String bookingId);
  Future<String> advanceStep(String bookingId);
  Future<void> requestRideHome(String bookingId);
  Future<void> submitSummary(String bookingId, Map<String, dynamic> summary);
  Future<String> requestDelivery(Map<String, dynamic> input);
  Future<void> payDelivery(String deliveryId, String method);
  Future<void> seedDemo();

  // Demo admin controls.
  Future<void> adminReset();
  Future<String> adminRespondOffer(String col, String id, bool accept);
  Future<void> adminNotFound(String col, String id);

  /// Returns the group status: 'locked' or 'cancelled'.
  Future<String> adminLockGroup(String groupId);
  Future<void> adminAdvanceDelivery(String id, {bool toEnd = false});
  Future<void> adminAdvanceStep(String bookingId);

  // Push tokens (Android).
  Future<void> claimPushToken(String token);
  Future<void> releasePushToken(String token);
}

class FunctionsCareWayApi implements CareWayApi {
  FunctionsCareWayApi(this._functions);
  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> _call(String name, Object? data) async {
    try {
      final r = await _functions.httpsCallable(name).call<Object?>(data);
      final d = r.data;
      return d is Map ? Map<String, dynamic>.from(d) : const {};
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final code = details is Map && details['code'] is String
          ? details['code'] as String
          : e.code;
      throw CareWayException(code, e.message ?? '');
    }
  }

  @override
  Future<BookingRequestResult> requestBooking(
    Map<String, dynamic> input,
  ) async {
    final r = await _call('requestBooking', input);
    return BookingRequestResult(
      bookingId: r['bookingId'] as String,
      status: r['status'] as String,
    );
  }

  @override
  Future<String> respondToOffer(String offerId, bool accept) async =>
      (await _call('respondToOffer', {
            'offerId': offerId,
            'accept': accept,
          }))['status']
          as String;

  @override
  Future<int> payBooking(Map<String, dynamic> input) async =>
      ((await _call('payBooking', input))['paidSen'] as num).toInt();

  @override
  Future<CancelResult> cancelBooking(String bookingId) async {
    final r = await _call('cancelBooking', {'bookingId': bookingId});
    return CancelResult(
      refundSen: (r['refundSen'] as num).toInt(),
      creditSen: (r['creditSen'] as num).toInt(),
    );
  }

  @override
  Future<String> advanceStep(String bookingId) async =>
      (await _call('advanceStep', {'bookingId': bookingId}))['step'] as String;

  @override
  Future<void> requestRideHome(String bookingId) =>
      _call('requestRideHome', {'bookingId': bookingId});

  @override
  Future<void> submitSummary(String bookingId, Map<String, dynamic> summary) =>
      _call('submitSummary', {'bookingId': bookingId, 'summary': summary});

  @override
  Future<String> requestDelivery(Map<String, dynamic> input) async =>
      (await _call('requestDelivery', input))['deliveryId'] as String;

  @override
  Future<void> payDelivery(String deliveryId, String method) =>
      _call('payDelivery', {'deliveryId': deliveryId, 'method': method});

  @override
  Future<void> seedDemo() => _call('seedDemo', null);

  @override
  Future<void> adminReset() => _call('adminReset', {});

  @override
  Future<String> adminRespondOffer(String col, String id, bool accept) async =>
      (await _call('adminRespondOffer', {
            'col': col,
            'id': id,
            'accept': accept,
          }))['status']
          as String;

  @override
  Future<void> adminNotFound(String col, String id) =>
      _call('adminNotFound', {'col': col, 'id': id});

  @override
  Future<String> adminLockGroup(String groupId) async =>
      (await _call('adminLockGroup', {'groupId': groupId}))['status']
          as String;

  @override
  Future<void> adminAdvanceDelivery(String id, {bool toEnd = false}) =>
      _call('adminAdvanceDelivery', {'id': id, 'toEnd': toEnd});

  @override
  Future<void> adminAdvanceStep(String bookingId) =>
      _call('adminAdvanceStep', {'bookingId': bookingId});

  @override
  Future<void> claimPushToken(String token) =>
      _call('claimPushToken', {'token': token});

  @override
  Future<void> releasePushToken(String token) =>
      _call('releasePushToken', {'token': token});
}

final careWayApiProvider = Provider<CareWayApi>(
  (ref) => FunctionsCareWayApi(
    FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
  ),
);
