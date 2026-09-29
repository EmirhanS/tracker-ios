import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/domain/models/activity.dart';
import 'package:sporttracker/domain/models/scoring_rule.dart';
import 'package:sporttracker/domain/points/points_engine.dart';

ScoringRule ruleWith(Scoring scoring, {bool isEnabled = true}) {
  return ScoringRule(
    id: 'rule_1',
    name: 'Test rule',
    scoring: scoring,
    isEnabled: isEnabled,
  );
}

void main() {
  group('PointsEngine, disabled rules', () {
    test('a disabled rule never scores', () {
      final rule = ruleWith(const FixedScoring(points: 3), isEnabled: false);

      final result = PointsEngine.calculate(
        rule,
        const ActivityInput(durationMinutes: 90),
      );

      expect(result, const PointsFailure(RuleDisabled()));
    });
  });

  group('PointsEngine, fixed scoring', () {
    test('gives the fixed points when there is no minimum', () {
      final rule = ruleWith(const FixedScoring(points: 4));

      final result = PointsEngine.calculate(rule, const ActivityInput());

      expect(result, const PointsSuccess(4));
    });

    test('needs a duration when a minimum is set', () {
      final rule = ruleWith(
        const FixedScoring(points: 3, minDurationMinutes: 45),
      );

      final result = PointsEngine.calculate(rule, const ActivityInput());

      expect(result, const PointsFailure(DurationRequired()));
    });

    test('rejects a duration below the minimum', () {
      final rule = ruleWith(
        const FixedScoring(points: 3, minDurationMinutes: 45),
      );

      final result = PointsEngine.calculate(
        rule,
        const ActivityInput(durationMinutes: 44),
      );

      expect(result, const PointsFailure(BelowMinimumDuration(45)));
    });

    test('accepts a duration exactly at the minimum', () {
      final rule = ruleWith(
        const FixedScoring(points: 3, minDurationMinutes: 45),
      );

      final result = PointsEngine.calculate(
        rule,
        const ActivityInput(durationMinutes: 45),
      );

      expect(result, const PointsSuccess(3));
    });

    test('a longer activity still gives the same fixed points', () {
      final rule = ruleWith(
        const FixedScoring(points: 3, minDurationMinutes: 45),
      );

      final result = PointsEngine.calculate(
        rule,
        const ActivityInput(durationMinutes: 240),
      );

      expect(result, const PointsSuccess(3));
    });
  });

  group('PointsEngine, time based scoring', () {
    final rule = ruleWith(
      const TimeBasedScoring(
        pointsPerBlock: 1,
        minutesPerBlock: 30,
        minDurationMinutes: 30,
      ),
    );

    test('needs a duration', () {
      final result = PointsEngine.calculate(rule, const ActivityInput());

      expect(result, const PointsFailure(DurationRequired()));
    });

    test('rejects a duration below the minimum', () {
      final result = PointsEngine.calculate(
        rule,
        const ActivityInput(durationMinutes: 29),
      );

      expect(result, const PointsFailure(BelowMinimumDuration(30)));
    });

    test('one whole block gives one block of points', () {
      final result = PointsEngine.calculate(
        rule,
        const ActivityInput(durationMinutes: 30),
      );

      expect(result, const PointsSuccess(1));
    });

    test('part blocks do not count', () {
      final result = PointsEngine.calculate(
        rule,
        const ActivityInput(durationMinutes: 59),
      );

      expect(result, const PointsSuccess(1));
    });

    test('three whole blocks give three blocks of points', () {
      final result = PointsEngine.calculate(
        rule,
        const ActivityInput(durationMinutes: 95),
      );

      expect(result, const PointsSuccess(3));
    });

    test('points per block larger than one multiply up', () {
      final fast = ruleWith(
        const TimeBasedScoring(
          pointsPerBlock: 2,
          minutesPerBlock: 20,
          minDurationMinutes: 20,
        ),
      );

      final result = PointsEngine.calculate(
        fast,
        const ActivityInput(durationMinutes: 65),
      );

      expect(result, const PointsSuccess(6));
    });

    test('the minimum can be longer than one block', () {
      final rule = ruleWith(
        const TimeBasedScoring(
          pointsPerBlock: 1,
          minutesPerBlock: 15,
          minDurationMinutes: 45,
        ),
      );

      expect(
        PointsEngine.calculate(
          rule,
          const ActivityInput(durationMinutes: 30),
        ),
        const PointsFailure(BelowMinimumDuration(45)),
      );
      expect(
        PointsEngine.calculate(
          rule,
          const ActivityInput(durationMinutes: 45),
        ),
        const PointsSuccess(3),
      );
    });
  });

  group('PointsEngine, distance tier scoring', () {
    final running = ruleWith(
      const DistanceTierScoring(
        tiers: [
          DistanceTier(minKm: 3, points: 1),
          DistanceTier(minKm: 5, points: 2),
          DistanceTier(minKm: 10, points: 4),
          DistanceTier(minKm: 15, points: 6),
        ],
      ),
    );

    test('needs a distance', () {
      final result = PointsEngine.calculate(running, const ActivityInput());

      expect(result, const PointsFailure(DistanceRequired()));
    });

    test('below the lowest tier does not count', () {
      final result = PointsEngine.calculate(
        running,
        const ActivityInput(distanceKm: 2.9),
      );

      expect(result, const PointsFailure(BelowMinimumDistance(3)));
    });

    test('exactly on a tier takes that tier', () {
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
        PointsEngine.calculate(running, const ActivityInput(distanceKm: 15)),
        const PointsSuccess(6),
      );
    });

    test('between tiers takes the lower tier', () {
      expect(
        PointsEngine.calculate(running, const ActivityInput(distanceKm: 7.5)),
        const PointsSuccess(2),
      );
      expect(
        PointsEngine.calculate(running, const ActivityInput(distanceKm: 14.9)),
        const PointsSuccess(4),
      );
    });

    test('above the highest tier takes the highest tier', () {
      final result = PointsEngine.calculate(
        running,
        const ActivityInput(distanceKm: 42.2),
      );

      expect(result, const PointsSuccess(6));
    });

    test('tiers out of order still score by threshold', () {
      final messy = ruleWith(
        const DistanceTierScoring(
          tiers: [
            DistanceTier(minKm: 10, points: 4),
            DistanceTier(minKm: 3, points: 1),
            DistanceTier(minKm: 5, points: 2),
          ],
        ),
      );

      expect(
        PointsEngine.calculate(messy, const ActivityInput(distanceKm: 12)),
        const PointsSuccess(4),
      );
      expect(
        PointsEngine.calculate(messy, const ActivityInput(distanceKm: 4)),
        const PointsSuccess(1),
      );
      expect(
        PointsEngine.calculate(messy, const ActivityInput(distanceKm: 1)),
        const PointsFailure(BelowMinimumDistance(3)),
      );
    });

    test('a rule with no tiers can never score', () {
      final empty = ruleWith(const DistanceTierScoring(tiers: []));

      final result = PointsEngine.calculate(
        empty,
        const ActivityInput(distanceKm: 100),
      );

      expect(result, isA<PointsFailure>());
      expect((result as PointsFailure).error, isA<BelowMinimumDistance>());
    });
  });

  group('PointsResult helpers', () {
    test('pointsOrNull and errorOrNull read the right side', () {
      const success = PointsSuccess(5);
      const failure = PointsFailure(RuleDisabled());

      expect(success.pointsOrNull, 5);
      expect(success.errorOrNull, isNull);
      expect(failure.pointsOrNull, isNull);
      expect(failure.errorOrNull, const RuleDisabled());
    });
  });

  group('Scoring input requirements', () {
    test('fixed without a minimum needs nothing', () {
      const scoring = FixedScoring(points: 2);

      expect(scoring.requiresDuration, isFalse);
      expect(scoring.requiresDistance, isFalse);
    });

    test('fixed with a minimum needs a duration', () {
      const scoring = FixedScoring(points: 2, minDurationMinutes: 30);

      expect(scoring.requiresDuration, isTrue);
      expect(scoring.requiresDistance, isFalse);
    });

    test('time based needs a duration', () {
      const scoring = TimeBasedScoring(
        pointsPerBlock: 1,
        minutesPerBlock: 30,
        minDurationMinutes: 30,
      );

      expect(scoring.requiresDuration, isTrue);
      expect(scoring.requiresDistance, isFalse);
    });

    test('distance tiers need a distance', () {
      const scoring = DistanceTierScoring(
        tiers: [DistanceTier(minKm: 3, points: 1)],
      );

      expect(scoring.requiresDuration, isFalse);
      expect(scoring.requiresDistance, isTrue);
    });
  });

  group('PointsEngine, rules that were never validated', () {
    // The log screen and the rule editor score an unsaved rule live as it is
    // typed, so the engine is reachable with values RuleValidator rejects.
    // It has to fail, not throw.

    test('a block size of zero fails instead of dividing by zero', () {
      final rule = ruleWith(
        const TimeBasedScoring(
          pointsPerBlock: 1,
          minutesPerBlock: 0,
          minDurationMinutes: 30,
        ),
      );

      expect(
        PointsEngine.calculate(rule, const ActivityInput(durationMinutes: 60)),
        const PointsFailure(BelowMinimumDuration(30)),
      );
    });

    test('a negative block size fails too', () {
      final rule = ruleWith(
        const TimeBasedScoring(
          pointsPerBlock: 1,
          minutesPerBlock: -5,
          minDurationMinutes: 10,
        ),
      );

      expect(
        PointsEngine.calculate(rule, const ActivityInput(durationMinutes: 60)),
        const PointsFailure(BelowMinimumDuration(10)),
      );
    });

    test('the below-minimum check still comes first', () {
      final rule = ruleWith(
        const TimeBasedScoring(
          pointsPerBlock: 1,
          minutesPerBlock: 0,
          minDurationMinutes: 30,
        ),
      );

      expect(
        PointsEngine.calculate(rule, const ActivityInput(durationMinutes: 29)),
        const PointsFailure(BelowMinimumDuration(30)),
      );
    });

    test('a block size of one still scores normally', () {
      final rule = ruleWith(
        const TimeBasedScoring(
          pointsPerBlock: 2,
          minutesPerBlock: 1,
          minDurationMinutes: 1,
        ),
      );

      expect(
        PointsEngine.calculate(rule, const ActivityInput(durationMinutes: 3)),
        const PointsSuccess(6),
      );
    });
  });
}
