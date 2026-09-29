import '../../domain/models/activity.dart';
import '../../domain/models/challenge.dart';
import '../../domain/models/player.dart';
import '../../domain/models/scoring_rule.dart';
import '../../domain/points/points_engine.dart';
import '../../domain/templates/challenge_templates.dart';
import 'id_generator.dart';
import 'in_memory_activity_repository.dart';
import 'in_memory_challenge_repository.dart';
import 'in_memory_player_repository.dart';

/// The three repositories, built together so they agree with each other.
class SeededRepositories {
  const SeededRepositories({
    required this.players,
    required this.challenges,
    required this.activities,
  });

  final InMemoryPlayerRepository players;
  final InMemoryChallengeRepository challenges;
  final InMemoryActivityRepository activities;

  void dispose() {
    players.dispose();
    challenges.dispose();
    activities.dispose();
  }
}

/// Sample data so the app has something to show on first run.
///
/// Seven players and two challenges running side by side, because a player can
/// be in more than one now: a big one everybody is in, and a small one three of
/// them share. Points come from [PointsEngine], the same path a real log takes,
/// so the seeded totals and the rules always agree.
abstract final class SeedData {
  /// The name of the big seeded challenge, the one everybody is in.
  static const String challengeName = 'Autumn 2026';

  /// The name of the small seeded challenge.
  static const String secondChallengeName = 'Gym Buddies';

  /// Fixed join codes, so they can be typed in by hand while testing.
  static const String joinCode = 'AUTUMN';
  static const String secondJoinCode = 'GYMBUD';

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

  /// The handful logged in the small challenge, by its three members.
  static const List<_SeedEntry> _secondEntries = [
    _SeedEntry(1, 'Gym session', 1, 55, null),
    _SeedEntry(1, 'Gym session', 4, 45, null),
    _SeedEntry(2, 'Gym session', 2, 60, null),
    _SeedEntry(2, 'Yoga / mobility', 6, 30, null),
    _SeedEntry(3, 'Gym session', 3, 50, null),
    _SeedEntry(3, 'Cycling', 7, 60, null),
  ];

  /// Builds the seeded repositories.
  ///
  /// [now] is injected so tests get the same data every run.
  static SeededRepositories build({DateTime? now}) {
    final today = now ?? DateTime.now();
    // One rule counter for both challenges. Rule ids have to be unique across
    // every challenge, because an activity stores its own `ruleId` and
    // `Challenge.ruleById` looks it up by id alone - see the contract on
    // `ChallengeRepository.nextRuleId`.
    final ruleIds = IdGenerator();
    final activityIds = IdGenerator();

    final players = [
      for (var i = 0; i < _playerNames.length; i++)
        Player(id: 'player_${i + 1}', name: _playerNames[i]),
    ];

    final challenge = Challenge(
      id: 'challenge_1',
      name: challengeName,
      startDate: DateTime(today.year, today.month - 1, 1),
      endDate: DateTime(today.year, today.month + 2, 0),
      ownerId: players.first.id,
      joinCode: joinCode,
      memberIds: List<String>.unmodifiable(
        players.map((player) => player.id),
      ),
      status: ChallengeStatus.active,
      rules: ChallengeTemplates.generalFitness.buildRules(
        ruleIds.forPrefix('rule'),
      ),
    );

    // A smaller one among three of them, so the app starts with two challenges
    // running at once. It opens on the same day as the big one, so every seeded
    // activity falls inside whichever challenge it belongs to.
    final second = Challenge(
      id: 'challenge_2',
      name: secondChallengeName,
      startDate: DateTime(today.year, today.month - 1, 1),
      endDate: DateTime(today.year, today.month + 1, 0),
      ownerId: players[1].id,
      joinCode: secondJoinCode,
      memberIds: List<String>.unmodifiable([
        players[1].id,
        players[2].id,
        players[3].id,
      ]),
      status: ChallengeStatus.active,
      rules: ChallengeTemplates.generalFitness.buildRules(
        ruleIds.forPrefix('rule'),
      ),
    );

    final activities = <Activity>[
      ..._score(
        entries: _entries,
        challenge: challenge,
        players: players,
        today: today,
        ids: activityIds,
      ),
      ..._score(
        entries: _secondEntries,
        challenge: second,
        players: players,
        today: today,
        ids: activityIds,
      ),
    ];

    return SeededRepositories(
      players: InMemoryPlayerRepository(players),
      challenges: InMemoryChallengeRepository(
        challenges: [challenge, second],
        idGenerator: IdGenerator(start: 2),
      ),
      activities: InMemoryActivityRepository(
        activities: activities,
        idGenerator: activityIds,
      ),
    );
  }

  /// Scores [entries] into activities of [challenge].
  static List<Activity> _score({
    required List<_SeedEntry> entries,
    required Challenge challenge,
    required List<Player> players,
    required DateTime today,
    required IdGenerator ids,
  }) {
    final scored = <Activity>[];
    for (final entry in entries) {
      final rule = challenge.rules.firstWhere(
        (ScoringRule rule) => rule.name == entry.ruleName,
      );
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

      scored.add(
        Activity(
          id: ids.next('activity'),
          playerId: players[entry.playerIndex].id,
          challengeId: challenge.id,
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
    return scored;
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
