import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/format/app_dates.dart';
import '../../domain/models/activity.dart';
import '../challenge/current_challenge_provider.dart';
import '../session/current_player_provider.dart';

/// The current player's activities in the running challenge, newest first.
final myActivitiesProvider = Provider<AsyncValue<List<Activity>>>((ref) {
  final player = ref.watch(currentPlayerProvider);
  if (player == null) return const AsyncValue.data(<Activity>[]);

  return ref.watch(currentChallengeActivitiesProvider).whenData(
        (activities) => activities
            .where((activity) => activity.playerId == player.id)
            .toList(growable: false),
      );
});

/// The current player's points in the running challenge.
///
/// Async on purpose. Reading `.value` off [myActivitiesProvider] would hand
/// back `null` while the activities are still loading *and* again if they fail,
/// and a total summed from `null` is a confident `0` — which a player reads as
/// lost points rather than as "not here yet". Carrying the [AsyncValue] through
/// lets the screens draw a spinner and an error instead.
final myChallengePointsProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(myActivitiesProvider).whenData(_sum);
});

/// The current player's points this Monday-to-Sunday week.
final myWeekPointsProvider = Provider<AsyncValue<int>>((ref) {
  final now = ref.watch(nowProvider);

  return ref.watch(myActivitiesProvider).whenData(
        (mine) => _sum(
          mine
              .where(
                (activity) => AppDates.isInCurrentWeek(activity.date, now: now),
              )
              .toList(growable: false),
        ),
      );
});

int _sum(List<Activity> activities) =>
    activities.fold<int>(0, (total, activity) => total + activity.points);
