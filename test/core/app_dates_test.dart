import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/format/app_dates.dart';

/// These cover the calendar semantics of the week window and the "Today" /
/// "Yesterday" labels.
///
/// The bug they guard - `Duration(days: n)` being n times 24h of absolute time
/// rather than n calendar days - only diverges inside a DST transition. This
/// host is Europe/Istanbul, a fixed UTC+3 offset with no DST, so the divergent
/// branch itself cannot be executed here; `DateTime` has no injectable zone.
/// What is asserted below is that the arithmetic goes through the calendar
/// fields, which is what makes the DST case correct.
void main() {
  group('AppDates.addDays', () {
    test('rolls back over a month boundary', () {
      expect(
        AppDates.addDays(DateTime(2026, 3, 1), -1),
        DateTime(2026, 2, 28),
      );
    });

    test('rolls forward over a year boundary', () {
      expect(
        AppDates.addDays(DateTime(2026, 12, 31), 1),
        DateTime(2027, 1, 1),
      );
    });

    test('handles a leap day', () {
      expect(
        AppDates.addDays(DateTime(2024, 2, 28), 1),
        DateTime(2024, 2, 29),
      );
    });

    test('strips the time and lands on local midnight', () {
      final result = AppDates.addDays(DateTime(2026, 5, 4, 13, 45), 3);

      expect(result, DateTime(2026, 5, 7));
      expect(result.hour, 0);
      expect(result.minute, 0);
    });

    test('a shift of zero is just the day', () {
      expect(
        AppDates.addDays(DateTime(2026, 5, 4, 23, 59), 0),
        AppDates.dayOf(DateTime(2026, 5, 4)),
      );
    });
  });

  group('AppDates.startOfWeek', () {
    test('a Monday is its own week start', () {
      // 2026-09-28 is a Monday.
      expect(AppDates.startOfWeek(DateTime(2026, 9, 28)), DateTime(2026, 9, 28));
    });

    test('a Sunday belongs to the week that began six days earlier', () {
      // 2026-10-04 is a Sunday.
      expect(AppDates.startOfWeek(DateTime(2026, 10, 4)), DateTime(2026, 9, 28));
    });

    test('the week start is midnight, whatever time of day goes in', () {
      final start = AppDates.startOfWeek(DateTime(2026, 10, 2, 23, 59, 59));

      expect(start, DateTime(2026, 9, 28));
      expect(start.hour, 0);
      expect(start.minute, 0);
    });

    test('a week start can fall in the previous month', () {
      // 2026-10-01 is a Thursday; its Monday is 28 September.
      expect(AppDates.startOfWeek(DateTime(2026, 10, 1)), DateTime(2026, 9, 28));
    });
  });

  group('AppDates.isInCurrentWeek', () {
    // Wednesday 30 September 2026.
    final now = DateTime(2026, 9, 30, 12);

    test('Monday 00:00 is in the week', () {
      expect(AppDates.isInCurrentWeek(DateTime(2026, 9, 28), now: now), isTrue);
    });

    test('Sunday 23:59 is in the week', () {
      expect(
        AppDates.isInCurrentWeek(DateTime(2026, 10, 4, 23, 59), now: now),
        isTrue,
      );
    });

    test('the Sunday before is not in the week', () {
      expect(AppDates.isInCurrentWeek(DateTime(2026, 9, 27), now: now), isFalse);
    });

    test('next Monday is not in the week', () {
      // The Duration-based window put next Monday 00:00 before a weekEnd of
      // next Monday 01:00 in a spring-forward week, counting it as "this week".
      expect(AppDates.isInCurrentWeek(DateTime(2026, 10, 5), now: now), isFalse);
    });
  });

  group('AppDates.relativeDay', () {
    final now = DateTime(2026, 3, 1, 9);

    test('the same day is Today, whatever the time', () {
      expect(AppDates.relativeDay(DateTime(2026, 3, 1, 23, 30), now: now),
          'Today');
    });

    test('the day before is Yesterday, across a month boundary', () {
      // The subtraction-based version truncated to 0 days across a
      // spring-forward midnight and called this "Today".
      expect(
        AppDates.relativeDay(DateTime(2026, 2, 28, 7), now: now),
        'Yesterday',
      );
    });

    test('two days back gets the weekday label', () {
      expect(
        AppDates.relativeDay(DateTime(2026, 2, 27), now: now),
        isNot(anyOf('Today', 'Yesterday')),
      );
    });
  });
}
