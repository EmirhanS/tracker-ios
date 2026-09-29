import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/data/in_memory/id_generator.dart';

import '../app_harness.dart';
import '../doubles/refusing_challenge_repository.dart';
import '../fixtures.dart';

/// Signs [playerName] in and opens the member list of the fixture challenge.
Future<TestWorld> openMembers(
  WidgetTester tester,
  String playerName, {
  RefusingChallengeRepository? repository,
}) async {
  final world = await pumpWorld(
    tester,
    activities: const [],
    challengeRepository: repository,
  );
  await signIn(tester, playerName);
  await openTab(tester, AppStrings.navLeaderboard);
  await tester.tap(find.byIcon(Icons.group_outlined));
  await settle(tester);
  return world;
}

/// The remove button of the row for [playerName].
Finder removeButtonFor(String playerName) => find.descendant(
      of: find.widgetWithText(ListTile, playerName),
      matching: find.byIcon(Icons.person_remove_outlined),
    );

void main() {
  group('The owner', () {
    testWidgets('sees every member, with themselves marked as owner',
        (tester) async {
      await openMembers(tester, Fixture.mira.name);

      expect(find.text(AppStrings.membersTitle), findsOneWidget);
      for (final player in Fixture.players) {
        expect(find.text(player.name), findsOneWidget);
      }
      expect(find.text(AppStrings.challengesOwnerMark), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, Fixture.mira.name),
          matching: find.text(AppStrings.challengesOwnerMark),
        ),
        findsOneWidget,
      );
    });

    testWidgets('can remove anybody but themselves', (tester) async {
      await openMembers(tester, Fixture.mira.name);

      expect(
        find.byIcon(Icons.person_remove_outlined),
        findsNWidgets(Fixture.players.length - 1),
      );
      expect(removeButtonFor(Fixture.mira.name), findsNothing);
      expect(removeButtonFor(Fixture.ben.name), findsOneWidget);
    });

    testWidgets('is never offered a way to leave their own challenge',
        (tester) async {
      await openMembers(tester, Fixture.mira.name);

      expect(find.text(AppStrings.membersLeave), findsNothing);
    });

    testWidgets('a remove asks first, then writes, then the row goes',
        (tester) async {
      final world = await openMembers(tester, Fixture.mira.name);

      await tester.tap(removeButtonFor(Fixture.cleo.name));
      await settle(tester);

      expect(find.text(AppStrings.membersRemoveTitle), findsOneWidget);
      // Nothing has happened yet.
      expect(
        (await world.challenges.getAll()).single.memberIds,
        contains(Fixture.cleo.id),
      );

      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.membersRemove),
      );
      await settle(tester);

      expect(
        (await world.challenges.getAll()).single.memberIds,
        isNot(contains(Fixture.cleo.id)),
      );
      expect(find.text(Fixture.cleo.name), findsNothing);
      expect(find.text(Fixture.ben.name), findsOneWidget);
    });

    testWidgets('backing out of the confirmation keeps the member',
        (tester) async {
      final world = await openMembers(tester, Fixture.mira.name);

      await tester.tap(removeButtonFor(Fixture.cleo.name));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, AppStrings.cancel));
      await settle(tester);

      expect(find.text(Fixture.cleo.name), findsOneWidget);
      expect(
        (await world.challenges.getAll()).single.memberIds,
        contains(Fixture.cleo.id),
      );
    });

    testWidgets('a remove the store refuses puts nothing back, because '
        'nothing left', (tester) async {
      // The row is the store's, not the screen's: it goes when the write has
      // landed and not a frame before, so a refused write is simply visible.
      await openMembers(
        tester,
        Fixture.mira.name,
        repository: RefusingChallengeRepository(
          challenges: [Fixture.challenge()],
          idGenerator: IdGenerator(start: 1),
        ),
      );

      await tester.tap(removeButtonFor(Fixture.cleo.name));
      await settle(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.membersRemove),
      );
      await settle(tester);

      expect(find.text(AppStrings.membersRemoveFailed), findsOneWidget);
      expect(find.text(Fixture.cleo.name), findsOneWidget);
      expect(removeButtonFor(Fixture.cleo.name), findsOneWidget);
    });
  });

  group('A member who does not own it', () {
    testWidgets('can leave, and cannot remove anybody', (tester) async {
      await openMembers(tester, Fixture.ben.name);

      expect(find.text(AppStrings.membersLeave), findsOneWidget);
      expect(find.byIcon(Icons.person_remove_outlined), findsNothing);
    });

    testWidgets('leaving asks first, writes, and lands on the list',
        (tester) async {
      final world = await openMembers(tester, Fixture.ben.name);

      await tester.tap(
        buttonWithText<OutlinedButton>(AppStrings.membersLeave),
      );
      await settle(tester);

      expect(find.text(AppStrings.membersLeaveTitle), findsOneWidget);
      expect(
        (await world.challenges.getAll()).single.memberIds,
        contains(Fixture.ben.id),
      );

      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.membersLeaveAction),
      );
      await settle(tester);

      expect(
        (await world.challenges.getAll()).single.memberIds,
        isNot(contains(Fixture.ben.id)),
      );
      // He is in nothing now, so the list says so.
      expect(find.text(AppStrings.challengesTitle), findsOneWidget);
      expect(find.text(AppStrings.challengesEmptyTitle), findsOneWidget);
    });

    testWidgets('a refused leave says so and leaves him where he was',
        (tester) async {
      await openMembers(
        tester,
        Fixture.ben.name,
        repository: RefusingChallengeRepository(
          challenges: [Fixture.challenge()],
          idGenerator: IdGenerator(start: 1),
        ),
      );

      await tester.tap(
        buttonWithText<OutlinedButton>(AppStrings.membersLeave),
      );
      await settle(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.membersLeaveAction),
      );
      await settle(tester);

      expect(find.text(AppStrings.membersLeaveFailed), findsOneWidget);
      expect(find.text(AppStrings.membersTitle), findsOneWidget);
      expect(find.text(Fixture.ben.name), findsOneWidget);
    });
  });
}
