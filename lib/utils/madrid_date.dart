import 'package:intl/intl.dart';

class MadridDate {
  static DateTime now() {
    final utc = DateTime.now().toUtc();
    final year = utc.year;
    final start = _lastSundayUtc(year, 3);
    final end = _lastSundayUtc(year, 10);
    final offset = !utc.isBefore(start) && utc.isBefore(end)
        ? const Duration(hours: 2)
        : const Duration(hours: 1);
    return utc.add(offset);
  }

  static String key([DateTime? date]) {
    final value = date ?? now();
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static String display([DateTime? date]) =>
      DateFormat("EEEE d 'de' MMMM, yyyy", 'es_ES').format(date ?? now());

  static DateTime _lastSundayUtc(int year, int month) {
    final last = DateTime.utc(year, month + 1, 0);
    final sunday = last.subtract(Duration(days: last.weekday % 7));
    return DateTime.utc(sunday.year, sunday.month, sunday.day, 1);
  }
}
