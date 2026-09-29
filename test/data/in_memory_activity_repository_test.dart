import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/data/in_memory/in_memory_activity_repository.dart';
import 'package:sporttracker/data/in_memory/seed_data.dart';
import 'package:sporttracker/domain/codes/join_code.dart';
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
      challengeId: 'challenge_1',
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
        challengeId: 'challenge_1',
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
          challengeId: 'challenge_1',
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
        challengeId: 'challenge_1',
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
        challengeId: 'challenge_1',
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
    test('getForChallenge filters by challenge', () async {
      await logGym();
      await repository.log(
        playerId: 'player_1',
        challengeId: 'challenge_2',
        rule: gym,
        date: DateTime(2026, 9, 29),
        input: const ActivityInput(durationMinutes: 60),
      );

      expect(await repository.getForChallenge('challenge_1'), hasLength(1));
      expect(await repository.getForChallenge('challenge_2'), hasLength(1));
      expect(await repository.getForChallenge('challenge_3'), isEmpty);
    });

    test('getForPlayer filters by player and challenge', () async {
      await logGym();
      await logGym(playerId: 'player_2');

      final mine = await repository.getForPlayer(
        playerId: 'player_1',
        challengeId: 'challenge_1',
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
    test('builds seven players, two challenges and 31 activities', () async {
      final repositories = SeedData.build(now: DateTime(2026, 9, 29));
      addTearDown(repositories.dispose);

      expect(await repositories.players.getAll(), hasLength(7));

      final challenges = await repositories.challenges.getAll();
      expect(challenges, hasLength(2));
      expect(challenges.every((challenge) => challenge.isActive), isTrue);

      final big = challenges.first;
      expect(big.name, SeedData.challengeName);
      expect(big.rules, hasLength(5));
      expect(big.ownerId, 'player_1');
      expect(big.memberIds, hasLength(7));
      expect(big.joinCode, SeedData.joinCode);

      final small = challenges.last;
      expect(small.name, SeedData.secondChallengeName);
      expect(small.rules, hasLength(5));
      expect(small.ownerId, 'player_2');
      expect(small.memberIds, ['player_2', 'player_3', 'player_4']);
      expect(small.joinCode, SeedData.secondJoinCode);

      expect(await repositories.activities.getAll(), hasLength(31));
    });

    test('both seeded join codes are real join codes', () async {
      expect(JoinCode.isValid(SeedData.joinCode), isTrue);
      expect(JoinCode.isValid(SeedData.secondJoinCode), isTrue);
      expect(SeedData.joinCode, isNot(SeedData.secondJoinCode));
    });

    test('every seeded activity scores and sits in its own challenge',
        () async {
      final repositories = SeedData.build(now: DateTime(2026, 9, 29));
      addTearDown(repositories.dispose);

      final challenges = await repositories.challenges.getAll();
      final activities = await repositories.activities.getAll();

      for (final activity in activities) {
        final challenge = challenges.firstWhere(
          (one) => one.id == activity.challengeId,
        );
        expect(activity.points, greaterThan(0), reason: activity.ruleName);
        expect(challenge.ruleById(activity.ruleId), isNotNull);
        expect(challenge.containsDate(activity.date), isTrue);
        expect(challenge.isMember(activity.playerId), isTrue);
      }
    });

    test('the two challenges share no rule id', () async {
      // Review finding M1: an activity stores its ruleId, and ruleById looks it
      // up by id alone, so a shared rule_1 would resolve to the wrong rule.
      final repositories = SeedData.build(now: DateTime(2026, 9, 29));
      addTearDown(repositories.dispose);

      final challenges = await repositories.challenges.getAll();
      final ruleIds = challenges
          .expand((challenge) => challenge.rules)
          .map((rule) => rule.id)
          .toList();

      expect(ruleIds, hasLength(10));
      expect(ruleIds.toSet(), hasLength(10));
    });

    test('a new rule id carries on past the seeded ones', () async {
      final repositories = SeedData.build(now: DateTime(2026, 9, 29));
      addTearDown(repositories.dispose);

      expect(repositories.challenges.nextRuleId(), 'rule_11');
    });

    test('a new log carries on from the seeded ids', () async {
      final repositories = SeedData.build(now: DateTime(2026, 9, 29));
      addTearDown(repositories.dispose);

      final challenge = (await repositories.challenges.getAll()).first;
      final rule = challenge.rules.firstWhere((rule) => rule.name == 'Cycling');

      final activity = await repositories.activities.log(
        playerId: 'player_1',
        challengeId: challenge.id,
        rule: rule,
        date: DateTime(2026, 9, 29),
        input: const ActivityInput(durationMinutes: 60),
      );

      expect(activity.id, 'activity_32');
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
