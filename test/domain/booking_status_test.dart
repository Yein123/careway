import 'package:careway/domain/booking_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
