import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/domain/models/challenge.dart';

import '../app_harness.dart';
import '../fixtures.dart';

/// Signs [playerName] in and opens the join screen through the switcher.
Future<TestWorld> openJoin(
  WidgetTester tester,
  String playerName, {
  List<Challenge>? challenges,
}) async {
  final world = await pumpWorld(
    tester,
    challenges: challenges,
    activities: const [],
  );
  await signIn(tester, playerName);
  await openChallengeList(tester);
  await tester.tap(
    buttonWithText<OutlinedButton>(AppStrings.challengesJoin),
  );
  await settle(tester);
  return world;
}

/// The join code field, as the screen currently holds it.
String fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

void main() {
  group('The code field takes a code in the shape people write it down',
      () {
    testWidgets('lower case is uppercased', (tester) async {
      await openJoin(tester, Fixture.mira.name);

      await tester.enterText(find.byType(TextField).first, 'tester');
      await settle(tester);

      expect(fieldText(tester), Fixture.joinCode);
    });

    testWidgets('a space in the middle is dropped', (tester) async {
      await openJoin(tester, Fixture.mira.name);

      await tester.enterText(find.byType(TextField).first, 'tes ter');
      await settle(tester);

      expect(fieldText(tester), Fixture.joinCode);
    });

    testWidgets('a dash is dropped, and so are both at once', (tester) async {
      await openJoin(tester, Fixture.mira.name);

      await tester.enterText(find.byType(TextField).first, ' tes-TER ');
      await settle(tester);

      expect(fieldText(tester), Fixture.joinCode);
    });

    testWidgets('more than six characters cannot be typed', (tester) async {
      await openJoin(tester, Fixture.mira.name);

      await tester.enterText(find.byType(TextField).first, 'ABCDEFGHJ');
      await settle(tester);

      expect(fieldText(tester), 'ABCDEF');
    });

    testWidgets('a half-typed code cannot be looked up', (tester) async {
      await openJoin(tester, Fixture.mira.name);

      await tester.enterText(find.byType(TextField).first, 'TES');
      await settle(tester);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, AppStrings.joinLookUp),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('A code that matches nothing', () {
    testWidgets('says so and stays where it is', (tester) async {
      await openJoin(tester, Fixture.mira.name);

      await tester.enterText(find.byType(TextField).first, 'ZZZZZZ');
      await settle(tester);
      await tapButton(tester, AppStrings.joinLookUp);

      expect(find.text(AppStrings.joinNotFound), findsOneWidget);
      // Still on the join screen: nothing was navigated to.
      expect(find.text(AppStrings.joinTitle), findsOneWidget);
      expect(find.text(AppStrings.joinPreviewTitle), findsNothing);
      expect(find.text(AppStrings.joinConfirm), findsNothing);
    });

    testWidgets('typing again clears the message', (tester) async {
      await openJoin(tester, Fixture.mira.name);

      await tester.enterText(find.byType(TextField).first, 'ZZZZZZ');
      await settle(tester);
      await tapButton(tester, AppStrings.joinLookUp);
      expect(find.text(AppStrings.joinNotFound), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'TESTER');
      await settle(tester);

      expect(find.text(AppStrings.joinNotFound), findsNothing);
    });
  });

  group('A code you have already used', () {
    testWidgets('says you are in it, and offers to open it instead',
        (tester) async {
      final world = await openJoin(tester, Fixture.mira.name);

      await tester.enterText(find.byType(TextField).first, Fixture.joinCode);
      await settle(tester);
      await tapButton(tester, AppStrings.joinLookUp);

      expect(find.text(AppStrings.joinAlreadyMember), findsOneWidget);
      expect(find.text(AppStrings.joinPreviewTitle), findsNothing);

      // The member list is untouched by a second look at the same code.
      expect(
        (await world.challenges.getAll()).single.memberIds,
        hasLength(Fixture.players.length),
      );

      await tester.tap(
        buttonWithText<OutlinedButton>(AppStrings.joinOpenInstead),
      );
      await settle(tester);

      expect(find.text('Hi ${Fixture.mira.name}'), findsOneWidget);
    });
  });

  group('A code that matches a challenge you are not in', () {
    testWidgets('shows what you would be joining before it joins you',
        (tester) async {
      // Dana is in the first challenge only, so the second one is new to her.
      final world = await openJoin(
        tester,
        Fixture.dana.name,
        challenges: [Fixture.challenge(), Fixture.secondChallenge()],
      );

      await tester.enterText(
        find.byType(TextField).first,
        Fixture.secondJoinCode,
      );
      await settle(tester);
      await tapButton(tester, AppStrings.joinLookUp);

      expect(find.text(AppStrings.joinPreviewTitle), findsOneWidget);
      expect(find.text(Fixture.secondChallengeName), findsOneWidget);
      expect(find.textContaining(AppStrings.formatMembers(2)), findsOneWidget);
      // Its rules are on show, not the ones of the challenge she is in.
      expect(find.text(Fixture.secondRowing.name), findsOneWidget);
      expect(find.text(Fixture.running.name), findsNothing);

      // Nothing has been written yet.
      final before = await world.challenges.getById(Fixture.secondChallengeId);
      expect(before!.isMember(Fixture.dana.id), isFalse);

      await tapButton(tester, AppStrings.joinConfirm);

      final after = await world.challenges.getById(Fixture.secondChallengeId);
      expect(after!.memberIds, contains(Fixture.dana.id));
      // And the tabs are pointed at what she just joined.
      expect(find.textContaining(Fixture.secondChallengeName), findsWidgets);
    });

    testWidgets('cancelling leaves the challenge alone', (tester) async {
      final world = await openJoin(
        tester,
        Fixture.dana.name,
        challenges: [Fixture.challenge(), Fixture.secondChallenge()],
      );

      await tester.enterText(
        find.byType(TextField).first,
        Fixture.secondJoinCode,
      );
      await settle(tester);
      await tapButton(tester, AppStrings.joinLookUp);
      expect(find.text(AppStrings.joinPreviewTitle), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, AppStrings.cancel));
      await settle(tester);

      expect(find.text(AppStrings.joinPreviewTitle), findsNothing);
      expect(find.text(AppStrings.joinTitle), findsOneWidget);
      final challenge =
          await world.challenges.getById(Fixture.secondChallengeId);
      expect(challenge!.isMember(Fixture.dana.id), isFalse);
    });
  });
}
