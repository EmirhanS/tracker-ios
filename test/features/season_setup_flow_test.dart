import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/router/app_routes.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/domain/models/scoring_rule.dart';
import 'package:sporttracker/domain/models/season.dart';
import 'package:sporttracker/features/season/season_rule_edit_screen.dart';
import 'package:sporttracker/features/season/season_rules_screen.dart';

import '../app_harness.dart';
import '../fixtures.dart';

/// A team that has never had a season, so setup starts from nothing.
Future<TestWorld> pumpFreshTeam(WidgetTester tester) =>
    pumpWorld(tester, seasons: const [], activities: const []);

/// Walks the first step: name the season and create it.
Future<void> createSeason(WidgetTester tester, String name) async {
  await tester.tap(find.text(AppStrings.dashboardSetUpSeason));
  await settle(tester);

  expect(find.text(AppStrings.seasonNewTitle), findsOneWidget);
  await tester.enterText(find.byType(TextField).first, name);
  await settle(tester);
  await tapButton(tester, AppStrings.seasonCreate);
}

void main() {
  group('Only the captain reaches setup', () {
    testWidgets('a team with no season at all lets anybody start one',
        (tester) async {
      await pumpFreshTeam(tester);
      await signIn(tester, Fixture.dana.name);

      expect(find.text(AppStrings.dashboardNoSeasonTitle), findsOneWidget);
      expect(find.text(AppStrings.dashboardSetUpSeason), findsOneWidget);
    });

    testWidgets('once a season exists, its captain keeps the button',
        (tester) async {
      await pumpWorld(
        tester,
        seasons: [Fixture.season(status: SeasonStatus.draft)],
        activities: const [],
      );
      await signIn(tester, Fixture.mira.name);

      expect(find.text(AppStrings.dashboardSetUpSeason), findsOneWidget);
      expect(
        find.text(AppStrings.dashboardNoSeasonCaptainBody),
        findsOneWidget,
      );
    });

    testWidgets('everybody else gets no way in', (tester) async {
      await pumpWorld(
        tester,
        seasons: [Fixture.season(status: SeasonStatus.draft)],
        activities: const [],
      );
      await signIn(tester, Fixture.ben.name);

      expect(find.text(AppStrings.dashboardNoSeasonTitle), findsOneWidget);
      expect(find.text(AppStrings.dashboardSetUpSeason), findsNothing);
      expect(find.text(AppStrings.dashboardNoSeasonBody), findsOneWidget);

      // The log screen offers the same shortcut, and must gate it the same way.
      await tester.tap(find.text(AppStrings.navLog));
      await settle(tester);
      expect(find.text(AppStrings.dashboardSetUpSeason), findsNothing);
    });

    testWidgets('the captain can also start setup from the log screen',
        (tester) async {
      await pumpWorld(
        tester,
        seasons: [Fixture.season(status: SeasonStatus.draft)],
        activities: const [],
      );
      await signIn(tester, Fixture.mira.name);

      await tester.tap(find.text(AppStrings.navLog));
      await settle(tester);
      expect(find.text(AppStrings.dashboardSetUpSeason), findsOneWidget);
    });
  });

  group('The router guards follow the session', () {
    // The redirect reads whether anybody is signed in, whether they are the
    // captain, and whether a season is running. Each of those has to reach it.

    testWidgets('signing out goes back to the welcome screen', (tester) async {
      await pumpWorld(tester);
      await signIn(tester, Fixture.mira.name);
      expect(find.text('Hi ${Fixture.mira.name}'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.switch_account));
      await settle(tester);

      expect(find.text(AppStrings.welcomeChoosePlayer), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('signing back in as somebody else re-reads who the captain is',
        (tester) async {
      await pumpWorld(
        tester,
        seasons: [Fixture.season(status: SeasonStatus.draft)],
        activities: const [],
      );

      // The captain has the setup button.
      await signIn(tester, Fixture.mira.name);
      expect(find.text(AppStrings.dashboardSetUpSeason), findsOneWidget);

      await tester.tap(find.byIcon(Icons.switch_account));
      await settle(tester);
      await signIn(tester, Fixture.ben.name);

      // Ben is not, so it is gone.
      expect(find.text(AppStrings.dashboardSetUpSeason), findsNothing);
    });

    testWidgets('a running season closes setup for good', (tester) async {
      await pumpWorld(tester);
      await signIn(tester, Fixture.mira.name);

      // Mira is the captain, but the season is already running, so there is
      // nothing to set up.
      expect(find.text(AppStrings.dashboardSetUpSeason), findsNothing);
      expect(find.text(AppStrings.dashboardSeasonPoints), findsOneWidget);

      await tester.tap(find.text(AppStrings.navLog));
      await settle(tester);
      expect(find.text(AppStrings.dashboardSetUpSeason), findsNothing);
    });
  });

  group('The whole setup flow', () {
    testWidgets('create, take General Fitness, edit a rule, review, start',
        (tester) async {
      final world = await pumpFreshTeam(tester);
      await signIn(tester, Fixture.mira.name);

      // --- step one: name and dates -------------------------------------
      await createSeason(tester, 'Spring 2027');

      var seasons = await world.seasons.getAll();
      expect(seasons, hasLength(1));
      expect(seasons.single.name, 'Spring 2027');
      expect(seasons.single.status, SeasonStatus.draft);
      expect(seasons.single.captainId, Fixture.mira.id);

      // --- step two: the template ---------------------------------------
      expect(find.text(AppStrings.seasonTemplateTitle), findsOneWidget);
      expect(find.text('General Fitness'), findsOneWidget);
      await tapButton(tester, AppStrings.seasonTemplateUse);

      expect(find.text(AppStrings.seasonRulesTitle), findsOneWidget);
      seasons = await world.seasons.getAll();
      expect(seasons.single.rules, hasLength(5));
      expect(
        seasons.single.rules.map((rule) => rule.name),
        containsAll(<String>['Gym session', 'Running', 'Cycling']),
      );

      // --- step three: edit one rule ------------------------------------
      await tester.tap(find.text('Gym session'));
      await settle(tester);
      expect(find.text(AppStrings.seasonRuleEditTitle), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.seasonRulePoints),
        '5',
      );
      await settle(tester);
      await tapButton(tester, AppStrings.save);

      expect(find.text(AppStrings.seasonRulesTitle), findsOneWidget);
      final edited = (await world.seasons.getAll())
          .single
          .rules
          .firstWhere((rule) => rule.name == 'Gym session');
      expect((edited.scoring as FixedScoring).points, 5);

      // --- step four: review --------------------------------------------
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.seasonRulesReview),
      );
      await settle(tester);

      expect(find.text(AppStrings.seasonReviewTitle), findsOneWidget);
      expect(find.text('Spring 2027'), findsOneWidget);
      expect(find.text('5 points · from 45 min'), findsOneWidget);

      // --- step five: start ---------------------------------------------
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.seasonReviewStart),
      );
      await settle(tester);

      // Starting locks the rules, so it asks first.
      expect(find.text(AppStrings.seasonReviewConfirmTitle), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.seasonReviewConfirmAction),
      );
      await settle(tester);

      final started = await world.seasons.getActiveSeason();
      expect(started, isNotNull);
      expect(started!.name, 'Spring 2027');
      expect(started.isLocked, isTrue);
      expect(
        (started.rules.firstWhere((rule) => rule.name == 'Gym session').scoring
                as FixedScoring)
            .points,
        5,
      );

      // And the captain lands back on a working dashboard.
      expect(find.text('Hi ${Fixture.mira.name}'), findsOneWidget);
      expect(find.text(AppStrings.dashboardSeasonPoints), findsOneWidget);
    });

    testWidgets('a draft with rules already on it resumes at the rules step',
        (tester) async {
      // The captain named a season and took the template last time, then quit.
      final world = await pumpWorld(
        tester,
        seasons: [Fixture.season(status: SeasonStatus.draft)],
        activities: const [],
      );
      await signIn(tester, Fixture.mira.name);

      await tester.tap(find.text(AppStrings.dashboardSetUpSeason));
      await settle(tester);

      expect(find.text(AppStrings.seasonRulesTitle), findsOneWidget);
      expect(find.text(Fixture.gym.name), findsOneWidget);
      // Resumed, not started over: still one season.
      expect(await world.seasons.getAll(), hasLength(1));
    });

    testWidgets('a draft with no rules yet resumes at the template step',
        (tester) async {
      final world = await pumpWorld(
        tester,
        seasons: [
          Fixture.season(status: SeasonStatus.draft).copyWith(rules: const []),
        ],
        activities: const [],
      );
      await signIn(tester, Fixture.mira.name);

      await tester.tap(find.text(AppStrings.dashboardSetUpSeason));
      await settle(tester);

      expect(find.text(AppStrings.seasonTemplateTitle), findsOneWidget);
      expect(find.text('General Fitness'), findsOneWidget);
      expect(await world.seasons.getAll(), hasLength(1));
    });
  });

  group('A season with no enabled rule cannot start', () {
    testWidgets('the review button is off and the reason is shown',
        (tester) async {
      final world = await pumpFreshTeam(tester);
      await signIn(tester, Fixture.mira.name);
      await createSeason(tester, 'Spring 2027');
      await tapButton(tester, AppStrings.seasonTemplateUse);

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byType(Switch).at(i));
        await settle(tester);
      }

      expect(find.text(AppStrings.seasonRulesNoneEnabled), findsOneWidget);
      final review = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, AppStrings.seasonRulesReview),
      );
      expect(review.onPressed, isNull);

      // The repository refuses it too, so the screen is not the only guard.
      expect(
        (await world.seasons.getAll()).single.enabledRules,
        isEmpty,
      );
      await expectLater(
        world.seasons.startSeason('season_1'),
        throwsA(isA<StateError>()),
      );
      expect(await world.seasons.getActiveSeason(), isNull);
    });

    testWidgets('switching one back on lets the review through',
        (tester) async {
      await pumpFreshTeam(tester);
      await signIn(tester, Fixture.mira.name);
      await createSeason(tester, 'Spring 2027');
      await tapButton(tester, AppStrings.seasonTemplateUse);

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byType(Switch).at(i));
        await settle(tester);
      }
      await tester.tap(find.byType(Switch).first);
      await settle(tester);

      expect(find.text(AppStrings.seasonRulesNoneEnabled), findsNothing);
      final review = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, AppStrings.seasonRulesReview),
      );
      expect(review.onPressed, isNotNull);
    });
  });

  group('The rules of a running season are locked', () {
    // The router keeps setup out of reach while a season runs, so these pump
    // the screens straight onto the tree. The screens still have to cope: a
    // repository that refuses a write must read as a message, not a crash.

    testWidgets('the repository refuses the edit', (tester) async {
      final world = await pumpWorld(tester);
      final season = (await world.seasons.getActiveSeason())!;

      expect(season.isLocked, isTrue);
      await expectLater(
        world.seasons.updateSeason(season.copyWith(rules: const [])),
        throwsA(isA<Exception>()),
      );
      expect((await world.seasons.getActiveSeason())!.rules, hasLength(5));
    });

    testWidgets('switching a rule off says so instead of crashing',
        (tester) async {
      final world = await pumpScreen(
        tester,
        const SeasonRulesScreen(seasonId: Fixture.seasonId),
      );

      await tester.tap(find.byType(Switch).first);
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.seasonLocked), findsOneWidget);

      // And the season is untouched.
      final season = (await world.seasons.getActiveSeason())!;
      expect(season.rules.first.isEnabled, isTrue);
      expect(season.rules, hasLength(5));
    });

    testWidgets('saving a rule says so instead of crashing', (tester) async {
      final world = await pumpScreen(
        tester,
        const SeasonRuleEditScreen(
          seasonId: Fixture.seasonId,
          ruleId: 'rule_1',
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.seasonRulePoints),
        '9',
      );
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.save));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.seasonLocked), findsOneWidget);

      final season = (await world.seasons.getActiveSeason())!;
      final gym = season.rules.firstWhere((rule) => rule.id == 'rule_1');
      expect((gym.scoring as FixedScoring).points, 3);
    });

    testWidgets('deleting a rule says so instead of crashing', (tester) async {
      final world = await pumpScreen(
        tester,
        const SeasonRuleEditScreen(
          seasonId: Fixture.seasonId,
          ruleId: 'rule_1',
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.seasonLocked), findsOneWidget);
      expect((await world.seasons.getActiveSeason())!.rules, hasLength(5));
    });

    testWidgets('adding a rule says so instead of crashing', (tester) async {
      final world = await pumpScreen(
        tester,
        const SeasonRuleEditScreen(
          seasonId: Fixture.seasonId,
          ruleId: AppRoutes.newRuleId,
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.seasonRuleName),
        'Rowing',
      );
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.save));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.seasonLocked), findsOneWidget);
      expect((await world.seasons.getActiveSeason())!.rules, hasLength(5));
    });
  });
}
