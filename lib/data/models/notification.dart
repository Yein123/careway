import 'firestore_utils.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.link,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? link;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromMap(String id, Map<String, dynamic> m) => AppNotification(
        id: id,
        type: m['type'] as String? ?? 'info',
        title: m['title'] as String? ?? '',
        body: m['body'] as String? ?? '',
        link: m['link'] as String?,
        read: m['read'] as bool? ?? false,
        createdAt: readDate(m['createdAt']),
      );

  Map<String, dynamic> toMap() =>
      {'type': type, 'title': title, 'body': body, 'link': link, 'read': read, 'createdAt': writeDate(createdAt)};
}

enum ReceiptKind { payment, refund, credit }

class Receipt {
  const Receipt({
    required this.id,
    required this.uid,
    required this.amountSen,
    required this.kind,
    required this.label,
    this.method = '',
    this.bookingId,
    this.deliveryId,
    this.createdAt,
  });

  final String id;
  final String uid;
  final int amountSen;
  final ReceiptKind kind;
  final String label;
  final String method;
  final String? bookingId;
  final String? deliveryId;
  final DateTime? createdAt;

  factory Receipt.fromMap(String id, Map<String, dynamic> m) => Receipt(
        id: id,
        uid: m['uid'] as String? ?? '',
        amountSen: (m['amountSen'] as num?)?.toInt() ?? 0,
        kind: readEnum(ReceiptKind.values, m['kind'], ReceiptKind.payment),
        label: m['label'] as String? ?? '',
        method: m['method'] as String? ?? '',
        bookingId: m['bookingId'] as String?,
        deliveryId: m['deliveryId'] as String?,
        createdAt: readDate(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'amountSen': amountSen,
        'kind': kind.name,
        'label': label,
        'method': method,
        'bookingId': bookingId,
        'deliveryId': deliveryId,
        'createdAt': writeDate(createdAt),
      };
}
