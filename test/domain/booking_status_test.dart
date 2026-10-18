import 'package:careway/domain/booking_status.dart';
import 'package:careway/features/booking/booking_common.dart';
import 'package:careway/features/booking/booking_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';

void main() {
  sameDayTests();
  test('wire strings are snake_case and round-trip', () {
    expect(
      BookingStatus.fromWire('pending_caregiver'),
      BookingStatus.pendingCaregiver,
    );
    expect(BookingStatus.awaitingPayment.wire, 'awaiting_payment');
    for (final s in BookingStatus.values) {
      expect(BookingStatus.fromWire(s.wire), s);
    }
  });

  test('allowed transitions', () {
    const B = BookingStatus.values;
    final allowed = [
      (BookingStatus.draft, BookingStatus.pendingCaregiver),
      (BookingStatus.pendingCaregiver, BookingStatus.awaitingPayment),
      (BookingStatus.pendingCaregiver, BookingStatus.notMatched),
      (BookingStatus.awaitingPayment, BookingStatus.confirmed),
      (BookingStatus.awaitingPayment, BookingStatus.expired),
      (BookingStatus.confirmed, BookingStatus.inProgress),
      (BookingStatus.inProgress, BookingStatus.completed),
      (BookingStatus.notMatched, BookingStatus.pendingCaregiver),
      (BookingStatus.draft, BookingStatus.cancelled),
      (BookingStatus.pendingCaregiver, BookingStatus.cancelled),
      (BookingStatus.awaitingPayment, BookingStatus.cancelled),
      (BookingStatus.confirmed, BookingStatus.cancelled),
    ];
    for (final (from, to) in allowed) {
      expect(canTransition(from, to), isTrue, reason: '$from -> $to');
    }
    expect(B, isNotEmpty);
  });

  test('disallowed transitions', () {
    for (final to in BookingStatus.values) {
      expect(canTransition(BookingStatus.completed, to), isFalse);
    }
    expect(
      canTransition(BookingStatus.inProgress, BookingStatus.cancelled),
      isFalse,
    );
    expect(
      canTransition(BookingStatus.draft, BookingStatus.confirmed),
      isFalse,
    );
  });

  test('terminal states', () {
    expect(BookingStatus.completed.isTerminal, isTrue);
    expect(BookingStatus.cancelled.isTerminal, isTrue);
    expect(BookingStatus.expired.isTerminal, isTrue);
    expect(BookingStatus.confirmed.isTerminal, isFalse);
  });
}

void sameDayTests() {
  test('dayBookable allows today and refuses yesterday', () {
    final n = DateTime(2026, 10, 17, 15);
    expect(dayBookable(DateTime(2026, 10, 17), n), isTrue);
    expect(dayBookable(DateTime(2026, 10, 18), n), isTrue);
    expect(dayBookable(DateTime(2026, 10, 16), n), isFalse);
  });

  test('afterLock is false for a same-day group booking without lockAt', () {
    final b = booking(noLock: true, groupId: 'g1');
    expect(afterLock(b, b.apptAt.subtract(const Duration(hours: 1))), isFalse);
  });
}
