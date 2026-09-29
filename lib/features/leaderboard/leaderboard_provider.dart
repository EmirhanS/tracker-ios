import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/player.dart';

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

/// The team ranked by points in the running season.
///
/// Every player on the roster appears, so a player with no activities yet can
/// see where they stand.
final leaderboardProvider = Provider<AsyncValue<List<LeaderboardEntry>>>((ref) {
  final players = ref.watch(playersProvider);
  final activities = ref.watch(seasonActivitiesProvider);

  return players.when(
    loading: AsyncValue<List<LeaderboardEntry>>.loading,
    error: AsyncValue<List<LeaderboardEntry>>.error,
    data: (players) => activities.whenData((activities) {
      final points = <String, int>{};
      final counts = <String, int>{};
      for (final activity in activities) {
        points[activity.playerId] =
            (points[activity.playerId] ?? 0) + activity.points;
        counts[activity.playerId] = (counts[activity.playerId] ?? 0) + 1;
      }

      final ranked = List<Player>.of(players)
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
    }),
  );
});
