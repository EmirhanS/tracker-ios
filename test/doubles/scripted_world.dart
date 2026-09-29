import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/app.dart';
import 'package:sporttracker/core/clock.dart';
import 'package:sporttracker/data/in_memory/in_memory_player_repository.dart';
import 'package:sporttracker/data/in_memory/in_memory_challenge_repository.dart';
import 'package:sporttracker/data/providers.dart';
import 'package:sporttracker/domain/models/activity.dart';

import '../app_harness.dart';
import '../fixtures.dart';
import 'scripted_activity_repository.dart';

/// Starts the app on [Fixture]'s roster and challenge, with the activities behind
/// a [ScriptedActivityRepository] the test drives by hand.
///
/// The roster and the challenge still come from the in-memory repositories, so
/// signing in works as usual; only the activities are held back.
///
/// Riverpod retries a failed provider ten times on a backoff before it settles
/// on an error, and counts itself loading throughout. [giveUpOnError] turns
/// that off so a test can look at the settled error without pumping through
/// forty seconds of retries.
Future<ScriptedActivityRepository> pumpScripted(
  WidgetTester tester, {
  Iterable<Activity> activities = const [],
  bool giveUpOnError = false,
}) async {
  final players = InMemoryPlayerRepository(Fixture.players);
  final challenges = InMemoryChallengeRepository(challenges: [Fixture.challenge()]);
  final repository = ScriptedActivityRepository(activities: activities);

  addTearDown(() {
    players.dispose();
    challenges.dispose();
    repository.dispose();
  });

  await tester.pumpWidget(
    ProviderScope(
      retry: giveUpOnError ? (_, _) => null : null,
      overrides: [
        playerRepositoryProvider.overrideWithValue(players),
        challengeRepositoryProvider.overrideWithValue(challenges),
        activityRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(() => Fixture.now),
      ],
      child: const SportTrackerApp(),
    ),
  );
  await settle(tester);

  return repository;
}
