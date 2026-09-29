import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sporttracker/core/router/app_routes.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/domain/models/scoring_rule.dart';
import 'package:sporttracker/features/challenge/scoring_rules_screen.dart';
import 'package:sporttracker/features/dashboard/dashboard_screen.dart';

import '../app_harness.dart';
import '../fixtures.dart';

/// Signs [playerName] in and opens the read-only rules screen.
Future<TestWorld> openRules(WidgetTester tester, String playerName) async {
  final world = await pumpWorld(tester);
  await signIn(tester, playerName);
  await tester.tap(find.byIcon(Icons.rule));
  await settle(tester);
  return world;
}

void main() {
  group('The edit action belongs to the owner', () {
    testWidgets('the owner of a running challenge gets it', (tester) async {
      await openRules(tester, Fixture.mira.name);

      expect(find.text(AppStrings.scoringRulesTitle), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('a member who does not own it does not', (tester) async {
      await openRules(tester, Fixture.ben.name);

      // Same screen, same rules, no way in.
      expect(find.byType(ScoringRuleTile), findsNWidgets(Fixture.rules.length));
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('the read-only screen stays read only for the owner too',
        (tester) async {
      await openRules(tester, Fixture.mira.name);

      expect(find.byType(Switch), findsNothing);
      final tiles =
          tester.widgetList<ScoringRuleTile>(find.byType(ScoringRuleTile));
      for (final tile in tiles) {
        expect(tile.onTap, isNull);
      }
    });
  });

  group('Editing a rule while the challenge is running', () {
    testWidgets('the editor says the change counts from now on',
        (tester) async {
      await openRules(tester, Fixture.mira.name);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await settle(tester);

      expect(find.text(AppStrings.challengeRulesTitle), findsOneWidget);
      expect(find.text(AppStrings.challengeRulesLiveNote), findsOneWidget);
      // There is nothing left to review: the challenge is already running.
      expect(find.text(AppStrings.challengeRulesReview), findsNothing);
      expect(find.widgetWithText(FilledButton, AppStrings.done),
          findsOneWidget);
    });

    testWidgets('the edit saves, leaves the editor, and moves nobody\'s points',
        (tester) async {
      final world = await openRules(tester, Fixture.mira.name);

      // Mira logged her gym sessions at 3 points each before any of this.
      expect(await world.pointsOf(Fixture.mira.id),
          Fixture.miraChallengePoints);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await settle(tester);
      await tester.tap(find.text(Fixture.gym.name));
      await settle(tester);
      expect(find.text(AppStrings.challengeRuleEditTitle), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.challengeRulePoints),
        '9',
      );
      await settle(tester);
      await tapButton(tester, AppStrings.save);

      // Saved, and back on the rules list rather than stuck in the editor.
      expect(find.text(AppStrings.challengeRuleEditTitle), findsNothing);
      expect(find.text(AppStrings.challengeRulesTitle), findsOneWidget);

      final challenge = (await world.challenges.getAll()).single;
      final gym = challenge.rules.firstWhere((rule) => rule.id == Fixture.gym.id);
      expect((gym.scoring as FixedScoring).points, 9);
      expect(challenge.isActive, isTrue);
      // The member list and the code came through the edit untouched.
      expect(challenge.memberIds, hasLength(Fixture.players.length));
      expect(challenge.joinCode, Fixture.joinCode);

      // And the activity she logged under the old rule is worth what it was.
      expect(await world.pointsOf(Fixture.mira.id),
          Fixture.miraChallengePoints);
      final logged = await world.activitiesOf(Fixture.mira.id);
      final underGym =
          logged.where((activity) => activity.ruleId == Fixture.gym.id);
      expect(underGym, isNotEmpty);
      for (final activity in underGym) {
        expect(activity.points, 3);
      }
    });

    testWidgets('a non-owner who reaches the editor by hand is sent back',
        (tester) async {
      // No screen offers this, but a route is a route.
      await pumpWorld(tester);
      await signIn(tester, Fixture.ben.name);

      final router = GoRouter.of(tester.element(find.byType(DashboardScreen)));
      router.go(AppRoutes.challengeRules(Fixture.challengeId));
      await settle(tester);

      expect(find.text(AppStrings.challengeRulesTitle), findsNothing);
      expect(find.text(AppStrings.challengesTitle), findsOneWidget);
    });

    testWidgets('the owner reaching the same route by hand gets in',
        (tester) async {
      await pumpWorld(tester);
      await signIn(tester, Fixture.mira.name);

      final router = GoRouter.of(tester.element(find.byType(DashboardScreen)));
      router.go(AppRoutes.challengeRules(Fixture.challengeId));
      await settle(tester);

      expect(find.text(AppStrings.challengeRulesTitle), findsOneWidget);
    });
  });
}
