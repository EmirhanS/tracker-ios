import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/app.dart';
import 'package:sporttracker/core/clock.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/core/widgets/points_chip.dart';
import 'package:sporttracker/data/in_memory/id_generator.dart';
import 'package:sporttracker/data/in_memory/in_memory_activity_repository.dart';
import 'package:sporttracker/data/in_memory/in_memory_player_repository.dart';
import 'package:sporttracker/data/in_memory/in_memory_challenge_repository.dart';
import 'package:sporttracker/data/providers.dart';

import '../app_harness.dart';
import '../fixtures.dart';

/// A clock a test can wind forward, the way the real one moves on its own.
class _MovableClock {
  _MovableClock(this.now);

  DateTime now;

  DateTime call() => now;
}

/// The big number out of the stat tile captioned [label].
String _statValue(WidgetTester tester, String label) {
  final tile = tester.widget<StatTile>(
    find.byWidgetPredicate(
      (widget) => widget is StatTile && widget.label == label,
    ),
  );
  return tile.value;
}

/// Starts the app on [Fixture]'s world with a clock the test owns.
Future<void> _pumpWithClock(
  WidgetTester tester,
  _MovableClock clock,
) async {
  final players = InMemoryPlayerRepository(Fixture.players);
  final challenges = InMemoryChallengeRepository(challenges: [Fixture.challenge()]);
  final activities = InMemoryActivityRepository(
    activities: Fixture.activities,
    idGenerator: IdGenerator(start: Fixture.activities.length),
    clock: clock.call,
  );

  addTearDown(() {
    players.dispose();
    challenges.dispose();
    activities.dispose();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerRepositoryProvider.overrideWithValue(players),
        challengeRepositoryProvider.overrideWithValue(challenges),
        activityRepositoryProvider.overrideWithValue(activities),
        clockProvider.overrideWithValue(clock.call),
      ],
      child: const SportTrackerApp(),
    ),
  );
  await settle(tester);
  await signIn(tester, Fixture.mira.name);
}

/// Backgrounds the app and brings it straight back.
Future<void> _resume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await settle(tester);
}

/// "This week" is worked out from a plain `Provider`, so it only moves when
/// something it watches moves. Nothing watches the calendar: an app left open
/// over Sunday midnight went on counting the old week until the next log or
/// delete happened to rebuild it, and a player checking their Monday total saw
/// last week's number.
///
/// Mira's fixture week is Mon 5 Oct to Sun 11 Oct and holds 9 points. Nothing
/// of hers falls in the week that starts Mon 12 Oct, so once the day turns over
/// the week tile has to read 0 while the challenge total stays at 17.
void main() {
  group('Midnight while the app is open', () {
    testWidgets('rolls "this week" over on its own', (tester) async {
      // The last minute of the fixture week.
      final clock = _MovableClock(Fixture.weekSunday);
      await _pumpWithClock(tester, clock);

      expect(
        _statValue(tester, AppStrings.dashboardWeekPoints),
        '${Fixture.miraWeekPoints}',
      );

      // A minute later it is Monday, and a new week.
      clock.now = DateTime(2026, 10, 12, 0, 0, 30);
      await tester.pump(const Duration(minutes: 2));
      await settle(tester);

      expect(_statValue(tester, AppStrings.dashboardWeekPoints), '0');
      expect(
        _statValue(tester, AppStrings.dashboardChallengePoints),
        '${Fixture.miraChallengePoints}',
      );
    });

    testWidgets('leaves a pinned clock alone', (tester) async {
      // The existing tests pin "now" and pump for whole seconds. Ticking must
      // not quietly move the date out from under them.
      final clock = _MovableClock(Fixture.weekSunday);
      await _pumpWithClock(tester, clock);

      await tester.pump(const Duration(minutes: 5));
      await settle(tester);

      expect(
        _statValue(tester, AppStrings.dashboardWeekPoints),
        '${Fixture.miraWeekPoints}',
      );
      expect(
        _statValue(tester, AppStrings.dashboardChallengePoints),
        '${Fixture.miraChallengePoints}',
      );
    });
  });

  group('Coming back to a backgrounded app', () {
    testWidgets('picks up the days that passed while it was away',
        (tester) async {
      final clock = _MovableClock(Fixture.weekWednesday);
      await _pumpWithClock(tester, clock);

      expect(
        _statValue(tester, AppStrings.dashboardWeekPoints),
        '${Fixture.miraWeekPoints}',
      );

      // Put away on Wednesday, opened again the following week. No timer can
      // be trusted to have fired across that.
      clock.now = DateTime(2026, 10, 14, 9);
      await _resume(tester);

      expect(_statValue(tester, AppStrings.dashboardWeekPoints), '0');
      expect(
        _statValue(tester, AppStrings.dashboardChallengePoints),
        '${Fixture.miraChallengePoints}',
      );
    });

    testWidgets('a resume inside the same week changes nothing',
        (tester) async {
      final clock = _MovableClock(Fixture.weekWednesday);
      await _pumpWithClock(tester, clock);

      clock.now = DateTime(2026, 10, 8, 9);
      await _resume(tester);

      expect(
        _statValue(tester, AppStrings.dashboardWeekPoints),
        '${Fixture.miraWeekPoints}',
      );
    });
  });
}
