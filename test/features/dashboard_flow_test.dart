import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/core/widgets/activity_tile.dart';
import 'package:sporttracker/core/widgets/points_chip.dart';
import 'package:sporttracker/domain/models/activity.dart';
import 'package:sporttracker/domain/models/season.dart';

import '../app_harness.dart';
import '../fixtures.dart';

/// The big number out of the stat tile captioned [label].
String _statValue(WidgetTester tester, String label) {
  final tile = tester.widget<StatTile>(
    find.byWidgetPredicate(
      (widget) => widget is StatTile && widget.label == label,
    ),
  );
  return tile.value;
}

/// Mira's activities without the ones whose ids are in [ids].
List<Activity> _miraWithout(Set<String> ids) => [
      for (final activity in Fixture.miraActivities)
        if (!ids.contains(activity.id)) activity,
    ];

void main() {
  group('Dashboard totals', () {
    testWidgets('season points is the sum of every activity in the season',
        (tester) async {
      final world = await pumpWorld(tester);
      await signIn(tester, Fixture.mira.name);

      // 3 + 3 + 3 + 2 + 4 + 2, over the whole season.
      expect(await world.pointsOf(Fixture.mira.id), Fixture.miraSeasonPoints);
      expect(
        _statValue(tester, AppStrings.dashboardSeasonPoints),
        '${Fixture.miraSeasonPoints}',
      );
    });

    testWidgets('a player who has logged nothing sees zero', (tester) async {
      await pumpWorld(tester);
      await signIn(tester, Fixture.dana.name);

      expect(_statValue(tester, AppStrings.dashboardSeasonPoints), '0');
      expect(_statValue(tester, AppStrings.dashboardWeekPoints), '0');
      expect(find.text(AppStrings.dashboardNoActivitiesTitle), findsOneWidget);
    });
  });

  group('Points this week runs Monday to Sunday', () {
    // "Now" is Sunday 11 Oct 2026 23:59, so the week is Mon 5 Oct 00:00 to
    // Sun 11 Oct 23:59. Mira has one activity on each boundary and one on
    // each side of it.

    testWidgets('counts both boundary days and nothing outside them',
        (tester) async {
      await pumpWorld(tester);
      await signIn(tester, Fixture.mira.name);

      // Mon 5 Oct 00:00 (3) + Wed 7 Oct (3) + Sun 11 Oct 23:59 (3).
      expect(
        _statValue(tester, AppStrings.dashboardWeekPoints),
        '${Fixture.miraWeekPoints}',
      );
      // The other 8 points are outside the week but still in the season.
      expect(
        _statValue(tester, AppStrings.dashboardSeasonPoints),
        '${Fixture.miraSeasonPoints}',
      );
    });

    testWidgets('the activity on Monday 00:00 is inside the week',
        (tester) async {
      await pumpWorld(tester, activities: _miraWithout({'activity_1'}));
      await signIn(tester, Fixture.mira.name);

      // Dropping the Monday 00:00 entry costs exactly its 3 points.
      expect(_statValue(tester, AppStrings.dashboardWeekPoints), '6');
    });

    testWidgets('the activity on Sunday 23:59 is inside the week',
        (tester) async {
      await pumpWorld(tester, activities: _miraWithout({'activity_2'}));
      await signIn(tester, Fixture.mira.name);

      // Dropping the Sunday 23:59 entry costs exactly its 3 points.
      expect(_statValue(tester, AppStrings.dashboardWeekPoints), '6');
    });

    testWidgets('the Sunday before and the Monday before are outside it',
        (tester) async {
      // Only the two entries that sit just outside the week: Sun 4 Oct 23:59
      // worth 2 and Mon 28 Sep worth 4.
      await pumpWorld(
        tester,
        activities: _miraWithout({
          'activity_1',
          'activity_2',
          'activity_3',
          'activity_6',
        }),
      );
      await signIn(tester, Fixture.mira.name);

      expect(_statValue(tester, AppStrings.dashboardWeekPoints), '0');
      expect(_statValue(tester, AppStrings.dashboardSeasonPoints), '6');
    });
  });

  group('Recent activities', () {
    testWidgets('shows exactly five, newest first', (tester) async {
      await pumpWorld(tester);
      await signIn(tester, Fixture.mira.name);

      expect(find.text(AppStrings.dashboardRecentActivities), findsOneWidget);

      final tiles =
          tester.widgetList<ActivityTile>(find.byType(ActivityTile)).toList();
      expect(tiles, hasLength(5));
      expect(
        tiles.map((tile) => tile.date).toList(),
        [
          Fixture.weekSunday, // Sun 11 Oct 23:59
          Fixture.weekWednesday, // Wed 7 Oct 12:00
          Fixture.weekMonday, // Mon 5 Oct 00:00
          Fixture.lastWeekSunday, // Sun 4 Oct 23:59
          Fixture.lastWeekMonday, // Mon 28 Sep
        ],
      );

      // Mira has six. The oldest one is the only entry left off the list.
      expect(Fixture.miraActivities, hasLength(6));
      expect(find.text(Fixture.stretching.name), findsNothing);
    });

    testWidgets('fewer than five are all shown', (tester) async {
      await pumpWorld(
        tester,
        activities: _miraWithout({'activity_4', 'activity_5', 'activity_6'}),
      );
      await signIn(tester, Fixture.mira.name);

      expect(find.byType(ActivityTile), findsNWidgets(3));
    });
  });

  group('No active season', () {
    testWidgets('an empty repository shows the no-season state',
        (tester) async {
      await pumpWorld(tester, seasons: const [], activities: const []);
      await signIn(tester, Fixture.mira.name);

      expect(find.text(AppStrings.dashboardNoSeasonTitle), findsOneWidget);
      expect(find.text(AppStrings.dashboardSeasonPoints), findsNothing);
      expect(find.text(AppStrings.dashboardWeekPoints), findsNothing);
    });

    testWidgets('a season still in draft does not count as active',
        (tester) async {
      await pumpWorld(
        tester,
        seasons: [Fixture.season(status: SeasonStatus.draft)],
      );
      await signIn(tester, Fixture.mira.name);

      expect(find.text(AppStrings.dashboardNoSeasonTitle), findsOneWidget);
      expect(find.byType(ActivityTile), findsNothing);
    });
  });
}
