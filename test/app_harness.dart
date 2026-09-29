import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/app.dart';
import 'package:sporttracker/core/clock.dart';
import 'package:sporttracker/data/in_memory/in_memory_activity_repository.dart';
import 'package:sporttracker/data/in_memory/in_memory_player_repository.dart';
import 'package:sporttracker/data/in_memory/in_memory_season_repository.dart';
import 'package:sporttracker/data/in_memory/seed_data.dart';
import 'package:sporttracker/data/providers.dart';
import 'package:sporttracker/domain/models/player.dart';

/// The day the widget tests pretend it is, so the seeded data never moves.
final testToday = DateTime(2026, 9, 29);

/// Starts the app with freshly seeded in-memory repositories.
///
/// Returns the repositories so a test can look at what the screens changed.
Future<SeededRepositories> pumpApp(
  WidgetTester tester, {
  DateTime? now,
}) async {
  final today = now ?? testToday;
  final repositories = SeedData.build(now: today);
  addTearDown(repositories.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerRepositoryProvider.overrideWithValue(repositories.players),
        seasonRepositoryProvider.overrideWithValue(repositories.seasons),
        activityRepositoryProvider.overrideWithValue(repositories.activities),
        clockProvider.overrideWithValue(() => today),
      ],
      child: const SportTrackerApp(),
    ),
  );
  await settle(tester);

  return repositories;
}

/// Starts the app with the roster but no season at all.
///
/// This is the state a brand new team is in, and the only state in which a
/// captain can set a season up.
Future<({
  InMemoryPlayerRepository players,
  InMemorySeasonRepository seasons,
  InMemoryActivityRepository activities,
})> pumpAppWithoutSeason(
  WidgetTester tester, {
  DateTime? now,
}) async {
  final today = now ?? testToday;
  final players = InMemoryPlayerRepository(const [
    Player(id: 'player_1', name: 'Mia Halvorsen'),
    Player(id: 'player_2', name: 'Jonas Berg'),
  ]);
  final seasons = InMemorySeasonRepository();
  final activities = InMemoryActivityRepository(clock: () => today);

  addTearDown(() {
    players.dispose();
    seasons.dispose();
    activities.dispose();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerRepositoryProvider.overrideWithValue(players),
        seasonRepositoryProvider.overrideWithValue(seasons),
        activityRepositoryProvider.overrideWithValue(activities),
        clockProvider.overrideWithValue(() => today),
      ],
      child: const SportTrackerApp(),
    ),
  );
  await settle(tester);

  return (players: players, seasons: seasons, activities: activities);
}

/// Pumps a few frames. [WidgetTester.pumpAndSettle] cannot be used because the
/// app shows progress indicators, which never stop animating.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Scrolls a button into view, taps it, and waits.
Future<void> tapButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  // A screen can hold more than one Scrollable, so name the outer list.
  await tester.scrollUntilVisible(
    button,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(button);
  await settle(tester);
}

/// Signs in from the welcome screen and waits for the dashboard.
Future<void> signIn(WidgetTester tester, String playerName) async {
  // The roster scrolls in the small test window.
  await tester.scrollUntilVisible(find.text(playerName), 100);
  await tester.tap(find.text(playerName));
  await settle(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await settle(tester);
}
