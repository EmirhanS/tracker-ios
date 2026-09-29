import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/core/widgets/activity_tile.dart';

import '../app_harness.dart';
import '../fixtures.dart';

/// Mira is in both challenges, so she is the one who can switch.
Future<TestWorld> pumpTwoChallenges(
  WidgetTester tester, {
  String playerName = 'Mira Sol',
}) async {
  final world = await pumpWorld(
    tester,
    challenges: [Fixture.challenge(), Fixture.secondChallenge()],
    activities: Fixture.bothChallengeActivities,
  );
  await signIn(tester, playerName);
  return world;
}

void main() {
  group('The switcher points every tab at one challenge', () {
    testWidgets('it opens on the first running challenge', (tester) async {
      await pumpTwoChallenges(tester);

      expect(find.textContaining('Test Challenge'), findsWidgets);
      expect(find.text('${Fixture.miraChallengePoints}'), findsOneWidget);
    });

    testWidgets('switching changes the dashboard totals', (tester) async {
      await pumpTwoChallenges(tester);
      expect(find.text('${Fixture.miraChallengePoints}'), findsOneWidget);

      await switchToChallenge(tester, Fixture.secondChallengeName);

      expect(find.textContaining(Fixture.secondChallengeName), findsWidgets);
      expect(
        find.text('${Fixture.miraSecondChallengePoints}'),
        findsWidgets,
        reason: 'the challenge total is now the second challenge\'s',
      );
      expect(find.text('${Fixture.miraChallengePoints}'), findsNothing);
    });

    testWidgets('switching changes which activities are listed',
        (tester) async {
      await pumpTwoChallenges(tester);

      await openTab(tester, AppStrings.navActivities);
      expect(find.byType(ActivityTile), findsNWidgets(6));

      await switchToChallenge(tester, Fixture.secondChallengeName);

      // Mira has logged one thing in the second challenge.
      expect(find.byType(ActivityTile), findsOneWidget);
      expect(
        find.text(
          '${Fixture.miraSecondChallengePoints} ${AppStrings.pointsShort}',
        ),
        findsWidgets,
      );
    });

    testWidgets('switching changes the leaderboard', (tester) async {
      await pumpTwoChallenges(tester);
      await openTab(tester, AppStrings.navLeaderboard);

      // The first challenge has all four players in it.
      expect(find.text(Fixture.dana.name), findsOneWidget);
      expect(find.text(Fixture.cleo.name), findsOneWidget);

      await switchToChallenge(tester, Fixture.secondChallengeName);

      // The second has two, and Ben leads it.
      expect(find.text(Fixture.ben.name), findsOneWidget);
      expect(find.text(Fixture.mira.name), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, Fixture.ben.name),
          matching: find.text(
            '${Fixture.benSecondChallengePoints} ${AppStrings.pointsShort}',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"All challenges" goes to the list', (tester) async {
      await pumpTwoChallenges(tester);

      await openChallengeList(tester);

      expect(find.text(AppStrings.challengesTitle), findsOneWidget);
      expect(find.text('Test Challenge'), findsOneWidget);
      expect(find.text(Fixture.secondChallengeName), findsOneWidget);
    });
  });

  group('A leaderboard is the members of that challenge and nobody else', () {
    testWidgets('a player who is only in the first one is not on the second',
        (tester) async {
      await pumpTwoChallenges(tester);
      await openTab(tester, AppStrings.navLeaderboard);
      await switchToChallenge(tester, Fixture.secondChallengeName);

      // Dana and Cleo are in the first challenge only.
      expect(find.text(Fixture.dana.name), findsNothing);
      expect(find.text(Fixture.cleo.name), findsNothing);
      expect(find.byType(ListTile), findsNWidgets(2));
    });

    testWidgets('joining puts you on it, leaving takes you off',
        (tester) async {
      final world = await pumpTwoChallenges(tester);
      await openTab(tester, AppStrings.navLeaderboard);
      await switchToChallenge(tester, Fixture.secondChallengeName);
      expect(find.byType(ListTile), findsNWidgets(2));

      await world.challenges.joinByCode(
        code: Fixture.secondJoinCode,
        playerId: Fixture.dana.id,
      );
      await settle(tester);

      expect(find.text(Fixture.dana.name), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(3));

      await world.challenges.leaveChallenge(
        challengeId: Fixture.secondChallengeId,
        playerId: Fixture.dana.id,
      );
      await settle(tester);

      expect(find.text(Fixture.dana.name), findsNothing);
    });
  });

  group('The challenges list', () {
    testWidgets('names each challenge, its dates, its size and your points',
        (tester) async {
      await pumpTwoChallenges(tester);
      await openChallengeList(tester);

      expect(
        find.textContaining(AppStrings.formatMembers(Fixture.players.length)),
        findsOneWidget,
      );
      expect(find.textContaining(AppStrings.formatMembers(2)), findsOneWidget);
      expect(
        find.text('${Fixture.miraChallengePoints} ${AppStrings.pointsShort}'),
        findsOneWidget,
      );
      expect(
        find.text(
          '${Fixture.miraSecondChallengePoints} ${AppStrings.pointsShort}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('marks the one you own, and only that one', (tester) async {
      await pumpTwoChallenges(tester);
      await openChallengeList(tester);

      // Mira owns the first challenge; Ben owns the second.
      expect(find.text(AppStrings.challengesOwnerMark), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Test Challenge'),
          matching: find.text(AppStrings.challengesOwnerMark),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping a row points the tabs at it', (tester) async {
      await pumpTwoChallenges(tester);
      await openChallengeList(tester);

      await tester.tap(find.text(Fixture.secondChallengeName));
      await settle(tester);

      expect(find.text('Hi ${Fixture.mira.name}'), findsOneWidget);
      expect(find.textContaining(Fixture.secondChallengeName), findsWidgets);
    });

    testWidgets('a player in nothing gets both ways in', (tester) async {
      await pumpWorld(
        tester,
        challenges: [Fixture.secondChallenge()],
        activities: const [],
      );
      // Dana is in neither.
      await signIn(tester, Fixture.dana.name);
      await openChallengeList(tester);

      expect(find.text(AppStrings.challengesEmptyTitle), findsOneWidget);
      expect(
        buttonWithText<FilledButton>(AppStrings.challengesCreate),
        findsOneWidget,
      );
      expect(
        buttonWithText<OutlinedButton>(AppStrings.challengesJoin),
        findsOneWidget,
      );
    });
  });
}
