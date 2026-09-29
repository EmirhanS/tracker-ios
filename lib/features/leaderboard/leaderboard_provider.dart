import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/player.dart';
import '../challenge/current_challenge_provider.dart';

/// One line of the leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.player,
    required this.points,
    required this.activityCount,
  });

  /// Starts at 1. Players on the same points share a rank.
  final int rank;
  final Player player;
  final int points;
  final int activityCount;
}

/// The members of the current challenge, ranked by their points in it.
///
/// Members only: a player can be in several challenges now, and somebody who
/// never joined this one would sit at the bottom of a table they cannot score
/// in. Every member appears even with nothing logged yet, so a player who has
/// just joined can see where they stand.
final leaderboardProvider = Provider<AsyncValue<List<LeaderboardEntry>>>((ref) {
  final players = ref.watch(playersProvider);
  final challenge = ref.watch(currentChallengeProvider);
  final activities = ref.watch(currentChallengeActivitiesProvider);

  // Loading and errors are carried through rather than flattened to an empty
  // table: a table that is still loading is not a table everybody lost.
  if (players.hasError) {
    return AsyncValue.error(players.error!, players.stackTrace!);
  }
  if (challenge.hasError) {
    return AsyncValue.error(challenge.error!, challenge.stackTrace!);
  }
  if (activities.hasError) {
    return AsyncValue.error(activities.error!, activities.stackTrace!);
  }
  if (!players.hasValue || !challenge.hasValue || !activities.hasValue) {
    return const AsyncValue.loading();
  }

  final current = challenge.requireValue;
  if (current == null) return const AsyncValue.data(<LeaderboardEntry>[]);

  return AsyncValue.data(
    _rank(
      members: players.requireValue
          .where((player) => current.isMember(player.id))
          .toList(growable: false),
      activities: activities.requireValue,
    ),
  );
});

/// Sums [activities] per player and ranks [members] by the total.
List<LeaderboardEntry> _rank({
  required List<Player> members,
  required List<Activity> activities,
}) {
  final points = <String, int>{};
  final counts = <String, int>{};
  for (final activity in activities) {
    points[activity.playerId] =
        (points[activity.playerId] ?? 0) + activity.points;
    counts[activity.playerId] = (counts[activity.playerId] ?? 0) + 1;
  }

  final ranked = List<Player>.of(members)
    ..sort((a, b) {
      final byPoints = (points[b.id] ?? 0).compareTo(points[a.id] ?? 0);
      return byPoints != 0 ? byPoints : a.name.compareTo(b.name);
    });

  final entries = <LeaderboardEntry>[];
  var rank = 0;
  int? lastPoints;
  for (var i = 0; i < ranked.length; i++) {
    final player = ranked[i];
    final playerPoints = points[player.id] ?? 0;
    // Equal points share a rank; the next rank still skips ahead.
    if (playerPoints != lastPoints) {
      rank = i + 1;
      lastPoints = playerPoints;
    }
    entries.add(
      LeaderboardEntry(
        rank: rank,
        player: player,
        points: playerPoints,
        activityCount: counts[player.id] ?? 0,
      ),
    );
  }
  return entries;
}
