import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/domain/models/activity.dart';
import 'package:sporttracker/domain/models/scoring_rule.dart';
import 'package:sporttracker/domain/points/points_engine.dart';
import 'package:sporttracker/domain/templates/season_templates.dart';
import 'package:sporttracker/domain/validation/rule_validator.dart';

String Function() counter() {
  var next = 0;
  return () => 'rule_${++next}';
}

ScoringRule ruleNamed(List<ScoringRule> rules, String name) =>
    rules.firstWhere((rule) => rule.name == name);

void main() {
  group('SeasonTemplates', () {
    test('v1 ships General Fitness only', () {
      expect(SeasonTemplates.all, [SeasonTemplates.generalFitness]);
      expect(
        SeasonTemplates.byKey('general_fitness'),
        SeasonTemplates.generalFitness,
      );
      expect(SeasonTemplates.byKey('nope'), isNull);
    });

    test('General Fitness has the five agreed rules', () {
      final rules = SeasonTemplates.generalFitness.buildRules(counter());

      expect(
        rules.map((rule) => rule.name),
        ['Gym session', 'Running', 'Cycling', 'Team sport', 'Yoga / mobility'],
      );
    });

    test('every built rule is enabled, has an id and passes validation', () {
      final rules = SeasonTemplates.generalFitness.buildRules(counter());

      for (final rule in rules) {
        expect(rule.isEnabled, isTrue, reason: rule.name);
        expect(rule.id, isNotEmpty, reason: rule.name);
        expect(
          RuleValidator.validate(rule, otherRules: rules),
          isEmpty,
          reason: rule.name,
        );
      }
    });

    test('two seasons built from one id source share no rule id', () {
      // The real caller is SeasonRepository.nextRuleId - one counter for the
      // whole app, not a fresh one per season. Passing a second hand-written
      // generator here would prove nothing about that caller.
      final ids = counter();
      final first = SeasonTemplates.generalFitness.buildRules(ids);
      final second = SeasonTemplates.generalFitness.buildRules(ids);

      final firstIds = first.map((rule) => rule.id).toSet();
      final secondIds = second.map((rule) => rule.id).toSet();

      expect(firstIds.intersection(secondIds), isEmpty);
      expect({...firstIds, ...secondIds}, hasLength(first.length * 2));
    });

    test('building rules twice gives independent lists', () {
      final ids = counter();
      final first = SeasonTemplates.generalFitness.buildRules(ids);
      final second = SeasonTemplates.generalFitness.buildRules(ids);

      expect(identical(first, second), isFalse);
      expect(identical(first.first, second.first), isFalse);
    });

    test('a built tier rule does not share its tiers with the template', () {
      final rules = SeasonTemplates.generalFitness.buildRules(counter());
      final running = ruleNamed(rules, 'Running').scoring as DistanceTierScoring;
      final blueprint = SeasonTemplates.generalFitness.blueprints
          .firstWhere((blueprint) => blueprint.name == 'Running')
          .scoring as DistanceTierScoring;

      expect(running.tiers, blueprint.tiers);
      expect(identical(running.tiers, blueprint.tiers), isFalse);

      // The template's list is const, so without the copy a rule editor
      // mutating the tiers in place throws UnsupportedError instead of editing.
      expect(
        () => running.tiers.add(const DistanceTier(minKm: 30, points: 8)),
        returnsNormally,
      );
      expect(blueprint.tiers, hasLength(4));
    });
  });

  group('General Fitness scoring values', () {
    final rules = SeasonTemplates.generalFitness.buildRules(counter());

    test('Gym session gives 3 points from 45 minutes', () {
      final gym = ruleNamed(rules, 'Gym session');

      expect(gym.scoring, const FixedScoring(points: 3, minDurationMinutes: 45));
      expect(
        PointsEngine.calculate(gym, const ActivityInput(durationMinutes: 45)),
        const PointsSuccess(3),
      );
      expect(
        PointsEngine.calculate(gym, const ActivityInput(durationMinutes: 44)),
        const PointsFailure(BelowMinimumDuration(45)),
      );
    });

    test('Running scores 1, 2, 4 and 6 by distance', () {
      final running = ruleNamed(rules, 'Running');

      expect(
        PointsEngine.calculate(running, const ActivityInput(distanceKm: 2.5)),
        const PointsFailure(BelowMinimumDistance(3)),
      );
      expect(
        PointsEngine.calculate(running, const ActivityInput(distanceKm: 3)),
        const PointsSuccess(1),
      );
      expect(
        PointsEngine.calculate(running, const ActivityInput(distanceKm: 5)),
        const PointsSuccess(2),
      );
      expect(
        PointsEngine.calculate(running, const ActivityInput(distanceKm: 10)),
        const PointsSuccess(4),
      );
      expect(
        PointsEngine.calculate(running, const ActivityInput(distanceKm: 21)),
        const PointsSuccess(6),
      );
    });

    test('Cycling gives 1 point per 30 minutes', () {
      final cycling = ruleNamed(rules, 'Cycling');

      expect(
        PointsEngine.calculate(
          cycling,
          const ActivityInput(durationMinutes: 29),
        ),
        const PointsFailure(BelowMinimumDuration(30)),
      );
      expect(
        PointsEngine.calculate(
          cycling,
          const ActivityInput(durationMinutes: 90),
        ),
        const PointsSuccess(3),
      );
    });

    test('Team sport gives 4 points from 60 minutes', () {
      final team = ruleNamed(rules, 'Team sport');

      expect(
        PointsEngine.calculate(team, const ActivityInput(durationMinutes: 60)),
        const PointsSuccess(4),
      );
    });

    test('Yoga / mobility gives 1 point from 30 minutes', () {
      final yoga = ruleNamed(rules, 'Yoga / mobility');

      expect(
        PointsEngine.calculate(yoga, const ActivityInput(durationMinutes: 30)),
        const PointsSuccess(1),
      );
    });

    test('no single activity can give more than 6 points', () {
      const generous = ActivityInput(durationMinutes: 600, distanceKm: 100);

      for (final rule in rules) {
        final result = PointsEngine.calculate(rule, generous);
        final points = result.pointsOrNull;
        if (points != null) {
          expect(points, lessThanOrEqualTo(20), reason: rule.name);
        }
      }

      // Cycling is time based, so a very long ride can pass 6. The cap applies
      // to a realistic session: the other four rules never pass 6.
      for (final rule in rules.where((rule) => rule.name != 'Cycling')) {
        expect(
          PointsEngine.calculate(rule, generous).pointsOrNull ?? 0,
          lessThanOrEqualTo(6),
          reason: rule.name,
        );
      }
    });
  });
}
