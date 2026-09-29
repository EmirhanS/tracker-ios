import '../../domain/models/activity.dart';
import '../../domain/models/scoring_rule.dart';
import '../../domain/points/points_engine.dart';
import '../repositories/activity_repository.dart';
import 'id_generator.dart';
import 'in_memory_store.dart';

/// Logged activities held in memory.
class InMemoryActivityRepository implements ActivityRepository {
  InMemoryActivityRepository({
    Iterable<Activity> activities = const [],
    IdGenerator? idGenerator,
    DateTime Function()? clock,
  })  : _store = InMemoryStore<Activity>(activities),
        _ids = idGenerator ?? IdGenerator(start: activities.length),
        _now = clock ?? DateTime.now;

  final InMemoryStore<Activity> _store;
  final IdGenerator _ids;
  final DateTime Function() _now;

  @override
  Future<List<Activity>> getAll() async => _store.items;

  @override
  Future<List<Activity>> getForSeason(String seasonId) async => _store.items
      .where((activity) => activity.seasonId == seasonId)
      .toList(growable: false);

  @override
  Future<List<Activity>> getForPlayer({
    required String playerId,
    required String seasonId,
  }) async =>
      _store.items
          .where(
            (activity) =>
                activity.playerId == playerId && activity.seasonId == seasonId,
          )
          .toList(growable: false);

  @override
  Future<Activity> log({
    required String playerId,
    required String seasonId,
    required ScoringRule rule,
    required DateTime date,
    required ActivityInput input,
    String? notes,
  }) async {
    final points = switch (PointsEngine.calculate(rule, input)) {
      PointsSuccess(:final points) => points,
      PointsFailure(:final error) => throw ArgumentError.value(
          input,
          'input',
          'Does not score against ${rule.name}: $error',
        ),
    };

    final trimmedNotes = notes?.trim();
    final activity = Activity(
      id: _ids.next('activity'),
      playerId: playerId,
      seasonId: seasonId,
      ruleId: rule.id,
      ruleName: rule.name,
      ruleEmoji: rule.emoji,
      date: DateTime(date.year, date.month, date.day),
      durationMinutes: input.durationMinutes,
      distanceKm: input.distanceKm,
      notes:
          (trimmedNotes == null || trimmedNotes.isEmpty) ? null : trimmedNotes,
      points: points,
      createdAt: _now(),
    );

    _store.add(activity);
    return activity;
  }

  @override
  Future<void> delete(String activityId) async {
    _store.removeWhere((activity) => activity.id == activityId);
  }

  @override
  Stream<List<Activity>> watchAll() => _store.watch();

  void dispose() => _store.dispose();
}
