import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/core/widgets/activity_tile.dart';
import 'package:sporttracker/core/widgets/points_chip.dart';
import 'package:sporttracker/domain/models/player.dart';

import '../app_harness.dart';
import '../fixtures.dart';

Finder _rowOf(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(ListTile));

/// The roster in the order the table lists it, top first.
List<String> _orderedNames(WidgetTester tester) {
  final rows = find.byType(ListTile);
  final count = rows.evaluate().length;
  final names = <String>[];

  for (var i = 0; i < count; i++) {
    for (final player in Fixture.players) {
      final hit = find.descendant(
        of: rows.at(i),
        matching: find.text(player.name),
      );
      if (hit.evaluate().isNotEmpty) names.add(player.name);
    }
  }
  return names;
}

int _pointsOf(WidgetTester tester, String name) {
  final chip = tester.widget<PointsChip>(
    find.descendant(of: _rowOf(name), matching: find.byType(PointsChip)),
  );
  return chip.points;
}

int _rankOf(WidgetTester tester, String name) {
  final badge = find.descendant(
    of: _rowOf(name),
    matching: find.byType(CircleAvatar),
  );
  final text = tester.widget<Text>(
    find.descendant(of: badge, matching: find.byType(Text)),
  );
  return int.parse(text.data!);
}

/// Signs [playerName] in and opens the Leaderboard tab.
Future<TestWorld> openLeaderboard(
  WidgetTester tester, {
  String? playerName,
  List<Player> players = Fixture.players,
}) async {
  final world = await pumpWorld(tester, players: players);
  await signIn(tester, playerName ?? Fixture.mira.name);
  await tester.tap(find.text(AppStrings.navLeaderboard));
  await settle(tester);
  return world;
}

void main() {
  group('Ordering', () {
    testWidgets('the table runs from most points to fewest', (tester) async {
      await openLeaderboard(tester);

      expect(_orderedNames(tester), [
        Fixture.ben.name, // 17
        Fixture.mira.name, // 17
        Fixture.cleo.name, // 9
        Fixture.dana.name, // 0
      ]);

      expect(_pointsOf(tester, Fixture.ben.name), Fixture.benSeasonPoints);
      expect(_pointsOf(tester, Fixture.mira.name), Fixture.miraSeasonPoints);
      expect(_pointsOf(tester, Fixture.cleo.name), Fixture.cleoSeasonPoints);
      expect(_pointsOf(tester, Fixture.dana.name), Fixture.danaSeasonPoints);
    });

    testWidgets('a player who has logged nothing is still on the table',
        (tester) async {
      await openLeaderboard(tester);

      expect(find.text(Fixture.dana.name), findsOneWidget);
      expect(_pointsOf(tester, Fixture.dana.name), 0);
      expect(_rankOf(tester, Fixture.dana.name), 4);
    });

    testWidgets('the signed-in player and the captain are tagged',
        (tester) async {
      await openLeaderboard(tester, playerName: Fixture.cleo.name);

      expect(find.text(AppStrings.leaderboardYou), findsOneWidget);
      expect(find.text(AppStrings.leaderboardCaptain), findsOneWidget);
      expect(
        find.descendant(
          of: _rowOf(Fixture.cleo.name),
          matching: find.text(AppStrings.leaderboardYou),
        ),
        findsOneWidget,
      );
      // Mira is the captain of the fixture season.
      expect(
        find.descendant(
          of: _rowOf(Fixture.mira.name),
          matching: find.text(AppStrings.leaderboardCaptain),
        ),
        findsOneWidget,
      );
    });

    testWidgets('nobody has scored yet', (tester) async {
      await pumpWorld(tester, activities: const []);
      await signIn(tester, Fixture.mira.name);
      await tester.tap(find.text(AppStrings.navLeaderboard));
      await settle(tester);

      expect(find.text(AppStrings.leaderboardEmptyTitle), findsOneWidget);
    });
  });

  group('Ties', () {
    testWidgets('players level on points share a rank and the next one skips',
        (tester) async {
      await openLeaderboard(tester);

      // Mira and Ben are both on 17.
      expect(_rankOf(tester, Fixture.ben.name), 1);
      expect(_rankOf(tester, Fixture.mira.name), 1);
      // So second place is not handed out; Cleo is third.
      expect(_rankOf(tester, Fixture.cleo.name), 3);
      expect(_rankOf(tester, Fixture.dana.name), 4);
    });

    testWidgets('a tie is settled by name, not by roster order',
        (tester) async {
      await openLeaderboard(tester);

      // Mira is first on the roster and Ben second, yet Ben is listed first
      // because "Ben Aro" sorts before "Mira Sol".
      expect(Fixture.players.indexOf(Fixture.mira), lessThan(
        Fixture.players.indexOf(Fixture.ben),
      ));
      final names = _orderedNames(tester);
      expect(
        names.indexOf(Fixture.ben.name),
        lessThan(names.indexOf(Fixture.mira.name)),
      );
    });

    testWidgets('the tied order does not depend on how the roster is stored',
        (tester) async {
      // Same points, roster handed over back to front.
      await openLeaderboard(
        tester,
        players: Fixture.players.reversed.toList(),
      );

      expect(_orderedNames(tester), [
        Fixture.ben.name,
        Fixture.mira.name,
        Fixture.cleo.name,
        Fixture.dana.name,
      ]);
      expect(_rankOf(tester, Fixture.ben.name), 1);
      expect(_rankOf(tester, Fixture.mira.name), 1);
    });

    testWidgets('the same world always draws the same table', (tester) async {
      await openLeaderboard(tester);
      final first = _orderedNames(tester);

      // Leaving and coming back must not shuffle the tied pair.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text(AppStrings.navDashboard));
        await settle(tester);
        await tester.tap(find.text(AppStrings.navLeaderboard));
        await settle(tester);
        expect(_orderedNames(tester), first);
      }
    });

    testWidgets('breaking the tie moves the table', (tester) async {
      await openLeaderboard(tester);
      expect(_rankOf(tester, Fixture.mira.name), 1);

      // Drop Mira's newest activity, worth 3, so Ben leads alone.
      await tester.tap(find.text(AppStrings.navActivities));
      await settle(tester);
      await tester.drag(
        find.byType(ActivityTile).first,
        const Offset(-500, 0),
      );
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.delete));
      await settle(tester);

      await tester.tap(find.text(AppStrings.navLeaderboard));
      await settle(tester);

      expect(_orderedNames(tester), [
        Fixture.ben.name, // 17
        Fixture.mira.name, // 14
        Fixture.cleo.name, // 9
        Fixture.dana.name, // 0
      ]);
      expect(_rankOf(tester, Fixture.ben.name), 1);
      expect(_rankOf(tester, Fixture.mira.name), 2);
      expect(_rankOf(tester, Fixture.cleo.name), 3);
    });
  });
}
