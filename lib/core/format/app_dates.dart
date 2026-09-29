import 'package:intl/intl.dart';

import '../strings/app_strings.dart';

/// Date text used across the screens.
abstract final class AppDates {
  static final DateFormat _dayMonth = DateFormat('d MMM');
  static final DateFormat _dayMonthYear = DateFormat('d MMM yyyy');
  static final DateFormat _weekday = DateFormat('EEE d MMM');

  /// Strips the time so two days can be compared.
  static DateTime dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Strips the time and shifts by [days] calendar days.
  ///
  /// `DateTime` normalises out-of-range fields, so `day - 1` on the 1st rolls
  /// back into the previous month. Going through the fields rather than adding
  /// a [Duration] keeps this exact across a DST change, where two adjacent
  /// local midnights are 23 or 25 hours apart rather than 24.
  static DateTime addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  /// "Today", "Yesterday", or "Tue 22 Sep".
  static String relativeDay(DateTime date, {DateTime? now}) {
    final today = dayOf(now ?? DateTime.now());
    final day = dayOf(date);

    // Compared as calendar days: `today.difference(day).inDays` truncates to 0
    // across a spring-forward boundary and labels yesterday "Today".
    if (day == today) return AppStrings.today;
    if (day == addDays(today, -1)) return AppStrings.yesterday;
    return _weekday.format(day);
  }

  /// "22 Sep" for this year, "22 Sep 2025" otherwise.
  static String shortDate(DateTime date, {DateTime? now}) {
    final year = (now ?? DateTime.now()).year;
    return date.year == year
        ? _dayMonth.format(date)
        : _dayMonthYear.format(date);
  }

  /// "1 Sep 2026".
  static String fullDate(DateTime date) => _dayMonthYear.format(date);

  /// "1 Sep 2026 - 30 Nov 2026".
  static String dateRange(DateTime start, DateTime end) =>
      '${fullDate(start)} – ${fullDate(end)}';

  /// The Monday that starts the week [date] falls in.
  static DateTime startOfWeek(DateTime date) {
    final day = dayOf(date);
    return addDays(day, DateTime.monday - day.weekday);
  }

  /// True when [date] is in the same Monday-to-Sunday week as [now].
  static bool isInCurrentWeek(DateTime date, {DateTime? now}) {
    final weekStart = startOfWeek(now ?? DateTime.now());
    // Next Monday as a calendar day. `weekStart.add(Duration(days: 7))` is 7
    // times 24h of absolute time, so in a spring-forward week it lands on next
    // Monday 01:00 and counts a next-Monday activity as "this week".
    final weekEnd = addDays(weekStart, 7);
    final day = dayOf(date);
    return !day.isBefore(weekStart) && day.isBefore(weekEnd);
  }
}
