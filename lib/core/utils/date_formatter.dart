import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _displayFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _timeFormat = DateFormat('h:mm a');
  static final DateFormat _filenameFormat = DateFormat('yyyy-MM-dd_HH-mm');

  static String formatDisplay(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final docDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (docDate == today) {
      return 'Today, ${_timeFormat.format(dateTime)}';
    } else if (docDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${_timeFormat.format(dateTime)}';
    } else {
      return _displayFormat.format(dateTime);
    }
  }

  static String generateDefaultDocName() {
    final timestamp = _filenameFormat.format(DateTime.now());
    return 'Scan_$timestamp';
  }
}
