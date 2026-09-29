import '../models/scoring_rule.dart';

/// What can be wrong with a scoring rule.
enum RuleValidationError {
  /// The name is empty or only spaces.
  nameRequired,

  /// Another rule in the challenge already has this name.
  nameNotUnique,

  /// A points value is outside 0 to 100.
  pointsOutOfRange,

  /// A minimum duration was set to zero or less.
  minDurationNotPositive,

  /// A time block must be at least one minute long.
  minutesPerBlockTooSmall,

  /// The minimum duration is shorter than one block, so the rule can never
  /// score.
  minDurationBelowBlock,

  /// A distance rule has no tiers.
  tiersRequired,

  /// A tier starts at zero km or less.
  tierDistanceNotPositive,

  /// Two tiers start at the same distance.
  tierDistanceNotUnique,

  /// A longer distance gives fewer points than a shorter one.
  tierPointsDecreasing,
}

/// The lowest and highest points a rule may award.
const int minRulePoints = 0;
const int maxRulePoints = 100;

/// Checks that one scoring rule makes sense on its own and inside its challenge.
abstract final class RuleValidator {
  /// Returns every problem with [rule]. An empty list means the rule is good.
  ///
  /// [otherRules] are the rules the challenge already has, not counting [rule]
  /// itself. They are used for the name uniqueness check.
  static List<RuleValidationError> validate(
    ScoringRule rule, {
    List<ScoringRule> otherRules = const [],
  }) {
    final errors = <RuleValidationError>[];

    final name = rule.name.trim();
    if (name.isEmpty) {
      errors.add(RuleValidationError.nameRequired);
    } else {
      final lower = name.toLowerCase();
      final clash = otherRules
          .where((other) => other.id != rule.id)
          .any((other) => other.name.trim().toLowerCase() == lower);
      if (clash) {
        errors.add(RuleValidationError.nameNotUnique);
      }
    }

    switch (rule.scoring) {
      case FixedScoring(:final points, :final minDurationMinutes):
        if (!_pointsInRange(points)) {
          errors.add(RuleValidationError.pointsOutOfRange);
        }
        if (minDurationMinutes != null && minDurationMinutes < 1) {
          errors.add(RuleValidationError.minDurationNotPositive);
        }

      case TimeBasedScoring(
          :final pointsPerBlock,
          :final minutesPerBlock,
          :final minDurationMinutes,
        ):
        if (!_pointsInRange(pointsPerBlock)) {
          errors.add(RuleValidationError.pointsOutOfRange);
        }
        if (minutesPerBlock < 1) {
          errors.add(RuleValidationError.minutesPerBlockTooSmall);
        }
        if (minDurationMinutes < 1) {
          errors.add(RuleValidationError.minDurationNotPositive);
        } else if (minutesPerBlock >= 1 && minDurationMinutes < minutesPerBlock) {
          errors.add(RuleValidationError.minDurationBelowBlock);
        }

      case DistanceTierScoring(:final tiers):
        if (tiers.isEmpty) {
          errors.add(RuleValidationError.tiersRequired);
          break;
        }
        if (tiers.any((tier) => !_pointsInRange(tier.points))) {
          errors.add(RuleValidationError.pointsOutOfRange);
        }
        if (tiers.any((tier) => tier.minKm <= 0)) {
          errors.add(RuleValidationError.tierDistanceNotPositive);
        }
        final distances = tiers.map((tier) => tier.minKm).toSet();
        if (distances.length != tiers.length) {
          errors.add(RuleValidationError.tierDistanceNotUnique);
        }
        final ordered = DistanceTierScoring(tiers: tiers).tiersLowestFirst;
        for (var i = 1; i < ordered.length; i++) {
          if (ordered[i].points < ordered[i - 1].points) {
            errors.add(RuleValidationError.tierPointsDecreasing);
            break;
          }
        }
    }

    return errors;
  }

  /// True when [rule] has no problems.
  static bool isValid(
    ScoringRule rule, {
    List<ScoringRule> otherRules = const [],
  }) =>
      validate(rule, otherRules: otherRules).isEmpty;

  static bool _pointsInRange(int points) =>
      points >= minRulePoints && points <= maxRulePoints;
}
