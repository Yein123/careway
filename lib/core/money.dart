/// Formats an amount in sen as ringgit, e.g. 2200 -> "RM 22.00". Zero is "Free".
/// Negative amounts (refunds) are shown as "− RM 18.00".
String formatRm(int sen) {
  if (sen == 0) return 'Free';
  final abs = sen.abs();
  final text = 'RM ${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  return sen < 0 ? '− $text' : text;
}
