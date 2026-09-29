import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/core/widgets/activity_tile.dart';
import 'package:sporttracker/core/widgets/points_chip.dart';

import '../app_harness.dart';

/// Mia Halvorsen's seeded points, from the five entries in SeedData:
/// Running 5.2 km (2), Gym 60 min (3), Yoga 40 min (1), Team sport 90 min (4),
/// Running 10.4 km (4).
const int miaSeasonPoints = 14;

void main() {
  group('Dashboard', () {
    testWidgets('shows season points and points this week', (tester) async {
      await pumpApp(tester);
      await signIn(tester, 'Mia Halvorsen');

      expect(find.text(AppStrings.dashboardSeasonPoints), findsOneWidget);
      expect(find.text(AppStrings.dashboardWeekPoints), findsOneWidget);
      expect(find.text('$miaSeasonPoints'), findsOneWidget);
    });

    testWidgets('greets the player and names the season', (tester) async {
      await pumpApp(tester);
      await signIn(tester, 'Mia Halvorsen');

      expect(find.text('Hi Mia Halvorsen'), findsOneWidget);
      expect(find.textContaining('Autumn 2026'), findsOneWidget);
    });

    testWidgets('lists at most five recent activities', (tester) async {
      await pumpApp(tester);
      await signIn(tester, 'Mia Halvorsen');

      expect(find.text(AppStrings.dashboardRecentActivities), findsOneWidget);
      expect(find.byType(ActivityTile), findsNWidgets(5));
    });

    testWidgets('falls back to the empty state once nothing is left',
        (tester) async {
      await pumpApp(tester);
      // Ines Duarte has the fewest seeded activities: yoga 1 pt, team sport 4.
      await signIn(tester, 'Ines Duarte');
      expect(find.text('5'), findsOneWidget);

      await tester.tap(find.text(AppStrings.navActivities));
      await settle(tester);

      for (var i = 0; i < 2; i++) {
        await tester.drag(
          find.byType(ActivityTile).first,
          const Offset(-500, 0),
        );
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, AppStrings.delete));
        await settle(tester);
      }

      expect(find.text(AppStrings.activitiesEmptyTitle), findsOneWidget);

      await tester.tap(find.text(AppStrings.navDashboard));
      await settle(tester);

      expect(find.text('0'), findsNWidgets(2));
      expect(find.text(AppStrings.dashboardNoActivitiesTitle), findsOneWidget);
    });
  });

  group('My activities', () {
    testWidgets('lists the activities of the signed-in player only',
        (tester) async {
      final repositories = await pumpApp(tester);
      await signIn(tester, 'Mia Halvorsen');

      await tester.tap(find.text(AppStrings.navActivities));
      await settle(tester);

      final mine = await repositories.activities.getForPlayer(
        playerId: 'player_1',
        seasonId: 'season_1',
      );
      expect(mine, hasLength(5));
      expect(find.byType(ActivityTile), findsNWidgets(5));
      expect(
        find.text('$miaSeasonPoints ${AppStrings.pointsShort}'),
        findsOneWidget,
      );
    });

    testWidgets('swiping a row asks before it deletes', (tester) async {
      await pumpApp(tester);
      await signIn(tester, 'Mia Halvorsen');
      await tester.tap(find.text(AppStrings.navActivities));
      await settle(tester);

      await tester.drag(find.byType(ActivityTile).first, const Offset(-500, 0));
      await settle(tester);

      expect(find.text(AppStrings.activitiesDeleteTitle), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, AppStrings.cancel));
      await settle(tester);

      expect(find.byType(ActivityTile), findsNWidgets(5));
    });

    testWidgets('confirming the swipe deletes the activity and its points',
        (tester) async {
      final repositories = await pumpApp(tester);
      await signIn(tester, 'Mia Halvorsen');
      await tester.tap(find.text(AppStrings.navActivities));
      await settle(tester);

      await tester.drag(find.byType(ActivityTile).first, const Offset(-500, 0));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.delete));
      await settle(tester);

      final left = await repositories.activities.getForPlayer(
        playerId: 'player_1',
        seasonId: 'season_1',
      );
      expect(left, hasLength(4));

      // The newest entry was Running 5.2 km, worth 2 points.
      expect(
        find.text('${miaSeasonPoints - 2} ${AppStrings.pointsShort}'),
        findsOneWidget,
      );
    });
  });

  group('Leaderboard', () {
    testWidgets('ranks the whole roster', (tester) async {
      await pumpApp(tester);
      await signIn(tester, 'Mia Halvorsen');

      await tester.tap(find.text(AppStrings.navLeaderboard));
      await settle(tester);

      expect(find.text('1'), findsOneWidget);
      expect(find.text(AppStrings.leaderboardYou), findsOneWidget);
      expect(find.text(AppStrings.leaderboardCaptain), findsOneWidget);
      expect(find.byType(PointsChip), findsWidgets);
    });

    testWidgets('the top player is first', (tester) async {
      await pumpApp(tester);
      await signIn(tester, 'Mia Halvorsen');
      await tester.tap(find.text(AppStrings.navLeaderboard));
      await settle(tester);

      final names = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => ((tile.title! as Row).children.first as Flexible))
          .map((flexible) => (flexible.child as Text).data)
          .toList();

      // Priya Nair scores 6 + 2 + 1 + 3 = 12 and Mia scores 14, so Mia leads.
      expect(names.first, 'Mia Halvorsen');
    });
  });

  group('Log activity', () {
    testWidgets('opens with the first rule and its live preview',
        (tester) async {
      await pumpApp(tester);
      await signIn(tester, 'Mia Halvorsen');

      await tester.tap(find.text(AppStrings.navLog));
      await settle(tester);

      expect(find.text(AppStrings.logRule), findsOneWidget);
      // Gym session needs 45 minutes and nothing is typed yet.
      expect(find.text('Enter how long the activity was.'), findsOneWidget);
    });

    testWidgets('shows the points once the duration is long enough',
        (tester) async {
      await pumpApp(tester);
      await signIn(tester, 'Mia Halvorsen');
      await tester.tap(find.text(AppStrings.navLog));
      await settle(tester);

      await tester.enterText(find.byType(TextField).first, '30');
      await settle(tester);
      expect(
        find.text('This activity must last at least 45 min to score.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).first, '60');
      await settle(tester);
      expect(find.text('You will earn 3 points'), findsOneWidget);
    });

    testWidgets('logging adds the activity and its points', (tester) async {
      final repositories = await pumpApp(tester);
      await signIn(tester, 'Ines Duarte');
      await tester.tap(find.text(AppStrings.navLog));
      await settle(tester);

      await tester.enterText(find.byType(TextField).first, '60');
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.logSubmit));
      await settle(tester);

      final mine = await repositories.activities.getForPlayer(
        playerId: 'player_7',
        seasonId: 'season_1',
      );
      expect(mine, hasLength(3));
      expect(mine.last.ruleName, 'Gym session');
      expect(mine.last.points, 3);
    });

    testWidgets('the submit button is off while the input does not score',
        (tester) async {
      await pumpApp(tester);
      await signIn(tester, 'Mia Halvorsen');
      await tester.tap(find.text(AppStrings.navLog));
      await settle(tester);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, AppStrings.logSubmit),
      );
      expect(button.onPressed, isNull);
    });
  });
}
