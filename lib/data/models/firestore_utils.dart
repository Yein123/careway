import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? readDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate().toUtc();
  if (v is DateTime) return v.toUtc();
  if (v is String) return DateTime.parse(v).toUtc();
  throw ArgumentError.value(v, 'date');
}

Timestamp? writeDate(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

List<String> readStrings(dynamic v) => v == null ? const [] : List<String>.from(v as List);

Map<String, dynamic> readMap(dynamic v) => v == null ? const {} : Map<String, dynamic>.from(v as Map);

List<Map<String, dynamic>> readMaps(dynamic v) =>
    v == null ? const [] : [for (final e in v as List) Map<String, dynamic>.from(e as Map)];

T readEnum<T extends Enum>(List<T> values, dynamic v, T fallback) {
  for (final e in values) {
    if (e.name == v) return e;
  }
  return fallback;
}

T? readEnumOrNull<T extends Enum>(List<T> values, dynamic v) {
  for (final e in values) {
    if (e.name == v) return e;
  }
  return null;
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  // Malay names: "Zainab binti Ahmad" -> ZA (skip bin/binti/a/l/a/p).
  const skip = {'bin', 'binti', 'a/l', 'a/p', 'b.', 'bt.'};
  final words = parts.where((p) => !skip.contains(p.toLowerCase())).toList();
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return (words.first[0] + words.last[0]).toUpperCase();
}
