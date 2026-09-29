import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/domain/models/scoring_rule.dart';
import 'package:sporttracker/domain/validation/rule_validator.dart';

ScoringRule ruleWith(
  Scoring scoring, {
  String id = 'rule_1',
  String name = 'Test rule',
}) {
  return ScoringRule(id: id, name: name, scoring: scoring);
}

void main() {
  group('RuleValidator, name', () {
    test('a good rule has no errors', () {
      final rule = ruleWith(const FixedScoring(points: 3));

      expect(RuleValidator.validate(rule), isEmpty);
      expect(RuleValidator.isValid(rule), isTrue);
    });

    test('an empty name is rejected', () {
      final rule = ruleWith(const FixedScoring(points: 3), name: '');

      expect(
        RuleValidator.validate(rule),
        contains(RuleValidationError.nameRequired),
      );
    });

    test('a name of only spaces is rejected', () {
      final rule = ruleWith(const FixedScoring(points: 3), name: '   ');

      expect(
        RuleValidator.validate(rule),
        contains(RuleValidationError.nameRequired),
      );
    });

    test('a name used by another rule is rejected, ignoring case', () {
      final rule = ruleWith(const FixedScoring(points: 3), name: 'Running');
      final other = ruleWith(
        const FixedScoring(points: 1),
        id: 'rule_2',
        name: 'running',
      );

      expect(
        RuleValidator.validate(rule, otherRules: [other]),
        contains(RuleValidationError.nameNotUnique),
      );
    });

    test('a rule does not clash with itself', () {
      final rule = ruleWith(const FixedScoring(points: 3), name: 'Running');

      expect(RuleValidator.validate(rule, otherRules: [rule]), isEmpty);
    });

    test('names are compared after trimming', () {
      final rule = ruleWith(const FixedScoring(points: 3), name: ' Running ');
      final other = ruleWith(
        const FixedScoring(points: 1),
        id: 'rule_2',
        name: 'Running',
      );

      expect(
        RuleValidator.validate(rule, otherRules: [other]),
        contains(RuleValidationError.nameNotUnique),
      );
    });
  });

  group('RuleValidator, fixed scoring', () {
    test('zero points is allowed', () {
      expect(RuleValidator.validate(ruleWith(const FixedScoring(points: 0))),
          isEmpty);
    });

    test('one hundred points is allowed', () {
      expect(RuleValidator.validate(ruleWith(const FixedScoring(points: 100))),
          isEmpty);
    });

    test('negative points are rejected', () {
      expect(
        RuleValidator.validate(ruleWith(const FixedScoring(points: -1))),
        contains(RuleValidationError.pointsOutOfRange),
      );
    });

    test('more than one hundred points is rejected', () {
      expect(
        RuleValidator.validate(ruleWith(const FixedScoring(points: 101))),
        contains(RuleValidationError.pointsOutOfRange),
      );
    });

    test('a minimum duration of zero is rejected', () {
      expect(
        RuleValidator.validate(
          ruleWith(const FixedScoring(points: 3, minDurationMinutes: 0)),
        ),
        contains(RuleValidationError.minDurationNotPositive),
      );
    });
  });

  group('RuleValidator, time based scoring', () {
    test('a sensible time rule passes', () {
      final rule = ruleWith(
        const TimeBasedScoring(
          pointsPerBlock: 1,
          minutesPerBlock: 30,
          minDurationMinutes: 30,
        ),
      );

      expect(RuleValidator.validate(rule), isEmpty);
    });

    test('a block shorter than one minute is rejected', () {
      final rule = ruleWith(
        const TimeBasedScoring(
          pointsPerBlock: 1,
          minutesPerBlock: 0,
          minDurationMinutes: 30,
        ),
      );

      expect(
        RuleValidator.validate(rule),
        contains(RuleValidationError.minutesPerBlockTooSmall),
      );
    });

    test('a minimum shorter than one block is rejected', () {
      final rule = ruleWith(
        const TimeBasedScoring(
          pointsPerBlock: 1,
          minutesPerBlock: 30,
          minDurationMinutes: 20,
        ),
      );

      expect(
        RuleValidator.validate(rule),
        contains(RuleValidationError.minDurationBelowBlock),
      );
    });

    test('a minimum longer than one block is allowed', () {
      final rule = ruleWith(
        const TimeBasedScoring(
          pointsPerBlock: 1,
          minutesPerBlock: 15,
          minDurationMinutes: 45,
        ),
      );

      expect(RuleValidator.validate(rule), isEmpty);
    });

    test('points per block out of range is rejected', () {
      final rule = ruleWith(
        const TimeBasedScoring(
          pointsPerBlock: 200,
          minutesPerBlock: 30,
          minDurationMinutes: 30,
        ),
      );

      expect(
        RuleValidator.validate(rule),
        contains(RuleValidationError.pointsOutOfRange),
      );
    });
  });

  group('RuleValidator, distance tiers', () {
    test('an ordered ladder passes', () {
      final rule = ruleWith(
        const DistanceTierScoring(
          tiers: [
            DistanceTier(minKm: 3, points: 1),
            DistanceTier(minKm: 5, points: 2),
            DistanceTier(minKm: 10, points: 4),
          ],
        ),
      );

      expect(RuleValidator.validate(rule), isEmpty);
    });

    test('tiers given out of order still pass', () {
      final rule = ruleWith(
        const DistanceTierScoring(
          tiers: [
            DistanceTier(minKm: 10, points: 4),
            DistanceTier(minKm: 3, points: 1),
          ],
        ),
      );

      expect(RuleValidator.validate(rule), isEmpty);
    });

    test('no tiers is rejected', () {
      final rule = ruleWith(const DistanceTierScoring(tiers: []));

      expect(
        RuleValidator.validate(rule),
        contains(RuleValidationError.tiersRequired),
      );
    });

    test('a tier starting at zero km is rejected', () {
      final rule = ruleWith(
        const DistanceTierScoring(
          tiers: [DistanceTier(minKm: 0, points: 1)],
        ),
      );

      expect(
        RuleValidator.validate(rule),
        contains(RuleValidationError.tierDistanceNotPositive),
      );
    });

    test('two tiers at the same distance are rejected', () {
      final rule = ruleWith(
        const DistanceTierScoring(
          tiers: [
            DistanceTier(minKm: 5, points: 1),
            DistanceTier(minKm: 5, points: 2),
          ],
        ),
      );

      expect(
        RuleValidator.validate(rule),
        contains(RuleValidationError.tierDistanceNotUnique),
      );
    });

    test('a longer distance giving fewer points is rejected', () {
      final rule = ruleWith(
        const DistanceTierScoring(
          tiers: [
            DistanceTier(minKm: 3, points: 4),
            DistanceTier(minKm: 10, points: 1),
          ],
        ),
      );

      expect(
        RuleValidator.validate(rule),
        contains(RuleValidationError.tierPointsDecreasing),
      );
    });

    test('equal points on two tiers are allowed', () {
      final rule = ruleWith(
        const DistanceTierScoring(
          tiers: [
            DistanceTier(minKm: 3, points: 2),
            DistanceTier(minKm: 10, points: 2),
          ],
        ),
      );

      expect(RuleValidator.validate(rule), isEmpty);
    });

    test('tier points out of range are rejected', () {
      final rule = ruleWith(
        const DistanceTierScoring(
          tiers: [DistanceTier(minKm: 3, points: 500)],
        ),
      );

      expect(
        RuleValidator.validate(rule),
        contains(RuleValidationError.pointsOutOfRange),
      );
    });
  });
}
