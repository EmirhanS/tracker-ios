import '../../domain/models/activity.dart';
import '../../domain/models/player.dart';
import '../../domain/models/season.dart';
import '../../domain/points/points_engine.dart';
import '../../domain/templates/season_templates.dart';
import 'id_generator.dart';
import 'in_memory_activity_repository.dart';
import 'in_memory_player_repository.dart';
import 'in_memory_season_repository.dart';

/// The three repositories, built together so they agree with each other.
class SeededRepositories {
  const SeededRepositories({
    required this.players,
    required this.seasons,
    required this.activities,
  });

  final InMemoryPlayerRepository players;
  final InMemorySeasonRepository seasons;
  final InMemoryActivityRepository activities;

  void dispose() {
    players.dispose();
    seasons.dispose();
    activities.dispose();
  }
}

/// Sample data so the app has something to show on first run.
///
/// Seven players, one running season built from General Fitness, and about
/// twenty-five activities spread over the last three weeks. Points come from
/// [PointsEngine], the same path a real log takes, so the seeded totals and the
/// rules always agree.
abstract final class SeedData {
  /// The name of the seeded season.
  static const String seasonName = 'Autumn 2026';

  static const List<String> _playerNames = [
    'Mia Halvorsen',
    'Jonas Berg',
    'Priya Nair',
    'Tomas Kowalski',
    'Lena Fischer',
    'Sam Okafor',
    'Ines Duarte',
  ];

  /// One seeded activity, before it is scored.
  static const List<_SeedEntry> _entries = [
    // (playerIndex, ruleName, daysAgo, minutes, km)
    _SeedEntry(0, 'Running', 1, null, 5.2),
    _SeedEntry(0, 'Gym session', 3, 60, null),
    _SeedEntry(0, 'Yoga / mobility', 5, 40, null),
    _SeedEntry(0, 'Team sport', 9, 90, null),
    _SeedEntry(0, 'Running', 13, null, 10.4),
    _SeedEntry(1, 'Cycling', 0, 75, null),
    _SeedEntry(1, 'Gym session', 2, 50, null),
    _SeedEntry(1, 'Team sport', 6, 75, null),
    _SeedEntry(1, 'Cycling', 11, 120, null),
    _SeedEntry(2, 'Running', 0, null, 15.8),
    _SeedEntry(2, 'Running', 4, null, 8.0),
    _SeedEntry(2, 'Yoga / mobility', 7, 35, null),
    _SeedEntry(2, 'Gym session', 12, 45, null),
    _SeedEntry(3, 'Team sport', 1, 60, null),
    _SeedEntry(3, 'Gym session', 8, 75, null),
    _SeedEntry(3, 'Running', 15, null, 3.4),
    _SeedEntry(4, 'Cycling', 2, 45, null),
    _SeedEntry(4, 'Yoga / mobility', 3, 60, null),
    _SeedEntry(4, 'Team sport', 10, 90, null),
    _SeedEntry(4, 'Running', 16, null, 6.1),
    _SeedEntry(5, 'Gym session', 1, 45, null),
    _SeedEntry(5, 'Cycling', 5, 95, null),
    _SeedEntry(5, 'Running', 14, null, 21.1),
    _SeedEntry(6, 'Yoga / mobility', 2, 30, null),
    _SeedEntry(6, 'Team sport', 9, 60, null),
  ];

  /// Builds the seeded repositories.
  ///
  /// [now] is injected so tests get the same data every run.
  static SeededRepositories build({DateTime? now}) {
    final today = now ?? DateTime.now();
    final ruleIds = IdGenerator();
    final activityIds = IdGenerator();

    final players = [
      for (var i = 0; i < _playerNames.length; i++)
        Player(id: 'player_${i + 1}', name: _playerNames[i]),
    ];

    final rules = SeasonTemplates.generalFitness.buildRules(
      ruleIds.forPrefix('rule'),
    );

    final season = Season(
      id: 'season_1',
      name: seasonName,
      startDate: DateTime(today.year, today.month - 1, 1),
      endDate: DateTime(today.year, today.month + 2, 0),
      captainId: players.first.id,
      status: SeasonStatus.active,
      rules: rules,
    );

    final activities = <Activity>[];
    for (final entry in _entries) {
      final rule = rules.firstWhere((rule) => rule.name == entry.ruleName);
      final input = ActivityInput(
        durationMinutes: entry.minutes,
        distanceKm: entry.km,
      );
      final result = PointsEngine.calculate(rule, input);
      if (result is! PointsSuccess) {
        // A seed entry that does not score is a mistake in this file.
        throw StateError(
          'Seed entry ${entry.ruleName} for player ${entry.playerIndex} '
          'does not score: $result',
        );
      }

      // Calendar days, not a Duration: `Duration(days: n)` is n times 24h of
      // absolute time, so across a DST change it lands on the wrong day and
      // shifts a seeded activity out of the week it was meant to fall in.
      // DateTime normalises an out-of-range day field back into the month.
      final date = DateTime(today.year, today.month, today.day - entry.daysAgo);

      activities.add(
        Activity(
          id: activityIds.next('activity'),
          playerId: players[entry.playerIndex].id,
          seasonId: season.id,
          ruleId: rule.id,
          ruleName: rule.name,
          ruleEmoji: rule.emoji,
          date: date,
          durationMinutes: entry.minutes,
          distanceKm: entry.km,
          points: result.points,
          createdAt: date,
        ),
      );
    }

    return SeededRepositories(
      players: InMemoryPlayerRepository(players),
      seasons: InMemorySeasonRepository(
        seasons: [season],
        idGenerator: IdGenerator(start: 1),
      ),
      activities: InMemoryActivityRepository(
        activities: activities,
        idGenerator: activityIds,
      ),
    );
  }
}

class _SeedEntry {
  const _SeedEntry(
    this.playerIndex,
    this.ruleName,
    this.daysAgo,
    this.minutes,
    this.km,
  );

  final int playerIndex;
  final String ruleName;
  final int daysAgo;
  final int? minutes;
  final double? km;
}
