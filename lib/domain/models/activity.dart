/// What the player entered for one activity, before points are worked out.
class ActivityInput {
  const ActivityInput({this.durationMinutes, this.distanceKm});

  final int? durationMinutes;
  final double? distanceKm;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityInput &&
          other.durationMinutes == durationMinutes &&
          other.distanceKm == distanceKm;

  @override
  int get hashCode => Object.hash(durationMinutes, distanceKm);

  @override
  String toString() =>
      'ActivityInput(durationMinutes: $durationMinutes, distanceKm: $distanceKm)';
}

/// One logged activity.
///
/// [points] and [ruleName] are frozen when the activity is logged. Totals are
/// sums over activities, so deleting one takes its points away by itself, and
/// later rule edits never rewrite history.
class Activity {
  const Activity({
    required this.id,
    required this.playerId,
    required this.seasonId,
    required this.ruleId,
    required this.ruleName,
    required this.date,
    required this.points,
    required this.createdAt,
    this.ruleEmoji,
    this.durationMinutes,
    this.distanceKm,
    this.notes,
  });

  final String id;
  final String playerId;
  final String seasonId;

  /// The rule this was logged against, as it was at log time.
  final String ruleId;
  final String ruleName;
  final String? ruleEmoji;

  /// The day the activity happened. Time of day is not used.
  final DateTime date;

  final int? durationMinutes;
  final double? distanceKm;
  final String? notes;

  /// Points earned, worked out at log time.
  final int points;

  final DateTime createdAt;

  ActivityInput get input =>
      ActivityInput(durationMinutes: durationMinutes, distanceKm: distanceKm);

  Activity copyWith({
    String? id,
    String? playerId,
    String? seasonId,
    String? ruleId,
    String? ruleName,
    String? ruleEmoji,
    DateTime? date,
    int? durationMinutes,
    double? distanceKm,
    String? notes,
    int? points,
    DateTime? createdAt,
  }) {
    return Activity(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      seasonId: seasonId ?? this.seasonId,
      ruleId: ruleId ?? this.ruleId,
      ruleName: ruleName ?? this.ruleName,
      ruleEmoji: ruleEmoji ?? this.ruleEmoji,
      date: date ?? this.date,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      distanceKm: distanceKm ?? this.distanceKm,
      notes: notes ?? this.notes,
      points: points ?? this.points,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Activity(id: $id, playerId: $playerId, '
      'ruleName: $ruleName, points: $points, date: $date)';
}
