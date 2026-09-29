import '../models/activity.dart';
import '../models/scoring_rule.dart';

/// Why an activity could not be scored.
sealed class PointsError {
  const PointsError();
}

/// The rule is switched off in the season.
final class RuleDisabled extends PointsError {
  const RuleDisabled();

  @override
  bool operator ==(Object other) => other is RuleDisabled;

  @override
  int get hashCode => (RuleDisabled).hashCode;

  @override
  String toString() => 'RuleDisabled()';
}

/// The rule needs a duration and none was given.
final class DurationRequired extends PointsError {
  const DurationRequired();

  @override
  bool operator ==(Object other) => other is DurationRequired;

  @override
  int get hashCode => (DurationRequired).hashCode;

  @override
  String toString() => 'DurationRequired()';
}

/// The activity was shorter than the rule allows.
final class BelowMinimumDuration extends PointsError {
  const BelowMinimumDuration(this.minimumMinutes);

  final int minimumMinutes;

  @override
  bool operator ==(Object other) =>
      other is BelowMinimumDuration && other.minimumMinutes == minimumMinutes;

  @override
  int get hashCode => Object.hash(BelowMinimumDuration, minimumMinutes);

  @override
  String toString() => 'BelowMinimumDuration($minimumMinutes)';
}

/// The rule needs a distance and none was given.
final class DistanceRequired extends PointsError {
  const DistanceRequired();

  @override
  bool operator ==(Object other) => other is DistanceRequired;

  @override
  int get hashCode => (DistanceRequired).hashCode;

  @override
  String toString() => 'DistanceRequired()';
}

/// The distance was below the lowest tier of the rule.
final class BelowMinimumDistance extends PointsError {
  const BelowMinimumDistance(this.minimumKm);

  final double minimumKm;

  @override
  bool operator ==(Object other) =>
      other is BelowMinimumDistance && other.minimumKm == minimumKm;

  @override
  int get hashCode => Object.hash(BelowMinimumDistance, minimumKm);

  @override
  String toString() => 'BelowMinimumDistance($minimumKm)';
}

/// The outcome of scoring one activity.
sealed class PointsResult {
  const PointsResult();

  /// The points when the activity scored, otherwise null.
  int? get pointsOrNull => switch (this) {
        PointsSuccess(:final points) => points,
        PointsFailure() => null,
      };

  /// The reason when the activity did not score, otherwise null.
  PointsError? get errorOrNull => switch (this) {
        PointsSuccess() => null,
        PointsFailure(:final error) => error,
      };
}

/// The activity scored [points].
final class PointsSuccess extends PointsResult {
  const PointsSuccess(this.points);

  final int points;

  @override
  bool operator ==(Object other) =>
      other is PointsSuccess && other.points == points;

  @override
  int get hashCode => Object.hash(PointsSuccess, points);

  @override
  String toString() => 'PointsSuccess($points)';
}

/// The activity did not score, because of [error].
final class PointsFailure extends PointsResult {
  const PointsFailure(this.error);

  final PointsError error;

  @override
  bool operator ==(Object other) =>
      other is PointsFailure && other.error == error;

  @override
  int get hashCode => Object.hash(PointsFailure, error);

  @override
  String toString() => 'PointsFailure($error)';
}

/// Works out the points for one activity against one rule.
///
/// This is the only place points are calculated. The log screen uses it for the
/// live preview, and the repository uses it again when the activity is saved.
abstract final class PointsEngine {
  /// Scores [input] against [rule].
  static PointsResult calculate(ScoringRule rule, ActivityInput input) {
    if (!rule.isEnabled) {
      return const PointsFailure(RuleDisabled());
    }

    switch (rule.scoring) {
      case FixedScoring(:final points, :final minDurationMinutes):
        if (minDurationMinutes != null) {
          final duration = input.durationMinutes;
          if (duration == null) {
            return const PointsFailure(DurationRequired());
          }
          if (duration < minDurationMinutes) {
            return PointsFailure(BelowMinimumDuration(minDurationMinutes));
          }
        }
        return PointsSuccess(points);

      case TimeBasedScoring(
          :final pointsPerBlock,
          :final minutesPerBlock,
          :final minDurationMinutes,
        ):
        final duration = input.durationMinutes;
        if (duration == null) {
          return const PointsFailure(DurationRequired());
        }
        if (duration < minDurationMinutes) {
          return PointsFailure(BelowMinimumDuration(minDurationMinutes));
        }
        if (minutesPerBlock < 1) {
          // RuleValidator rejects a block size below 1, so this only happens
          // for a rule that was never validated - the live preview on the log
          // and rule-edit screens scores an unsaved rule as it is typed. Fail
          // rather than let `~/ 0` throw, mirroring the empty-tiers guard below.
          return PointsFailure(BelowMinimumDuration(minDurationMinutes));
        }
        // Only whole blocks count.
        final blocks = duration ~/ minutesPerBlock;
        return PointsSuccess(blocks * pointsPerBlock);

      case DistanceTierScoring(:final tiers):
        final distance = input.distanceKm;
        if (distance == null) {
          return const PointsFailure(DistanceRequired());
        }
        if (tiers.isEmpty) {
          // RuleValidator rejects a tier rule with no tiers, so this only
          // happens for a rule that was never validated. No distance can score.
          return const PointsFailure(BelowMinimumDistance(double.infinity));
        }
        final highestFirst = DistanceTierScoring(tiers: tiers).tiersHighestFirst;
        for (final tier in highestFirst) {
          if (distance >= tier.minKm) {
            return PointsSuccess(tier.points);
          }
        }
        // Below every tier: the activity does not count.
        final lowest = highestFirst.last.minKm;
        return PointsFailure(BelowMinimumDistance(lowest));
    }
  }
}
