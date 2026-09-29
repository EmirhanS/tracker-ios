import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/domain/models/scoring_rule.dart';
import 'package:sporttracker/domain/models/season.dart';
import 'package:sporttracker/features/season/scoring_rules_screen.dart';

import '../app_harness.dart';
import '../fixtures.dart';

/// Signs [playerName] in and opens the read-only rules screen.
Future<TestWorld> openScoringRules(
  WidgetTester tester,
  String playerName, {
  List<Season>? seasons,
}) async {
  final world = await pumpWorld(tester, seasons: seasons);
  await signIn(tester, playerName);
  await tester.tap(find.byIcon(Icons.rule));
  await settle(tester);
  return world;
}

/// The row for [rule], found by its name.
Finder _tileOf(ScoringRule rule) => find.ancestor(
      of: find.text(rule.name),
      matching: find.byType(ScoringRuleTile),
    );

void main() {
  group('Everyone can read the rules', () {
    testWidgets('the captain can open the screen', (tester) async {
      await openScoringRules(tester, Fixture.mira.name);

      expect(find.text(AppStrings.scoringRulesTitle), findsOneWidget);
      expect(find.byType(ScoringRuleTile), findsNWidgets(Fixture.rules.length));
    });

    testWidgets('a player who is not the captain can too', (tester) async {
      await openScoringRules(tester, Fixture.ben.name);

      expect(find.text(AppStrings.scoringRulesTitle), findsOneWidget);
      expect(find.byType(ScoringRuleTile), findsNWidgets(Fixture.rules.length));
      for (final rule in Fixture.rules) {
        expect(find.text(rule.name), findsOneWidget);
      }
    });

    testWidgets('the season it belongs to is named', (tester) async {
      await openScoringRules(tester, Fixture.dana.name);

      expect(find.textContaining('Test Season'), findsOneWidget);
    });
  });

  group('The screen is read only', () {
    testWidgets('no row can be tapped and nothing can be switched',
        (tester) async {
      await openScoringRules(tester, Fixture.mira.name);

      // Not even the captain gets an edit affordance here: the rules of a
      // running season are locked, and setup is where rules are changed.
      expect(find.byType(Switch), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.text(AppStrings.seasonRulesAdd), findsNothing);
      expect(find.text(AppStrings.seasonRuleDelete), findsNothing);

      final tiles = tester.widgetList<ScoringRuleTile>(
        find.byType(ScoringRuleTile),
      );
      for (final tile in tiles) {
        expect(tile.onTap, isNull, reason: '${tile.rule.name} must not open');
      }
    });

    testWidgets('a non-captain sees exactly the same screen', (tester) async {
      await openScoringRules(tester, Fixture.ben.name);

      expect(find.byType(Switch), findsNothing);
      final tiles = tester.widgetList<ScoringRuleTile>(
        find.byType(ScoringRuleTile),
      );
      for (final tile in tiles) {
        expect(tile.onTap, isNull);
      }
    });
  });

  group('Each scoring type reads correctly', () {
    testWidgets('fixed points with a minimum duration', (tester) async {
      await openScoringRules(tester, Fixture.mira.name);

      expect(
        find.descendant(
          of: _tileOf(Fixture.gym),
          matching: find.text('3 points · from 45 min'),
        ),
        findsOneWidget,
      );
      expect(
        AppStrings.describeScoring(Fixture.gym.scoring),
        '3 points · from 45 min',
      );
    });

    testWidgets('fixed points with no minimum', (tester) async {
      await openScoringRules(tester, Fixture.mira.name);

      expect(
        find.descendant(
          of: _tileOf(Fixture.stretching),
          matching: find.text('2 points'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('points per block of time', (tester) async {
      await openScoringRules(tester, Fixture.mira.name);

      expect(
        find.descendant(
          of: _tileOf(Fixture.cycling),
          matching: find.text('1 point per 30 min · from 30 min'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('points by distance, lowest tier first', (tester) async {
      await openScoringRules(tester, Fixture.mira.name);

      expect(
        find.descendant(
          of: _tileOf(Fixture.running),
          matching: find.text('3 km → 1 · 5 km → 2 · 10 km → 4'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a switched-off rule is shown, and marked off', (tester) async {
      await openScoringRules(tester, Fixture.mira.name);

      expect(find.text(Fixture.swimming.name), findsOneWidget);
      expect(
        find.descendant(
          of: _tileOf(Fixture.swimming),
          matching: find.text(AppStrings.scoringRulesDisabled),
        ),
        findsOneWidget,
      );
      // Only the switched-off rule carries the badge.
      expect(find.text(AppStrings.scoringRulesDisabled), findsOneWidget);
    });
  });

  group('Empty states', () {
    testWidgets('no season at all', (tester) async {
      await pumpWorld(tester, seasons: const [], activities: const []);
      await signIn(tester, Fixture.mira.name);
      await tester.tap(find.byIcon(Icons.rule));
      await settle(tester);

      expect(find.text(AppStrings.dashboardNoSeasonTitle), findsOneWidget);
      expect(find.byType(ScoringRuleTile), findsNothing);
    });

    testWidgets('a season with no rules', (tester) async {
      await pumpWorld(
        tester,
        seasons: [Fixture.season().copyWith(rules: const [])],
        activities: const [],
      );
      await signIn(tester, Fixture.mira.name);
      await tester.tap(find.byIcon(Icons.rule));
      await settle(tester);

      expect(find.text(AppStrings.scoringRulesEmptyTitle), findsOneWidget);
    });
  });
}
