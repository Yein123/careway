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

  test("today's appointment slots start after now", () {
    final n = DateTime(2026, 10, 17, 14);
    final today = DateTime(2026, 10, 17);
    final l2 = availableSlots(today, n, level: 2);
    expect(l2, isNot(contains(13 * 60 + 30)));
    expect(l2, isNot(contains(14 * 60)));
    expect(l2, contains(15 * 60));
    // Level 1 also needs the earliest new-group pickup (an hour before) to be ahead.
    final l1 = availableSlots(today, n, level: 1);
    expect(l1, isNot(contains(14 * 60 + 45)));
    expect(l1, contains(15 * 60 + 15));
    expect(availableSlots(DateTime(2026, 10, 18), n), appointmentSlots);
  });

  test('today is not bookable once no slot remains', () {
    final n = DateTime(2026, 10, 17, 17);
    expect(dayBookable(DateTime(2026, 10, 17), n), isFalse);
    expect(dayBookable(DateTime(2026, 10, 17), n, level: 2), isFalse);
    expect(dayBookable(DateTime(2026, 10, 18), n), isTrue);
    // 4:00 PM: Level 2 still has 4:15 and 4:30, Level 1 has none.
    final late = DateTime(2026, 10, 17, 16);
    expect(dayBookable(DateTime(2026, 10, 17), late, level: 2), isTrue);
    expect(dayBookable(DateTime(2026, 10, 17), late), isFalse);
  });

  test('afterLock is false for a same-day group booking without lockAt', () {
    final b = booking(noLock: true, groupId: 'g1');
    expect(afterLock(b, b.apptAt.subtract(const Duration(hours: 1))), isFalse);
  });
}
