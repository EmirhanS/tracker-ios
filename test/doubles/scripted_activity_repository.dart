import 'dart:async';

import 'package:sporttracker/data/repositories/activity_repository.dart';
import 'package:sporttracker/domain/models/activity.dart';
import 'package:sporttracker/domain/models/scoring_rule.dart';

/// An [ActivityRepository] whose stream and whose writes a test can hold open.
///
/// The in-memory repository answers inside the same frame, which hides every
/// gap between asking for something and being given it. Behind a network the
/// gap is what the screens actually face: a first batch that has not arrived, a
/// query that fails outright, a `delete` still in flight. Nothing here is
/// emitted until a test says so.
class ScriptedActivityRepository implements ActivityRepository {
  ScriptedActivityRepository({Iterable<Activity> activities = const []})
      : _items = List<Activity>.of(activities);

  final List<Activity> _items;
  final StreamController<List<Activity>> _stream =
      StreamController<List<Activity>>.broadcast();

  /// Holds every [delete] open until the test completes it.
  Completer<void>? pendingDelete;

  /// Makes [delete] throw this instead of removing anything.
  Object? deleteError;

  /// The ids [delete] was called with, in order.
  final List<String> deleted = <String>[];

  /// Never emits on its own, so a screen watching it starts out loading.
  @override
  Stream<List<Activity>> watchAll() => _stream.stream;

  /// Hands the current contents to whoever is watching.
  void emit() {
    if (!_stream.isClosed) _stream.add(List<Activity>.of(_items));
  }

  /// Fails the stream, the way a query that cannot reach the server would.
  ///
  /// Whether the screens settle on the error or sit retrying is Riverpod's
  /// call, not this double's — see `pumpScripted`'s `giveUpOnError`.
  void fail([Object error = 'activities unavailable']) {
    if (!_stream.isClosed) _stream.addError(error, StackTrace.empty);
  }

  @override
  Future<void> delete(String activityId) async {
    deleted.add(activityId);

    // Recorded before the wait, so a test can see the write go out while it is
    // still holding the answer back.
    await pendingDelete?.future;

    final error = deleteError;
    if (error != null) throw error;

    _items.removeWhere((activity) => activity.id == activityId);
    emit();
  }

  @override
  Future<List<Activity>> getAll() async => List<Activity>.of(_items);

  @override
  Future<List<Activity>> getForChallenge(String challengeId) async => _items
      .where((activity) => activity.challengeId == challengeId)
      .toList(growable: false);

  @override
  Future<List<Activity>> getForPlayer({
    required String playerId,
    required String challengeId,
  }) async =>
      _items
          .where(
            (activity) =>
                activity.playerId == playerId && activity.challengeId == challengeId,
          )
          .toList(growable: false);

  @override
  Future<Activity> log({
    required String playerId,
    required String challengeId,
    required ScoringRule rule,
    required DateTime date,
    required ActivityInput input,
    String? notes,
  }) {
    throw UnsupportedError('This double is only used for reads and deletes.');
  }

  void dispose() => unawaited(_stream.close());
}
