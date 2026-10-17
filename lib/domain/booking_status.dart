/// Booking lifecycle (spec §4). Payment only happens after a caregiver accepts.
enum BookingStatus {
  draft('draft'),
  pendingCaregiver('pending_caregiver'),
  awaitingPayment('awaiting_payment'),
  confirmed('confirmed'),
  inProgress('in_progress'),
  completed('completed'),
  notMatched('not_matched'),
  cancelled('cancelled'),
  expired('expired');

  const BookingStatus(this.wire);
  final String wire;

  static BookingStatus fromWire(String s) => values.firstWhere(
    (v) => v.wire == s,
    orElse: () => throw ArgumentError.value(s, 'status'),
  );

  bool get isTerminal =>
      this == completed || this == cancelled || this == expired;
}

const _transitions = {
  BookingStatus.draft: {
    BookingStatus.pendingCaregiver,
    BookingStatus.cancelled,
  },
  BookingStatus.pendingCaregiver: {
    BookingStatus.awaitingPayment,
    BookingStatus.notMatched,
    BookingStatus.cancelled,
  },
  BookingStatus.awaitingPayment: {
    BookingStatus.confirmed,
    BookingStatus.expired,
    BookingStatus.cancelled,
  },
  BookingStatus.confirmed: {BookingStatus.inProgress, BookingStatus.cancelled},
  BookingStatus.inProgress: {BookingStatus.completed},
  BookingStatus.notMatched: {
    BookingStatus.pendingCaregiver,
    BookingStatus.cancelled,
  },
};

bool canTransition(BookingStatus from, BookingStatus to) =>
    _transitions[from]?.contains(to) ?? false;
