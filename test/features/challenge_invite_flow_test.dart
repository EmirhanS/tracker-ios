import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/domain/codes/join_code.dart';

import '../app_harness.dart';
import '../fixtures.dart';

/// Walks the whole create flow and stops on the invite screen.
Future<void> createAndStart(WidgetTester tester, String name) async {
  await tester.tap(find.text(AppStrings.dashboardSetUpChallenge));
  await settle(tester);

  await tester.enterText(find.byType(TextField).first, name);
  await settle(tester);
  await tapButton(tester, AppStrings.challengeCreate);

  await useTemplate(tester, 'General Fitness');

  await tester.tap(
    find.widgetWithText(FilledButton, AppStrings.challengeRulesReview),
  );
  await settle(tester);

  await tester.tap(
    find.widgetWithText(FilledButton, AppStrings.challengeReviewStart),
  );
  await settle(tester);
  await tester.tap(
    find.widgetWithText(FilledButton, AppStrings.challengeReviewConfirmAction),
  );
  await settle(tester);
}

void main() {
  group('The create flow ends on a code somebody can read out', () {
    testWidgets('name and dates, a schema, the rules, start, invite',
        (tester) async {
      final world = await pumpWorld(
        tester,
        challenges: const [],
        activities: const [],
      );
      await signIn(tester, Fixture.mira.name);

      await createAndStart(tester, 'Spring 2027');

      expect(find.text(AppStrings.inviteTitle), findsOneWidget);
      expect(find.text('Spring 2027'), findsOneWidget);
      expect(find.text(AppStrings.inviteBody), findsOneWidget);

      // Six characters, all from the alphabet, and the one the store holds.
      final shown = readInviteCode(tester);
      expect(shown, hasLength(JoinCode.length));
      expect(JoinCode.isValid(shown), isTrue);
      expect((await world.challenges.getAll()).single.joinCode, shown);
    });

    testWidgets('the code is grouped in halves so it reads aloud',
        (tester) async {
      await pumpWorld(tester, challenges: const [], activities: const []);
      await signIn(tester, Fixture.mira.name);
      await createAndStart(tester, 'Spring 2027');

      // The first scripted code is AAAAAA, so the screen says "AAA AAA".
      expect(find.text('AAA AAA'), findsOneWidget);
      expect(readInviteCode(tester), 'AAAAAA');
    });

    testWidgets('the copy button puts the code on the clipboard',
        (tester) async {
      await pumpWorld(tester, challenges: const [], activities: const []);
      await signIn(tester, Fixture.mira.name);
      await createAndStart(tester, 'Spring 2027');

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.tap(
        buttonWithText<FilledButton>(AppStrings.inviteCopy),
      );
      await settle(tester);

      // The plain code, not the spaced-out version: the other player pastes it.
      // Only the clipboard is checked here: the "challenge has started"
      // snackbar from the step before is still on screen, and snackbars queue.
      expect(copied, 'AAAAAA');
    });
  });

  group('A new code is the owner\'s alone, and it asks first', () {
    testWidgets('the owner gets the button and the confirmation replaces it',
        (tester) async {
      final world = await pumpWorld(
        tester,
        challenges: const [],
        activities: const [],
      );
      await signIn(tester, Fixture.mira.name);
      await createAndStart(tester, 'Spring 2027');

      expect(readInviteCode(tester), 'AAAAAA');

      await tester.tap(
        buttonWithText<OutlinedButton>(AppStrings.inviteNewCode),
      );
      await settle(tester);

      // It says what it costs before it does it.
      expect(find.text(AppStrings.inviteNewCodeTitle), findsOneWidget);
      expect(find.text(AppStrings.inviteNewCodeBody), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.inviteNewCodeAction),
      );
      await settle(tester);

      expect(readInviteCode(tester), 'BBBBBB');
      expect((await world.challenges.getAll()).single.joinCode, 'BBBBBB');
    });

    testWidgets('backing out of the confirmation keeps the old code',
        (tester) async {
      final world = await pumpWorld(
        tester,
        challenges: const [],
        activities: const [],
      );
      await signIn(tester, Fixture.mira.name);
      await createAndStart(tester, 'Spring 2027');

      await tester.tap(
        buttonWithText<OutlinedButton>(AppStrings.inviteNewCode),
      );
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, AppStrings.cancel));
      await settle(tester);

      expect(readInviteCode(tester), 'AAAAAA');
      expect((await world.challenges.getAll()).single.joinCode, 'AAAAAA');
    });

    testWidgets('a member who does not own it has no new-code button',
        (tester) async {
      // Ben is in the fixture challenge; Mira owns it.
      await pumpWorld(tester);
      await signIn(tester, Fixture.ben.name);

      await openTab(tester, AppStrings.navLeaderboard);
      await tester.tap(find.byIcon(Icons.group_outlined));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.person_add_alt));
      await settle(tester);

      expect(find.text(AppStrings.inviteTitle), findsOneWidget);
      expect(
        find.text(AppStrings.groupJoinCode(Fixture.joinCode)),
        findsOneWidget,
      );
      // Everybody can hand the code out. Only the owner can burn it.
      expect(buttonWithText<FilledButton>(AppStrings.inviteCopy),
          findsOneWidget);
      expect(find.text(AppStrings.inviteNewCode), findsNothing);
    });
  });

  group('The invite loop, on one device', () {
    testWidgets(
        'A creates and reads the code, B signs in, joins, and is on the board',
        (tester) async {
      final world = await pumpWorld(
        tester,
        challenges: const [],
        activities: const [],
      );

      // --- player A: create a challenge and read the code off the screen ---
      await signIn(tester, Fixture.mira.name);
      await createAndStart(tester, 'Spring 2027');

      final code = readInviteCode(tester);
      expect(JoinCode.isValid(code), isTrue);

      await tester.tap(find.widgetWithText(TextButton, AppStrings.inviteDone));
      await settle(tester);
      expect(find.text('Hi ${Fixture.mira.name}'), findsOneWidget);

      // --- hand the device over ------------------------------------------
      await signOut(tester);
      await signIn(tester, Fixture.ben.name);

      // Ben is in nothing, so his way in is the switcher and the list.
      await openChallengeList(tester);
      expect(find.text(AppStrings.challengesEmptyTitle), findsOneWidget);

      await tester.tap(
        buttonWithText<OutlinedButton>(AppStrings.challengesJoin),
      );
      await settle(tester);

      // --- player B: type the code, look at what it is, join --------------
      await tester.enterText(find.byType(TextField).first, code);
      await settle(tester);
      await tapButton(tester, AppStrings.joinLookUp);

      expect(find.text(AppStrings.joinPreviewTitle), findsOneWidget);
      expect(find.text('Spring 2027'), findsOneWidget);
      // The preview says who is in it so far, before anything is committed.
      expect(
        find.textContaining(AppStrings.formatMembers(1)),
        findsOneWidget,
      );

      await tapButton(tester, AppStrings.joinConfirm);

      final joined = (await world.challenges.getAll()).single;
      expect(joined.memberIds, [Fixture.mira.id, Fixture.ben.id]);

      // --- B sees it in his list ------------------------------------------
      // The "you joined" snackbar sits over the bottom of the switcher sheet,
      // which is where "All challenges" is. Let it go first.
      await tester.pump(const Duration(seconds: 5));

      await openChallengeList(tester);
      expect(find.text(AppStrings.challengesTitle), findsOneWidget);
      expect(find.text('Spring 2027'), findsOneWidget);
      // It is not his, so it carries no owner mark.
      expect(find.text(AppStrings.challengesOwnerMark), findsNothing);

      await tester.tap(find.text('Spring 2027'));
      await settle(tester);

      // --- and he can score in it -----------------------------------------
      await openTab(tester, AppStrings.navLog);
      await tester.enterText(find.byType(TextField).first, '60');
      await settle(tester);
      await tapButton(tester, AppStrings.logSubmit);

      await openTab(tester, AppStrings.navLeaderboard);
      expect(find.text(Fixture.ben.name), findsOneWidget);
      expect(find.text(Fixture.mira.name), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, Fixture.ben.name),
          matching: find.text('3 ${AppStrings.pointsShort}'),
        ),
        findsOneWidget,
      );
    });
  });
}
