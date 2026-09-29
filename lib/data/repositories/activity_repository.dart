import '../../domain/models/activity.dart';
import '../../domain/models/scoring_rule.dart';

/// Reads and writes logged activities.
///
/// Points are worked out here through `PointsEngine` and stored on the
/// activity, so totals are always a plain sum and deleting an activity takes
/// its points away by itself.
abstract interface class ActivityRepository {
  Future<List<Activity>> getAll();

  Future<List<Activity>> getForChallenge(String challengeId);

  Future<List<Activity>> getForPlayer({
    required String playerId,
    required String challengeId,
  });

  /// Scores [input] against [rule] and stores the result.
  ///
  /// Throws `ArgumentError` when the rule cannot score the input; check with
  /// `PointsEngine.calculate` first to show the reason in the form.
  Future<Activity> log({
    required String playerId,
    required String challengeId,
    required ScoringRule rule,
    required DateTime date,
    required ActivityInput input,
    String? notes,
  });

  /// Removes an activity. Its points go with it.
  Future<void> delete(String activityId);

  /// Emits every activity, then again after every change.
  Stream<List<Activity>> watchAll();
}
