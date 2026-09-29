import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/activity.dart';
import '../domain/models/challenge.dart';
import '../domain/models/player.dart';
import 'repositories/activity_repository.dart';
import 'repositories/challenge_repository.dart';
import 'repositories/player_repository.dart';

/// The repositories the screens use.
///
/// Nothing above this file knows which implementation is behind a provider.
/// `main.dart` overrides all three with the in-memory ones, and a Supabase
/// build overrides them with its own. That is the only swap point.
final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  throw UnimplementedError(
    'playerRepositoryProvider must be overridden in ProviderScope.',
  );
});

final challengeRepositoryProvider = Provider<ChallengeRepository>((ref) {
  throw UnimplementedError(
    'challengeRepositoryProvider must be overridden in ProviderScope.',
  );
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  throw UnimplementedError(
    'activityRepositoryProvider must be overridden in ProviderScope.',
  );
});

/// The team roster.
final playersProvider = StreamProvider<List<Player>>((ref) {
  return ref.watch(playerRepositoryProvider).watchAll();
});

/// Every challenge, running or draft, whoever is in it.
///
/// Screens showing the challenge the signed-in player is looking at use
/// `currentChallengeProvider` instead. This one is for the few places that
/// really do have to see all of them.
final challengesProvider = StreamProvider<List<Challenge>>((ref) {
  return ref.watch(challengeRepositoryProvider).watchAll();
});

/// One challenge by id, kept up to date.
final challengeByIdProvider = Provider.family<AsyncValue<Challenge?>, String>((
  ref,
  challengeId,
) {
  return ref.watch(challengesProvider).whenData((challenges) {
    for (final challenge in challenges) {
      if (challenge.id == challengeId) return challenge;
    }
    return null;
  });
});

/// Every logged activity.
final allActivitiesProvider = StreamProvider<List<Activity>>((ref) {
  return ref.watch(activityRepositoryProvider).watchAll();
});
