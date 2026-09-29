import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/data/in_memory/id_generator.dart';
import 'package:sporttracker/domain/exceptions.dart';
import 'package:sporttracker/domain/models/challenge.dart';
import 'package:sporttracker/domain/models/scoring_rule.dart';
import 'package:sporttracker/domain/templates/challenge_templates.dart';

import '../app_harness.dart';

Future<void> createChallenge(WidgetTester tester, {String name = 'Spring'}) async {
  await tester.tap(find.text(AppStrings.dashboardSetUpChallenge));
  await settle(tester);

  await tester.enterText(find.byType(TextField).first, name);
  await settle(tester);
  await tapButton(tester, AppStrings.challengeCreate);
}

void main() {
  group('Empty states and owner gating', () {
    testWidgets('the owner sees the setup button when no challenge runs',
        (tester) async {
      await pumpAppWithoutChallenge(tester);
      await signIn(tester, 'Mia Halvorsen');

      expect(find.text(AppStrings.dashboardNoChallengeTitle), findsOneWidget);
      expect(find.text(AppStrings.dashboardSetUpChallenge), findsOneWidget);
    });

    testWidgets('a player who is not the owner gets no setup button',
        (tester) async {
      final repositories = await pumpAppWithoutChallenge(tester);

      // Mia sets a challenge up, so Mia is the owner.
      await repositories.challenges.createDraft(
        name: 'Spring 2027',
        startDate: testToday,
        endDate: DateTime(2027, 6, 30),
        ownerId: 'player_1',
      );
      await settle(tester);

      await signIn(tester, 'Jonas Berg');

      expect(find.text(AppStrings.dashboardNoChallengeTitle), findsOneWidget);
      expect(find.text(AppStrings.dashboardSetUpChallenge), findsNothing);
      expect(find.text(AppStrings.dashboardNoChallengeBody), findsOneWidget);
    });

    testWidgets('the log screen also offers setup to the owner',
        (tester) async {
      await pumpAppWithoutChallenge(tester);
      await signIn(tester, 'Mia Halvorsen');

      await tester.tap(find.text(AppStrings.navLog));
      await settle(tester);

      expect(find.text(AppStrings.dashboardSetUpChallenge), findsOneWidget);
    });
  });

  group('Challenge setup flow', () {
    testWidgets('create, take the template, then start the challenge',
        (tester) async {
      final repositories = await pumpAppWithoutChallenge(tester);
      await signIn(tester, 'Mia Halvorsen');

      await createChallenge(tester, name: 'Spring 2027');

      // The draft exists and the template step is showing.
      final drafts = await repositories.challenges.getAll();
      expect(drafts, hasLength(1));
      expect(drafts.single.name, 'Spring 2027');
      expect(drafts.single.status, ChallengeStatus.draft);
      expect(find.text('General Fitness'), findsOneWidget);

      await useTemplate(tester, 'General Fitness');

      // The five template rules are copied in.
      expect(find.text('Gym session'), findsOneWidget);
      expect(find.text('Cycling'), findsOneWidget);
      expect((await repositories.challenges.getAll()).single.rules, hasLength(5));

      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.challengeRulesReview),
      );
      await settle(tester);

      expect(find.text('Spring 2027'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.challengeReviewStart),
      );
      await settle(tester);

      // Starting asks first.
      expect(find.text(AppStrings.challengeReviewConfirmTitle), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.challengeReviewConfirmAction),
      );
      await settle(tester);

      final challenge = (await repositories.challenges.getAll()).single;
      expect(challenge.isActive, isTrue);
      expect(challenge.memberIds, ['player_1']);

      // Setup ends on the invite screen: a challenge with one member in it is
      // not a challenge yet.
      expect(find.text(AppStrings.inviteTitle), findsOneWidget);
      expect(
        find.text(AppStrings.groupJoinCode(challenge.joinCode)),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, AppStrings.inviteDone));
      await settle(tester);

      expect(find.text('Hi Mia Halvorsen'), findsOneWidget);
      expect(find.text(AppStrings.dashboardChallengePoints), findsOneWidget);
    });

    testWidgets('a rule can be switched off before the challenge starts',
        (tester) async {
      final repositories = await pumpAppWithoutChallenge(tester);
      await signIn(tester, 'Mia Halvorsen');
      await createChallenge(tester);
      await useTemplate(tester, 'General Fitness');

      await tester.tap(find.byType(Switch).first);
      await settle(tester);

      final challenge = (await repositories.challenges.getAll()).single;
      expect(challenge.rules.first.isEnabled, isFalse);
      expect(challenge.enabledRules, hasLength(4));
    });

    testWidgets('a rule can be edited before the challenge starts',
        (tester) async {
      final repositories = await pumpAppWithoutChallenge(tester);
      await signIn(tester, 'Mia Halvorsen');
      await createChallenge(tester);
      await useTemplate(tester, 'General Fitness');

      await tester.tap(find.text('Gym session'));
      await settle(tester);

      // The form is showing, not the not-found fallback: only the form has a
      // scoring type picker.
      expect(find.text(AppStrings.challengeRuleScoringType), findsOneWidget);
      expect(find.text(AppStrings.challengeRuleEditTitle), findsOneWidget);

      // Points is the first number field for a fixed rule.
      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.challengeRulePoints),
        '5',
      );
      await settle(tester);
      await tapButton(tester, AppStrings.save);

      final challenge = (await repositories.challenges.getAll()).single;
      final gym = challenge.rules.firstWhere((rule) => rule.name == 'Gym session');
      expect(AppStrings.describeScoring(gym.scoring), startsWith('5 points'));
    });

    testWidgets('a rule with a name another rule uses cannot be saved',
        (tester) async {
      final repositories = await pumpAppWithoutChallenge(tester);
      await signIn(tester, 'Mia Halvorsen');
      await createChallenge(tester);
      await useTemplate(tester, 'General Fitness');

      await tester.tap(find.text('Gym session'));
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.challengeRuleName),
        'Cycling',
      );
      await settle(tester);
      await tapButton(tester, AppStrings.save);

      expect(
        find.text('Another rule already uses this name.'),
        findsWidgets,
      );
      final challenge = (await repositories.challenges.getAll()).single;
      expect(
        challenge.rules.where((rule) => rule.name == 'Cycling'),
        hasLength(1),
      );
    });

    testWidgets('a challenge with every rule off cannot be reviewed',
        (tester) async {
      await pumpAppWithoutChallenge(tester);
      await signIn(tester, 'Mia Halvorsen');
      await createChallenge(tester);
      await useTemplate(tester, 'General Fitness');

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byType(Switch).at(i));
        await settle(tester);
      }

      expect(find.text(AppStrings.challengeRulesNoneEnabled), findsOneWidget);
      final review = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, AppStrings.challengeRulesReview),
      );
      expect(review.onPressed, isNull);
    });
  });

  group('Leaving setup part way through', () {
    testWidgets('the setup button goes back to the draft, not to a second one',
        (tester) async {
      final repositories = await pumpAppWithoutChallenge(tester);

      // A draft Mia started earlier and never finished.
      final ids = IdGenerator();
      await repositories.challenges.createDraft(
        name: 'Spring 2027',
        startDate: testToday,
        endDate: DateTime(2027, 6, 30),
        ownerId: 'player_1',
        rules: ChallengeTemplates.generalFitness.buildRules(
          ids.forPrefix('rule'),
        ),
      );
      await settle(tester);

      await signIn(tester, 'Mia Halvorsen');
      await tester.tap(find.text(AppStrings.dashboardSetUpChallenge));
      await settle(tester);

      // Back on the rules of the same draft, and still only one challenge.
      expect(find.text('Gym session'), findsOneWidget);
      expect(find.text(AppStrings.challengeRulesTitle), findsOneWidget);
      expect(await repositories.challenges.getAll(), hasLength(1));
    });
  });

  group('Scoring rules screen', () {
    testWidgets('every player can read the rules of the running challenge',
        (tester) async {
      await pumpApp(tester);
      await signIn(tester, 'Jonas Berg');

      await tester.tap(find.byIcon(Icons.rule));
      await settle(tester);

      expect(find.text(AppStrings.scoringRulesTitle), findsOneWidget);
      expect(find.text('Gym session'), findsOneWidget);
      expect(find.text('3 points · from 45 min'), findsOneWidget);
      expect(find.text('Team sport'), findsOneWidget);
    });
  });

  group('A running challenge keeps its rules editable', () {
    testWidgets('the seeded challenge takes a rule edit', (tester) async {
      // v1 locked the rules the moment a season started. v2 leaves them with
      // the owner: Activity froze its own points at log time, so nobody's score
      // moves when a rule changes.
      final repositories = await pumpApp(tester);
      final challenge = (await repositories.challenges.getAll()).first;
      final rules = List<ScoringRule>.of(challenge.rules);
      rules[0] = rules[0].copyWith(isEnabled: false);

      final updated = await repositories.challenges.updateChallenge(
        challenge.copyWith(rules: rules),
      );

      expect(updated.isActive, isTrue);
      expect(updated.enabledRules, hasLength(4));
    });

    testWidgets('but its dates are fixed', (tester) async {
      final repositories = await pumpApp(tester);
      final challenge = (await repositories.challenges.getAll()).first;

      await expectLater(
        repositories.challenges.updateChallenge(
          challenge.copyWith(endDate: DateTime(2027, 12, 31)),
        ),
        throwsA(isA<ChallengeLockedException>()),
      );
    });
  });
}
