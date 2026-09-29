import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/data/in_memory/id_generator.dart';
import 'package:sporttracker/domain/models/season.dart';
import 'package:sporttracker/domain/templates/season_templates.dart';

import '../app_harness.dart';

Future<void> createSeason(WidgetTester tester, {String name = 'Spring'}) async {
  await tester.tap(find.text(AppStrings.dashboardSetUpSeason));
  await settle(tester);

  await tester.enterText(find.byType(TextField).first, name);
  await settle(tester);
  await tapButton(tester, AppStrings.seasonCreate);
}

void main() {
  group('Empty states and captain gating', () {
    testWidgets('the captain sees the setup button when no season runs',
        (tester) async {
      await pumpAppWithoutSeason(tester);
      await signIn(tester, 'Mia Halvorsen');

      expect(find.text(AppStrings.dashboardNoSeasonTitle), findsOneWidget);
      expect(find.text(AppStrings.dashboardSetUpSeason), findsOneWidget);
    });

    testWidgets('a player who is not the captain gets no setup button',
        (tester) async {
      final repositories = await pumpAppWithoutSeason(tester);

      // Mia sets a season up, so Mia is the captain.
      await repositories.seasons.createDraft(
        name: 'Spring 2027',
        startDate: testToday,
        endDate: DateTime(2027, 6, 30),
        captainId: 'player_1',
      );
      await settle(tester);

      await signIn(tester, 'Jonas Berg');

      expect(find.text(AppStrings.dashboardNoSeasonTitle), findsOneWidget);
      expect(find.text(AppStrings.dashboardSetUpSeason), findsNothing);
      expect(find.text(AppStrings.dashboardNoSeasonBody), findsOneWidget);
    });

    testWidgets('the log screen also offers setup to the captain',
        (tester) async {
      await pumpAppWithoutSeason(tester);
      await signIn(tester, 'Mia Halvorsen');

      await tester.tap(find.text(AppStrings.navLog));
      await settle(tester);

      expect(find.text(AppStrings.dashboardSetUpSeason), findsOneWidget);
    });
  });

  group('Season setup flow', () {
    testWidgets('create, take the template, then start the season',
        (tester) async {
      final repositories = await pumpAppWithoutSeason(tester);
      await signIn(tester, 'Mia Halvorsen');

      await createSeason(tester, name: 'Spring 2027');

      // The draft exists and the template step is showing.
      final drafts = await repositories.seasons.getAll();
      expect(drafts, hasLength(1));
      expect(drafts.single.name, 'Spring 2027');
      expect(drafts.single.status, SeasonStatus.draft);
      expect(find.text('General Fitness'), findsOneWidget);

      await tapButton(tester, AppStrings.seasonTemplateUse);

      // The five template rules are copied in.
      expect(find.text('Gym session'), findsOneWidget);
      expect(find.text('Cycling'), findsOneWidget);
      expect((await repositories.seasons.getAll()).single.rules, hasLength(5));

      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.seasonRulesReview),
      );
      await settle(tester);

      expect(find.text('Spring 2027'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.seasonReviewStart),
      );
      await settle(tester);

      // Starting asks first.
      expect(find.text(AppStrings.seasonReviewConfirmTitle), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.seasonReviewConfirmAction),
      );
      await settle(tester);

      final season = await repositories.seasons.getActiveSeason();
      expect(season, isNotNull);
      expect(season!.isLocked, isTrue);
      expect(find.text('Hi Mia Halvorsen'), findsOneWidget);
      expect(find.text(AppStrings.dashboardSeasonPoints), findsOneWidget);
    });

    testWidgets('a rule can be switched off before the season starts',
        (tester) async {
      final repositories = await pumpAppWithoutSeason(tester);
      await signIn(tester, 'Mia Halvorsen');
      await createSeason(tester);
      await tapButton(tester, AppStrings.seasonTemplateUse);

      await tester.tap(find.byType(Switch).first);
      await settle(tester);

      final season = (await repositories.seasons.getAll()).single;
      expect(season.rules.first.isEnabled, isFalse);
      expect(season.enabledRules, hasLength(4));
    });

    testWidgets('a rule can be edited before the season starts',
        (tester) async {
      final repositories = await pumpAppWithoutSeason(tester);
      await signIn(tester, 'Mia Halvorsen');
      await createSeason(tester);
      await tapButton(tester, AppStrings.seasonTemplateUse);

      await tester.tap(find.text('Gym session'));
      await settle(tester);

      // The form is showing, not the not-found fallback: only the form has a
      // scoring type picker.
      expect(find.text(AppStrings.seasonRuleScoringType), findsOneWidget);
      expect(find.text(AppStrings.seasonRuleEditTitle), findsOneWidget);

      // Points is the first number field for a fixed rule.
      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.seasonRulePoints),
        '5',
      );
      await settle(tester);
      await tapButton(tester, AppStrings.save);

      final season = (await repositories.seasons.getAll()).single;
      final gym = season.rules.firstWhere((rule) => rule.name == 'Gym session');
      expect(AppStrings.describeScoring(gym.scoring), startsWith('5 points'));
    });

    testWidgets('a rule with a name another rule uses cannot be saved',
        (tester) async {
      final repositories = await pumpAppWithoutSeason(tester);
      await signIn(tester, 'Mia Halvorsen');
      await createSeason(tester);
      await tapButton(tester, AppStrings.seasonTemplateUse);

      await tester.tap(find.text('Gym session'));
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.seasonRuleName),
        'Cycling',
      );
      await settle(tester);
      await tapButton(tester, AppStrings.save);

      expect(
        find.text('Another rule already uses this name.'),
        findsWidgets,
      );
      final season = (await repositories.seasons.getAll()).single;
      expect(
        season.rules.where((rule) => rule.name == 'Cycling'),
        hasLength(1),
      );
    });

    testWidgets('a season with every rule off cannot be reviewed',
        (tester) async {
      await pumpAppWithoutSeason(tester);
      await signIn(tester, 'Mia Halvorsen');
      await createSeason(tester);
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
    });
  });

  group('Leaving setup part way through', () {
    testWidgets('the setup button goes back to the draft, not to a second one',
        (tester) async {
      final repositories = await pumpAppWithoutSeason(tester);

      // A draft Mia started earlier and never finished.
      final ids = IdGenerator();
      await repositories.seasons.createDraft(
        name: 'Spring 2027',
        startDate: testToday,
        endDate: DateTime(2027, 6, 30),
        captainId: 'player_1',
        rules: SeasonTemplates.generalFitness.buildRules(
          ids.forPrefix('rule'),
        ),
      );
      await settle(tester);

      await signIn(tester, 'Mia Halvorsen');
      await tester.tap(find.text(AppStrings.dashboardSetUpSeason));
      await settle(tester);

      // Back on the rules of the same draft, and still only one season.
      expect(find.text('Gym session'), findsOneWidget);
      expect(find.text(AppStrings.seasonRulesTitle), findsOneWidget);
      expect(await repositories.seasons.getAll(), hasLength(1));
    });
  });

  group('Scoring rules screen', () {
    testWidgets('every player can read the rules of the running season',
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

  group('An active season is locked', () {
    testWidgets('the seeded season cannot be edited through the repository',
        (tester) async {
      final repositories = await pumpApp(tester);
      final season = (await repositories.seasons.getActiveSeason())!;

      expect(
        () => repositories.seasons.updateSeason(
          season.copyWith(rules: const []),
        ),
        throwsA(isA<Object>()),
      );
    });
  });
}
