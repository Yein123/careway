import 'package:intl/intl.dart';

/// 'Mon 26 Oct'
String dayLabel(DateTime d) => DateFormat('EEE d MMM').format(d.toLocal());

/// '9:00 AM'
String timeLabel(DateTime d) => DateFormat('h:mm a').format(d.toLocal());

/// 'Mon 26 Oct, 9:00 AM'
String dayTimeLabel(DateTime d) => '${dayLabel(d)}, ${timeLabel(d)}';

/// 'today', 'yesterday', '3 days ago'
String agoLabel(DateTime d, DateTime now) {
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.toLocal().year, d.toLocal().month, d.toLocal().day)).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  return '$days days ago';
}
