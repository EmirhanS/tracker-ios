import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/app.dart';
import 'package:sporttracker/core/clock.dart';
import 'package:sporttracker/data/in_memory/id_generator.dart';
import 'package:sporttracker/data/in_memory/in_memory_activity_repository.dart';
import 'package:sporttracker/data/in_memory/in_memory_player_repository.dart';
import 'package:sporttracker/data/in_memory/in_memory_season_repository.dart';
import 'package:sporttracker/data/providers.dart';
import 'package:sporttracker/domain/models/activity.dart';
import 'package:sporttracker/domain/models/player.dart';
import 'package:sporttracker/domain/models/scoring_rule.dart';
import 'package:sporttracker/domain/models/season.dart';

import 'app_harness.dart';

/// The three repositories a test drives the app with.
class TestWorld {
  const TestWorld({
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

  /// Everything [playerId] has logged in [Fixture.seasonId], newest first is
  /// not guaranteed — this is the raw store, for exact assertions.
  Future<List<Activity>> activitiesOf(String playerId) =>
      activities.getForPlayer(playerId: playerId, seasonId: Fixture.seasonId);

  /// The points [playerId] holds in [Fixture.seasonId].
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

  static final DateTime seasonStart = DateTime(2026, 9, 1);
  static final DateTime seasonEnd = DateTime(2026, 12, 31);

  // ------------------------------------------------------------------- rules

  static const String seasonId = 'season_1';

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

  /// The captain, and the player most screen tests sign in as. 17 points.
  static const Player mira = Player(id: 'player_1', name: 'Mira Sol');

  /// Ties with [mira] on 17 points, and sorts before her by name even though
  /// she comes first on the roster.
  static const Player ben = Player(id: 'player_2', name: 'Ben Aro');

  /// 9 points.
  static const Player cleo = Player(id: 'player_3', name: 'Cleo Vane');

  /// Has logged nothing, so a fresh log starts from an exact zero.
  static const Player dana = Player(id: 'player_4', name: 'Dana Wu');

  static const List<Player> players = [mira, ben, cleo, dana];

  // ---------------------------------------------------------------- seasons

  static Season season({SeasonStatus status = SeasonStatus.active}) => Season(
        id: seasonId,
        name: 'Test Season',
        startDate: seasonStart,
        endDate: seasonEnd,
        captainId: mira.id,
        status: status,
        rules: rules,
      );

  // -------------------------------------------------------------- activities

  /// Mira's six activities. Season total **17**, this week **9**.
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

  /// Ben's six activities. Season total **17**, tying with Mira.
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

  /// Cleo's three activities. Season total **9**.
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

  /// Mira's points over the whole season.
  static const int miraSeasonPoints = 17;

  /// Mira's points in the Monday-to-Sunday week that contains [now].
  static const int miraWeekPoints = 9;

  static const int benSeasonPoints = 17;
  static const int cleoSeasonPoints = 9;
  static const int danaSeasonPoints = 0;

  static Activity _activity(
    String id,
    Player player,
    ScoringRule rule,
    DateTime date, {
    required int points,
    int? minutes,
    double? km,
  }) {
    return Activity(
      id: id,
      playerId: player.id,
      seasonId: seasonId,
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

/// Starts the app on [Fixture]'s world.
///
/// [seasons] and [activities] default to the full fixture. Pass `const []` for
/// a team that has no season yet, or a draft season to start setup part way in.
Future<TestWorld> pumpWorld(
  WidgetTester tester, {
  List<Player> players = Fixture.players,
  List<Season>? seasons,
  List<Activity>? activities,
  DateTime? now,
}) async {
  final today = now ?? Fixture.now;
  final seeded = activities ?? Fixture.activities;

  final world = TestWorld(
    players: InMemoryPlayerRepository(players),
    seasons: InMemorySeasonRepository(
      seasons: seasons ?? [Fixture.season()],
      idGenerator: IdGenerator(start: seasons?.length ?? 1),
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

/// Puts one screen on the tree, without the router or the tab shell.
///
/// Used where the router's own guards make a state unreachable by tapping but
/// the screen still has to behave — an active season's rules, for instance.
Future<TestWorld> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Season>? seasons,
  List<Activity>? activities,
  DateTime? now,
}) async {
  final today = now ?? Fixture.now;
  final seeded = activities ?? Fixture.activities;

  final world = TestWorld(
    players: InMemoryPlayerRepository(Fixture.players),
    seasons: InMemorySeasonRepository(
      seasons: seasons ?? [Fixture.season()],
      idGenerator: IdGenerator(start: seasons?.length ?? 1),
    ),
    activities: InMemoryActivityRepository(
      activities: seeded,
      idGenerator: IdGenerator(start: seeded.length),
      clock: () => today,
    ),
  );
  addTearDown(world.dispose);

  await tester.pumpWidget(_scope(world, today, MaterialApp(home: screen)));
  await settle(tester);

  return world;
}

/// Wraps [child] in a scope where the three repositories and the clock are
/// the fixture's.
ProviderScope _scope(TestWorld world, DateTime today, Widget child) {
  return ProviderScope(
    overrides: [
      playerRepositoryProvider.overrideWithValue(world.players),
      seasonRepositoryProvider.overrideWithValue(world.seasons),
      activityRepositoryProvider.overrideWithValue(world.activities),
      clockProvider.overrideWithValue(() => today),
    ],
    child: child,
  );
}
