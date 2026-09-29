/// How an activity turns into points.
///
/// Each variant also says which inputs the log screen must ask for, through
/// [requiresDuration] and [requiresDistance].
sealed class Scoring {
  const Scoring();

  /// True when the player must enter a duration for this rule.
  bool get requiresDuration;

  /// True when the player must enter a distance for this rule.
  bool get requiresDistance;
}

/// The same number of points every time, with an optional minimum duration.
final class FixedScoring extends Scoring {
  const FixedScoring({required this.points, this.minDurationMinutes});

  final int points;

  /// When set, the activity must last at least this long to count.
  final int? minDurationMinutes;

  @override
  bool get requiresDuration => minDurationMinutes != null;

  @override
  bool get requiresDistance => false;

  FixedScoring copyWith({
    int? points,
    int? minDurationMinutes,
    bool clearMinDuration = false,
  }) {
    return FixedScoring(
      points: points ?? this.points,
      minDurationMinutes:
          clearMinDuration ? null : minDurationMinutes ?? this.minDurationMinutes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FixedScoring &&
          other.points == points &&
          other.minDurationMinutes == minDurationMinutes;

  @override
  int get hashCode => Object.hash(points, minDurationMinutes);

  @override
  String toString() =>
      'FixedScoring(points: $points, minDurationMinutes: $minDurationMinutes)';
}

/// Points for every finished block of time, for example 1 point per 30 minutes.
///
/// Part blocks do not count, so 50 minutes at 1 point per 30 minutes gives 1.
final class TimeBasedScoring extends Scoring {
  const TimeBasedScoring({
    required this.pointsPerBlock,
    required this.minutesPerBlock,
    required this.minDurationMinutes,
  });

  final int pointsPerBlock;
  final int minutesPerBlock;

  /// The activity must last at least this long to count at all.
  final int minDurationMinutes;

  @override
  bool get requiresDuration => true;

  @override
  bool get requiresDistance => false;

  TimeBasedScoring copyWith({
    int? pointsPerBlock,
    int? minutesPerBlock,
    int? minDurationMinutes,
  }) {
    return TimeBasedScoring(
      pointsPerBlock: pointsPerBlock ?? this.pointsPerBlock,
      minutesPerBlock: minutesPerBlock ?? this.minutesPerBlock,
      minDurationMinutes: minDurationMinutes ?? this.minDurationMinutes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeBasedScoring &&
          other.pointsPerBlock == pointsPerBlock &&
          other.minutesPerBlock == minutesPerBlock &&
          other.minDurationMinutes == minDurationMinutes;

  @override
  int get hashCode =>
      Object.hash(pointsPerBlock, minutesPerBlock, minDurationMinutes);

  @override
  String toString() => 'TimeBasedScoring(pointsPerBlock: $pointsPerBlock, '
      'minutesPerBlock: $minutesPerBlock, '
      'minDurationMinutes: $minDurationMinutes)';
}

/// One step of a [DistanceTierScoring] ladder: from [minKm] you get [points].
class DistanceTier {
  const DistanceTier({required this.minKm, required this.points});

  final double minKm;
  final int points;

  DistanceTier copyWith({double? minKm, int? points}) {
    return DistanceTier(
      minKm: minKm ?? this.minKm,
      points: points ?? this.points,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DistanceTier && other.minKm == minKm && other.points == points;

  @override
  int get hashCode => Object.hash(minKm, points);

  @override
  String toString() => 'DistanceTier(minKm: $minKm, points: $points)';
}

/// Points from a ladder of distances. The highest tier the player reaches wins.
///
/// A distance below the lowest tier does not count.
final class DistanceTierScoring extends Scoring {
  const DistanceTierScoring({required this.tiers});

  final List<DistanceTier> tiers;

  /// The tiers ordered from the highest threshold to the lowest.
  List<DistanceTier> get tiersHighestFirst =>
      List<DistanceTier>.of(tiers)..sort((a, b) => b.minKm.compareTo(a.minKm));

  /// The tiers ordered from the lowest threshold to the highest.
  List<DistanceTier> get tiersLowestFirst =>
      List<DistanceTier>.of(tiers)..sort((a, b) => a.minKm.compareTo(b.minKm));

  @override
  bool get requiresDuration => false;

  @override
  bool get requiresDistance => true;

  DistanceTierScoring copyWith({List<DistanceTier>? tiers}) {
    return DistanceTierScoring(tiers: tiers ?? this.tiers);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DistanceTierScoring) return false;
    if (other.tiers.length != tiers.length) return false;
    for (var i = 0; i < tiers.length; i++) {
      if (other.tiers[i] != tiers[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(tiers);

  @override
  String toString() => 'DistanceTierScoring(tiers: $tiers)';
}

/// One scoring rule inside a season, for example "Running" or "Gym session".
class ScoringRule {
  const ScoringRule({
    required this.id,
    required this.name,
    required this.scoring,
    this.emoji,
    this.isEnabled = true,
  });

  final String id;
  final String name;

  /// Shown next to the name. Optional, purely decorative.
  final String? emoji;

  /// Disabled rules stay in the season but cannot be logged against.
  final bool isEnabled;

  final Scoring scoring;

  ScoringRule copyWith({
    String? id,
    String? name,
    String? emoji,
    bool clearEmoji = false,
    bool? isEnabled,
    Scoring? scoring,
  }) {
    return ScoringRule(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: clearEmoji ? null : emoji ?? this.emoji,
      isEnabled: isEnabled ?? this.isEnabled,
      scoring: scoring ?? this.scoring,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoringRule &&
          other.id == id &&
          other.name == name &&
          other.emoji == emoji &&
          other.isEnabled == isEnabled &&
          other.scoring == scoring;

  @override
  int get hashCode => Object.hash(id, name, emoji, isEnabled, scoring);

  @override
  String toString() =>
      'ScoringRule(id: $id, name: $name, isEnabled: $isEnabled, '
      'scoring: $scoring)';
}
