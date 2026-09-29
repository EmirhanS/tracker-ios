import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/challenge.dart';
import '../session/current_player_provider.dart';

/// The challenges the signed-in player is a member of.
final myChallengesProvider = StreamProvider<List<Challenge>>((ref) {
  final player = ref.watch(currentPlayerProvider);
  if (player == null) return Stream.value(const <Challenge>[]);

  return ref.watch(challengeRepositoryProvider).watchForPlayer(player.id);
});

/// Which challenge the player picked in the switcher.
///
/// Null means "nobody has picked one yet", which is not the same as "there is
/// none": [currentChallengeProvider] falls back to the first running challenge
/// so a player who never opens the switcher still lands somewhere.
///
/// Nothing here clears the choice when the session changes, and nothing needs
/// to: [currentChallengeProvider] only honours an id that names a running
/// challenge the *current* player is in, so a choice left behind by whoever
/// signed out falls back on its own.
class SelectedChallengeNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Points the tabs at [challengeId].
  void select(String challengeId) => state = challengeId;

  /// Goes back to the fallback, used when the chosen challenge is left behind.
  void clear() => state = null;
}

final selectedChallengeIdProvider =
    NotifierProvider<SelectedChallengeNotifier, String?>(
  SelectedChallengeNotifier.new,
);

/// The challenge the tabs are showing.
///
/// The switcher's choice when it still points at a running challenge the player
/// is in, otherwise the first running one. Drafts are left out on purpose:
/// there is nothing to log against a challenge that has not started, and the
/// screens read `null` as "no challenge yet".
final currentChallengeProvider = Provider<AsyncValue<Challenge?>>((ref) {
  final selectedId = ref.watch(selectedChallengeIdProvider);

  return ref.watch(myChallengesProvider).whenData((challenges) {
    Challenge? fallback;
    for (final challenge in challenges) {
      if (!challenge.isActive) continue;
      if (challenge.id == selectedId) return challenge;
      fallback ??= challenge;
    }
    return fallback;
  });
});

/// The activities logged in [currentChallengeProvider], newest first.
final currentChallengeActivitiesProvider =
    Provider<AsyncValue<List<Activity>>>((ref) {
  final challenge = ref.watch(currentChallengeProvider);
  final activities = ref.watch(allActivitiesProvider);

  return challenge.when(
    loading: AsyncValue<List<Activity>>.loading,
    error: AsyncValue<List<Activity>>.error,
    data: (challenge) {
      if (challenge == null) return const AsyncValue.data(<Activity>[]);
      return activities.whenData((all) {
        final mine = all
            .where((activity) => activity.challengeId == challenge.id)
            .toList(growable: false);
        return _newestFirst(mine);
      });
    },
  );
});

/// What [playerId] has scored in [challengeId], out of every logged activity.
///
/// A plain function rather than a `Provider.family`: the only caller is the
/// challenges list, which already holds the activities it would pass to one,
/// and a family would put a live provider behind every row of a screen that
/// exists to be left.
int pointsInChallenge(
  List<Activity> activities, {
  required String challengeId,
  required String playerId,
}) {
  var total = 0;
  for (final activity in activities) {
    if (activity.challengeId == challengeId && activity.playerId == playerId) {
      total += activity.points;
    }
  }
  return total;
}

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
