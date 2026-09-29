import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sporttracker/app.dart';
import 'package:sporttracker/core/clock.dart';
import 'package:sporttracker/data/in_memory/id_generator.dart';
import 'package:sporttracker/data/in_memory/in_memory_activity_repository.dart';
import 'package:sporttracker/data/in_memory/in_memory_player_repository.dart';
import 'package:sporttracker/data/in_memory/in_memory_challenge_repository.dart';
import 'package:sporttracker/data/providers.dart';
import 'package:sporttracker/domain/models/activity.dart';
import 'package:sporttracker/domain/models/player.dart';
import 'package:sporttracker/domain/models/scoring_rule.dart';
import 'package:sporttracker/domain/models/challenge.dart';

import 'app_harness.dart';
import 'doubles/scripted_join_code_generator.dart';

/// The three repositories a test drives the app with.
class TestWorld {
  const TestWorld({
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

  /// Everything [playerId] has logged in [Fixture.challengeId], newest first is
  /// not guaranteed — this is the raw store, for exact assertions.
  Future<List<Activity>> activitiesOf(String playerId) =>
      activities.getForPlayer(playerId: playerId, challengeId: Fixture.challengeId);

  /// The points [playerId] holds in [Fixture.challengeId].
  Future<int> pointsOf(String playerId) async {
    final mine = await activitiesOf(playerId);
    return mine.fold<int>(0, (total, activity) => total + activity.points);
  }
}

/// A hand-built world with exact numbers, used instead of the demo seed.
///
/// Every total in the tests is a sum the reader can check against [activities]
/// by hand, and the week boundaries are pinned to real calendar days:
///
/// * "now" is **Sunday 11 October 2026, 23:59** — the last minute of the week.
/// * The current week runs **Mon 5 Oct 00:00** to **Sun 11 Oct 23:59**.
/// * The week before runs **Mon 28 Sep** to **Sun 4 Oct**.
///
/// [mira] holds one activity on each of those four days, so "this week" is
/// tested on both of its boundaries and just outside both of them.
abstract final class Fixture {
  // ------------------------------------------------------------------- dates

  /// Sunday 11 October 2026, one minute before midnight.
  static final DateTime now = DateTime(2026, 10, 11, 23, 59);

  /// Monday 5 October 2026, midnight — the first instant of the current week.
  static final DateTime weekMonday = DateTime(2026, 10, 5);

  /// Wednesday 7 October 2026, the middle of the current week.
  static final DateTime weekWednesday = DateTime(2026, 10, 7, 12);

  /// Sunday 11 October 2026, 23:59 — the last minute of the current week.
  static final DateTime weekSunday = DateTime(2026, 10, 11, 23, 59);

  /// Sunday 4 October 2026, 23:59 — one minute before the current week starts.
  static final DateTime lastWeekSunday = DateTime(2026, 10, 4, 23, 59);

  /// Monday 28 September 2026 — the Monday of the week before.
  static final DateTime lastWeekMonday = DateTime(2026, 9, 28);

  /// A day well before the two weeks above.
  static final DateTime earlier = DateTime(2026, 9, 20);

  static final DateTime challengeStart = DateTime(2026, 9, 1);
  static final DateTime challengeEnd = DateTime(2026, 12, 31);

  // ------------------------------------------------------------------- rules

  static const String challengeId = 'challenge_1';

  /// Fixed points with a minimum duration: asks for a duration.
  static const ScoringRule gym = ScoringRule(
    id: 'rule_1',
    name: 'Gym session',
    emoji: '🏋️',
    scoring: FixedScoring(points: 3, minDurationMinutes: 45),
  );

  /// Points per block of time: asks for a duration.
  static const ScoringRule cycling = ScoringRule(
    id: 'rule_2',
    name: 'Cycling',
    emoji: '🚴',
    scoring: TimeBasedScoring(
      pointsPerBlock: 1,
      minutesPerBlock: 30,
      minDurationMinutes: 30,
    ),
  );

  /// Points by distance: asks for a distance.
  static const ScoringRule running = ScoringRule(
    id: 'rule_3',
    name: 'Running',
    emoji: '🏃',
    scoring: DistanceTierScoring(
      tiers: [
        DistanceTier(minKm: 3, points: 1),
        DistanceTier(minKm: 5, points: 2),
        DistanceTier(minKm: 10, points: 4),
      ],
    ),
  );

  /// Fixed points with no minimum: asks for nothing at all.
  static const ScoringRule stretching = ScoringRule(
    id: 'rule_4',
    name: 'Stretching',
    emoji: '🤸',
    scoring: FixedScoring(points: 2),
  );

  /// Switched off, so it must never reach the log screen's picker.
  static const ScoringRule swimming = ScoringRule(
    id: 'rule_5',
    name: 'Swimming',
    emoji: '🏊',
    isEnabled: false,
    scoring: FixedScoring(points: 5, minDurationMinutes: 30),
  );

  static const List<ScoringRule> rules = [
    gym,
    cycling,
    running,
    stretching,
    swimming,
  ];

  /// The names the log screen's picker must offer, in order.
  static const List<String> enabledRuleNames = [
    'Gym session',
    'Cycling',
    'Running',
    'Stretching',
  ];

  // ----------------------------------------------------------------- players

  /// The owner, and the player most screen tests sign in as. 17 points.
  static const Player mira = Player(id: 'player_1', name: 'Mira Sol');

  /// Ties with [mira] on 17 points, and sorts before her by name even though
  /// she comes first on the roster.
  static const Player ben = Player(id: 'player_2', name: 'Ben Aro');

  /// 9 points.
  static const Player cleo = Player(id: 'player_3', name: 'Cleo Vane');

  /// Has logged nothing, so a fresh log starts from an exact zero.
  static const Player dana = Player(id: 'player_4', name: 'Dana Wu');

  static const List<Player> players = [mira, ben, cleo, dana];

  // ---------------------------------------------------------------- challenges

  /// The join code of [challenge]. Six characters, all in the alphabet.
  static const String joinCode = 'TESTER';

  /// The challenge every screen test runs on, with all four players in it.
  static Challenge challenge({
    ChallengeStatus status = ChallengeStatus.active,
    List<String>? memberIds,
  }) =>
      Challenge(
        id: challengeId,
        name: 'Test Challenge',
        startDate: challengeStart,
        endDate: challengeEnd,
        ownerId: mira.id,
        joinCode: joinCode,
        memberIds:
            memberIds ?? [for (final player in players) player.id],
        status: status,
        rules: rules,
      );

  // ------------------------------------------------- the second challenge
  //
  // A player can be in several challenges at once in v2, so the switcher, the
  // scoped leaderboard and the join flow all need a second one to be about.
  // [ben] owns it and [mira] is in it; [cleo] and [dana] are in the first one
  // only, which is what makes "this table is members of *this* challenge"
  // something a test can see.

  static const String secondChallengeId = 'challenge_2';

  /// Six characters, all in the join code alphabet — no O and no I.
  static const String secondJoinCode = 'GYMBUD';

  static const String secondChallengeName = 'Gym Buddies';

  /// Rule ids carry on from [rules]: they are unique across every challenge.
  static const ScoringRule secondGym = ScoringRule(
    id: 'rule_6',
    name: 'Gym session',
    emoji: '🏋️',
    scoring: FixedScoring(points: 3, minDurationMinutes: 45),
  );

  static const ScoringRule secondRowing = ScoringRule(
    id: 'rule_7',
    name: 'Rowing',
    emoji: '🚣',
    scoring: FixedScoring(points: 2),
  );

  static const List<ScoringRule> secondRules = [secondGym, secondRowing];

  static Challenge secondChallenge({
    ChallengeStatus status = ChallengeStatus.active,
    List<String>? memberIds,
  }) =>
      Challenge(
        id: secondChallengeId,
        name: secondChallengeName,
        startDate: challengeStart,
        endDate: challengeEnd,
        ownerId: ben.id,
        joinCode: secondJoinCode,
        memberIds: memberIds ?? [ben.id, mira.id],
        status: status,
        rules: secondRules,
      );

  /// What is logged in the second challenge. Ben **6**, Mira **3**.
  static List<Activity> get secondChallengeActivities => [
        _activity(
          'activity_16',
          mira,
          secondGym,
          weekWednesday,
          minutes: 60,
          points: 3,
          challengeId: secondChallengeId,
        ),
        _activity(
          'activity_17',
          ben,
          secondGym,
          weekWednesday,
          minutes: 60,
          points: 3,
          challengeId: secondChallengeId,
        ),
        _activity(
          'activity_18',
          ben,
          secondRowing,
          weekMonday,
          points: 3,
          challengeId: secondChallengeId,
        ),
      ];

  /// Both challenges' activities, for a test that switches between them.
  static List<Activity> get bothChallengeActivities => [
        ...activities,
        ...secondChallengeActivities,
      ];

  static const int miraSecondChallengePoints = 3;
  static const int benSecondChallengePoints = 6;

  // -------------------------------------------------------------- activities

  /// Mira's six activities. Challenge total **17**, this week **9**.
  ///
  /// The first four sit on the week boundaries: Mon 5 Oct 00:00 and Sun 11 Oct
  /// 23:59 are inside the week, Sun 4 Oct 23:59 and Mon 28 Sep are outside it.
  static List<Activity> get miraActivities => [
        _activity('activity_1', mira, gym, weekMonday, minutes: 45, points: 3),
        _activity('activity_2', mira, gym, weekSunday, minutes: 60, points: 3),
        _activity(
          'activity_3',
          mira,
          cycling,
          weekWednesday,
          minutes: 90,
          points: 3,
        ),
        _activity('activity_4', mira, running, lastWeekSunday, km: 5, points: 2),
        _activity('activity_5', mira, running, lastWeekMonday, km: 10, points: 4),
        _activity('activity_6', mira, stretching, earlier, points: 2),
      ];

  /// Ben's six activities. Challenge total **17**, tying with Mira.
  static List<Activity> get benActivities => [
        _activity(
          'activity_7',
          ben,
          running,
          DateTime(2026, 9, 15),
          km: 10,
          points: 4,
        ),
        _activity(
          'activity_8',
          ben,
          running,
          DateTime(2026, 9, 16),
          km: 12,
          points: 4,
        ),
        _activity(
          'activity_9',
          ben,
          gym,
          DateTime(2026, 9, 17),
          minutes: 50,
          points: 3,
        ),
        _activity(
          'activity_10',
          ben,
          cycling,
          DateTime(2026, 9, 18),
          minutes: 90,
          points: 3,
        ),
        _activity('activity_11', ben, stretching, DateTime(2026, 9, 19),
            points: 2),
        _activity(
          'activity_12',
          ben,
          running,
          DateTime(2026, 9, 20),
          km: 3,
          points: 1,
        ),
      ];

  /// Cleo's three activities. Challenge total **9**.
  static List<Activity> get cleoActivities => [
        _activity(
          'activity_13',
          cleo,
          running,
          DateTime(2026, 9, 15),
          km: 10,
          points: 4,
        ),
        _activity(
          'activity_14',
          cleo,
          running,
          DateTime(2026, 9, 16),
          km: 5,
          points: 2,
        ),
        _activity(
          'activity_15',
          cleo,
          gym,
          DateTime(2026, 9, 17),
          minutes: 45,
          points: 3,
        ),
      ];

  static List<Activity> get activities => [
        ...miraActivities,
        ...benActivities,
        ...cleoActivities,
      ];

  /// Mira's points over the whole challenge.
  static const int miraChallengePoints = 17;

  /// Mira's points in the Monday-to-Sunday week that contains [now].
  static const int miraWeekPoints = 9;

  static const int benChallengePoints = 17;
  static const int cleoChallengePoints = 9;
  static const int danaChallengePoints = 0;

  static Activity _activity(
    String id,
    Player player,
    ScoringRule rule,
    DateTime date, {
    required int points,
    int? minutes,
    double? km,
    String challengeId = Fixture.challengeId,
  }) {
    return Activity(
      id: id,
      playerId: player.id,
      challengeId: challengeId,
      ruleId: rule.id,
      ruleName: rule.name,
      ruleEmoji: rule.emoji,
      date: date,
      durationMinutes: minutes,
      distanceKm: km,
      points: points,
      // Logged on the day it happened, so the newest-first sort is settled by
      // the date alone.
      createdAt: date,
    );
  }
}

/// The codes a test world hands out when a challenge is created in it.
///
/// Fresh each call, because a [ScriptedJoinCodeGenerator] counts through its
/// list. None of them is [Fixture.joinCode], so a created challenge never looks
/// like the fixture one.
List<String> scriptedJoinCodes() => ['AAAAAA', 'BBBBBB', 'CCCCCC', 'DDDDDD'];

/// Starts the app on [Fixture]'s world.
///
/// [challenges] and [activities] default to the full fixture. Pass `const []` for
/// a team that has no challenge yet, or a draft challenge to start setup part way in.
///
/// [challengeRepository] replaces the challenge store outright, for a test that
/// needs one that refuses a write. It takes the place of [challenges].
Future<TestWorld> pumpWorld(
  WidgetTester tester, {
  List<Player> players = Fixture.players,
  List<Challenge>? challenges,
  List<Activity>? activities,
  InMemoryChallengeRepository? challengeRepository,
  DateTime? now,
}) async {
  final today = now ?? Fixture.now;
  final seeded = activities ?? Fixture.activities;

  final world = TestWorld(
    players: InMemoryPlayerRepository(players),
    challenges: challengeRepository ??
        InMemoryChallengeRepository(
      challenges: challenges ?? [Fixture.challenge()],
      idGenerator: IdGenerator(start: challenges?.length ?? 1),
      joinCodeGenerator: ScriptedJoinCodeGenerator(scriptedJoinCodes()),
    ),
    activities: InMemoryActivityRepository(
      activities: seeded,
      idGenerator: IdGenerator(start: seeded.length),
      clock: () => today,
    ),
  );
  addTearDown(world.dispose);

  await tester.pumpWidget(_scope(world, today, const SportTrackerApp()));
  await settle(tester);

  return world;
}

/// Puts one screen on the tree, without the app's own router or the tab shell.
///
/// Used where the app's guards make a state unreachable by tapping but the
/// screen still has to behave — the rules of a running challenge, for instance.
///
/// The screen is pushed on top of a blank host inside a throwaway [GoRouter],
/// not dropped in as `MaterialApp.home`: these screens call `context.pop()` when
/// a save lands, which needs both a router in the tree and something underneath
/// to pop back to.
Future<TestWorld> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Challenge>? challenges,
  List<Activity>? activities,
  DateTime? now,
}) async {
  final today = now ?? Fixture.now;
  final seeded = activities ?? Fixture.activities;

  final world = TestWorld(
    players: InMemoryPlayerRepository(Fixture.players),
    challenges: InMemoryChallengeRepository(
      challenges: challenges ?? [Fixture.challenge()],
      idGenerator: IdGenerator(start: challenges?.length ?? 1),
      joinCodeGenerator: ScriptedJoinCodeGenerator(scriptedJoinCodes()),
    ),
    activities: InMemoryActivityRepository(
      activities: seeded,
      idGenerator: IdGenerator(start: seeded.length),
      clock: () => today,
    ),
  );
  addTearDown(world.dispose);

  final router = GoRouter(
    initialLocation: '/host/screen',
    routes: [
      GoRoute(
        path: '/host',
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
        routes: [
          GoRoute(path: 'screen', builder: (context, state) => screen),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    _scope(world, today, MaterialApp.router(routerConfig: router)),
  );
  await settle(tester);

  return world;
}

/// Wraps [child] in a scope where the three repositories and the clock are
/// the fixture's.
ProviderScope _scope(TestWorld world, DateTime today, Widget child) {
  return ProviderScope(
    overrides: [
      playerRepositoryProvider.overrideWithValue(world.players),
      challengeRepositoryProvider.overrideWithValue(world.challenges),
      activityRepositoryProvider.overrideWithValue(world.activities),
      clockProvider.overrideWithValue(() => today),
    ],
    child: child,
  );
}
