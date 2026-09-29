import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/data/in_memory/in_memory_activity_repository.dart';
import 'package:sporttracker/data/in_memory/seed_data.dart';
import 'package:sporttracker/domain/models/activity.dart';
import 'package:sporttracker/domain/models/scoring_rule.dart';

const gym = ScoringRule(
  id: 'rule_1',
  name: 'Gym session',
  emoji: '🏋️',
  scoring: FixedScoring(points: 3, minDurationMinutes: 45),
);

const running = ScoringRule(
  id: 'rule_2',
  name: 'Running',
  scoring: DistanceTierScoring(
    tiers: [
      DistanceTier(minKm: 3, points: 1),
      DistanceTier(minKm: 5, points: 2),
      DistanceTier(minKm: 10, points: 4),
    ],
  ),
);

void main() {
  late InMemoryActivityRepository repository;

  setUp(() {
    repository = InMemoryActivityRepository(
      clock: () => DateTime(2026, 9, 29, 12),
    );
  });

  tearDown(() {
    repository.dispose();
  });

  Future<Activity> logGym({
    String playerId = 'player_1',
    int minutes = 60,
    DateTime? date,
  }) {
    return repository.log(
      playerId: playerId,
      seasonId: 'season_1',
      rule: gym,
      date: date ?? DateTime(2026, 9, 29),
      input: ActivityInput(durationMinutes: minutes),
    );
  }

  group('log', () {
    test('stores the points worked out by the engine', () async {
      final activity = await logGym();

      expect(activity.points, 3);
      expect(activity.ruleId, gym.id);
      expect(activity.ruleName, 'Gym session');
      expect(activity.ruleEmoji, '🏋️');
      expect(activity.durationMinutes, 60);
    });

    test('keeps only the day part of the date', () async {
      final activity = await logGym(date: DateTime(2026, 9, 29, 18, 45));

      expect(activity.date, DateTime(2026, 9, 29));
    });

    test('stamps createdAt from the clock', () async {
      final activity = await logGym();

      expect(activity.createdAt, DateTime(2026, 9, 29, 12));
    });

    test('scores a distance rule by tier', () async {
      final activity = await repository.log(
        playerId: 'player_1',
        seasonId: 'season_1',
        rule: running,
        date: DateTime(2026, 9, 29),
        input: const ActivityInput(distanceKm: 7.5),
      );

      expect(activity.points, 2);
      expect(activity.distanceKm, 7.5);
    });

    test('refuses an input the rule cannot score', () async {
      expect(
        () => logGym(minutes: 20),
        throwsA(isA<ArgumentError>()),
      );
      expect(await repository.getAll(), isEmpty);
    });

    test('refuses a disabled rule', () async {
      expect(
        () => repository.log(
          playerId: 'player_1',
          seasonId: 'season_1',
          rule: gym.copyWith(isEnabled: false),
          date: DateTime(2026, 9, 29),
          input: const ActivityInput(durationMinutes: 60),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('empty notes are stored as null', () async {
      final activity = await repository.log(
        playerId: 'player_1',
        seasonId: 'season_1',
        rule: gym,
        date: DateTime(2026, 9, 29),
        input: const ActivityInput(durationMinutes: 60),
        notes: '   ',
      );

      expect(activity.notes, isNull);
    });

    test('notes are trimmed', () async {
      final activity = await repository.log(
        playerId: 'player_1',
        seasonId: 'season_1',
        rule: gym,
        date: DateTime(2026, 9, 29),
        input: const ActivityInput(durationMinutes: 60),
        notes: '  Leg day  ',
      );

      expect(activity.notes, 'Leg day');
    });

    test('each activity gets its own id', () async {
      final first = await logGym();
      final second = await logGym();

      expect(first.id, isNot(second.id));
    });
  });

  group('reads', () {
    test('getForSeason filters by season', () async {
      await logGym();
      await repository.log(
        playerId: 'player_1',
        seasonId: 'season_2',
        rule: gym,
        date: DateTime(2026, 9, 29),
        input: const ActivityInput(durationMinutes: 60),
      );

      expect(await repository.getForSeason('season_1'), hasLength(1));
      expect(await repository.getForSeason('season_2'), hasLength(1));
      expect(await repository.getForSeason('season_3'), isEmpty);
    });

    test('getForPlayer filters by player and season', () async {
      await logGym();
      await logGym(playerId: 'player_2');

      final mine = await repository.getForPlayer(
        playerId: 'player_1',
        seasonId: 'season_1',
      );

      expect(mine, hasLength(1));
      expect(mine.single.playerId, 'player_1');
    });
  });

  group('delete', () {
    test('removes the activity and its points', () async {
      final first = await logGym();
      await logGym();

      await repository.delete(first.id);

      final left = await repository.getAll();
      expect(left, hasLength(1));
      expect(
        left.fold<int>(0, (sum, activity) => sum + activity.points),
        3,
      );
    });

    test('deleting an unknown id does nothing', () async {
      await logGym();

      await repository.delete('missing');

      expect(await repository.getAll(), hasLength(1));
    });
  });

  group('watchAll', () {
    test('gives the current list first, then every change', () async {
      final seen = <int>[];
      final subscription =
          repository.watchAll().listen((items) => seen.add(items.length));

      await Future<void>.delayed(Duration.zero);
      final activity = await logGym();
      await Future<void>.delayed(Duration.zero);
      await repository.delete(activity.id);
      await Future<void>.delayed(Duration.zero);

      expect(seen, [0, 1, 0]);
      await subscription.cancel();
    });
  });

  group('SeedData', () {
    test('builds seven players, one active season and 25 activities', () async {
      final repositories = SeedData.build(now: DateTime(2026, 9, 29));
      addTearDown(repositories.dispose);

      expect(await repositories.players.getAll(), hasLength(7));

      final season = await repositories.seasons.getActiveSeason();
      expect(season, isNotNull);
      expect(season!.name, SeedData.seasonName);
      expect(season.rules, hasLength(5));
      expect(season.captainId, 'player_1');

      expect(await repositories.activities.getAll(), hasLength(25));
    });

    test('every seeded activity scores and sits in the season', () async {
      final repositories = SeedData.build(now: DateTime(2026, 9, 29));
      addTearDown(repositories.dispose);

      final season = (await repositories.seasons.getActiveSeason())!;
      final activities = await repositories.activities.getAll();

      for (final activity in activities) {
        expect(activity.points, greaterThan(0), reason: activity.ruleName);
        expect(activity.seasonId, season.id);
        expect(season.ruleById(activity.ruleId), isNotNull);
        expect(season.containsDate(activity.date), isTrue);
      }
    });

    test('the seeded season is active and locked', () async {
      final repositories = SeedData.build(now: DateTime(2026, 9, 29));
      addTearDown(repositories.dispose);

      final season = (await repositories.seasons.getActiveSeason())!;

      expect(season.isActive, isTrue);
      expect(season.isLocked, isTrue);
    });

    test('a new log carries on from the seeded ids', () async {
      final repositories = SeedData.build(now: DateTime(2026, 9, 29));
      addTearDown(repositories.dispose);

      final season = (await repositories.seasons.getActiveSeason())!;
      final rule = season.rules.firstWhere((rule) => rule.name == 'Cycling');

      final activity = await repositories.activities.log(
        playerId: 'player_1',
        seasonId: season.id,
        rule: rule,
        date: DateTime(2026, 9, 29),
        input: const ActivityInput(durationMinutes: 60),
      );

      expect(activity.id, 'activity_26');
      expect(activity.points, 2);
    });

    test('the seed is the same every time for the same day', () async {
      final first = SeedData.build(now: DateTime(2026, 9, 29));
      final second = SeedData.build(now: DateTime(2026, 9, 29));
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      final a = await first.activities.getAll();
      final b = await second.activities.getAll();

      expect(a.map((x) => '${x.id}:${x.points}:${x.date}'),
          b.map((x) => '${x.id}:${x.points}:${x.date}'));
    });
  });
}
