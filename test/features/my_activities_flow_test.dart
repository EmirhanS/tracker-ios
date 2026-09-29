import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/core/widgets/activity_tile.dart';
import 'package:sporttracker/core/widgets/points_chip.dart';

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

/// The points shown for [name] on the leaderboard.
int _leaderboardPoints(WidgetTester tester, String name) {
  final row = find.ancestor(
    of: find.text(name),
    matching: find.byType(ListTile),
  );
  final chip = tester.widget<PointsChip>(
    find.descendant(of: row, matching: find.byType(PointsChip)),
  );
  return chip.points;
}

/// Signs [playerName] in and opens the My activities tab.
Future<TestWorld> openActivities(
  WidgetTester tester, {
  String? playerName,
}) async {
  final world = await pumpWorld(tester);
  await signIn(tester, playerName ?? Fixture.mira.name);
  await tester.tap(find.text(AppStrings.navActivities));
  await settle(tester);
  return world;
}

/// Swipes the row at [index] left and confirms the dialog.
Future<void> swipeToDelete(WidgetTester tester, {int index = 0}) async {
  await tester.drag(find.byType(ActivityTile).at(index), const Offset(-500, 0));
  await settle(tester);
  await tester.tap(find.widgetWithText(FilledButton, AppStrings.delete));
  await settle(tester);
}

void main() {
  group('My activities lists the signed-in player only', () {
    testWidgets('Mira sees her six and nobody else sees them', (tester) async {
      final world = await openActivities(tester);

      expect(await world.activitiesOf(Fixture.mira.id), hasLength(6));
      expect(find.byType(ActivityTile), findsNWidgets(6));
      expect(
        find.text('${Fixture.miraSeasonPoints} ${AppStrings.pointsShort}'),
        findsOneWidget,
      );
    });

    testWidgets('a player with nothing logged gets the empty state',
        (tester) async {
      await openActivities(tester, playerName: Fixture.dana.name);

      expect(find.text(AppStrings.activitiesEmptyTitle), findsOneWidget);
      expect(find.byType(ActivityTile), findsNothing);
    });
  });

  group('Swipe to delete', () {
    testWidgets('asks first, and cancelling keeps the row', (tester) async {
      final world = await openActivities(tester);

      await tester.drag(
        find.byType(ActivityTile).first,
        const Offset(-500, 0),
      );
      await settle(tester);
      expect(find.text(AppStrings.activitiesDeleteTitle), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, AppStrings.cancel));
      await settle(tester);

      expect(find.byType(ActivityTile), findsNWidgets(6));
      expect(await world.activitiesOf(Fixture.mira.id), hasLength(6));
    });

    testWidgets('confirming removes the activity from the repository',
        (tester) async {
      final world = await openActivities(tester);

      // The newest row is Sunday's gym session, worth 3.
      await swipeToDelete(tester);

      final left = await world.activitiesOf(Fixture.mira.id);
      expect(left, hasLength(5));
      expect(left.map((activity) => activity.id), isNot(contains('activity_2')));
      expect(find.byType(ActivityTile), findsNWidgets(5));
    });

    testWidgets('the dashboard totals drop by exactly that many points',
        (tester) async {
      await openActivities(tester);

      // activity_2: Sunday 11 Oct, gym, 3 points, inside the current week.
      await swipeToDelete(tester);

      await tester.tap(find.text(AppStrings.navDashboard));
      await settle(tester);

      expect(
        _statValue(tester, AppStrings.dashboardSeasonPoints),
        '${Fixture.miraSeasonPoints - 3}',
      );
      expect(
        _statValue(tester, AppStrings.dashboardWeekPoints),
        '${Fixture.miraWeekPoints - 3}',
      );
    });

    testWidgets('deleting an activity outside the week leaves the week alone',
        (tester) async {
      await openActivities(tester);

      // Row 4 is Sunday 4 Oct, worth 2, in the week before this one.
      await swipeToDelete(tester, index: 3);

      await tester.tap(find.text(AppStrings.navDashboard));
      await settle(tester);

      expect(
        _statValue(tester, AppStrings.dashboardSeasonPoints),
        '${Fixture.miraSeasonPoints - 2}',
      );
      expect(
        _statValue(tester, AppStrings.dashboardWeekPoints),
        '${Fixture.miraWeekPoints}',
      );
    });

    testWidgets('the leaderboard total drops by exactly that many points',
        (tester) async {
      await openActivities(tester);

      await tester.tap(find.text(AppStrings.navLeaderboard));
      await settle(tester);
      expect(
        _leaderboardPoints(tester, Fixture.mira.name),
        Fixture.miraSeasonPoints,
      );

      await tester.tap(find.text(AppStrings.navActivities));
      await settle(tester);
      await swipeToDelete(tester);

      await tester.tap(find.text(AppStrings.navLeaderboard));
      await settle(tester);

      expect(
        _leaderboardPoints(tester, Fixture.mira.name),
        Fixture.miraSeasonPoints - 3,
      );
      // Nobody else moved.
      expect(
        _leaderboardPoints(tester, Fixture.ben.name),
        Fixture.benSeasonPoints,
      );
      expect(
        _leaderboardPoints(tester, Fixture.cleo.name),
        Fixture.cleoSeasonPoints,
      );
    });

    testWidgets('deleting the last one falls back to the empty state',
        (tester) async {
      final world = await openActivities(tester, playerName: Fixture.cleo.name);
      expect(find.byType(ActivityTile), findsNWidgets(3));

      for (var i = 0; i < 3; i++) {
        await swipeToDelete(tester);
      }

      expect(await world.activitiesOf(Fixture.cleo.id), isEmpty);
      expect(find.text(AppStrings.activitiesEmptyTitle), findsOneWidget);
    });
  });
}
