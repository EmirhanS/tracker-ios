import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/activity.dart';
import '../domain/models/player.dart';
import '../domain/models/season.dart';
import 'repositories/activity_repository.dart';
import 'repositories/player_repository.dart';
import 'repositories/season_repository.dart';

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

final seasonRepositoryProvider = Provider<SeasonRepository>((ref) {
  throw UnimplementedError(
    'seasonRepositoryProvider must be overridden in ProviderScope.',
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

/// The season that is running now, or null when there is none.
final activeSeasonProvider = StreamProvider<Season?>((ref) {
  return ref.watch(seasonRepositoryProvider).watchActiveSeason();
});

/// Every season, running or draft.
final seasonsProvider = StreamProvider<List<Season>>((ref) {
  return ref.watch(seasonRepositoryProvider).watchAll();
});

/// One season by id, kept up to date.
final seasonByIdProvider = Provider.family<AsyncValue<Season?>, String>((
  ref,
  seasonId,
) {
  return ref.watch(seasonsProvider).whenData((seasons) {
    for (final season in seasons) {
      if (season.id == seasonId) return season;
    }
    return null;
  });
});

/// Every logged activity.
final allActivitiesProvider = StreamProvider<List<Activity>>((ref) {
  return ref.watch(activityRepositoryProvider).watchAll();
});

/// The activities that belong to the season that is running now, newest first.
final seasonActivitiesProvider = Provider<AsyncValue<List<Activity>>>((ref) {
  final season = ref.watch(activeSeasonProvider);
  final activities = ref.watch(allActivitiesProvider);

  return season.when(
    loading: AsyncValue<List<Activity>>.loading,
    error: AsyncValue<List<Activity>>.error,
    data: (season) {
      if (season == null) return const AsyncValue.data(<Activity>[]);
      return activities.whenData((all) {
        final forSeason = all
            .where((activity) => activity.seasonId == season.id)
            .toList(growable: false);
        return _newestFirst(forSeason);
      });
    },
  );
});

/// Sorts newest first by day, then by when it was logged.
List<Activity> _newestFirst(List<Activity> activities) {
  final sorted = List<Activity>.of(activities);
  sorted.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    return b.createdAt.compareTo(a.createdAt);
  });
  return sorted;
}
