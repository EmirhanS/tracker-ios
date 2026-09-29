import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../leaderboard/leaderboard_provider.dart';
import '../my_activities/my_activities_provider.dart';
import 'current_challenge_provider.dart';

/// Points the tabs at [challengeId], and settles everything that reads it.
///
/// The reads below are the whole reason this exists, and none of them is idle.
///
/// Writing the choice leaves every provider derived from it stale. Each caller
/// then goes to a screen that mounts fresh and subscribes to those providers
/// for the first time — and flushing a stale chain from inside a widget's
/// `build` makes Riverpod ask the whole scope to rebuild, which Flutter
/// refuses in the middle of a build. Reading them here does the same work one
/// moment earlier, in the tap, where it is allowed.
///
/// This file sits above the providers it settles so it can import all of them;
/// putting the function next to `currentChallengeProvider` would mean
/// importing the leaves back down into their own root.
///
/// A provider scoped to the current challenge that is missing from this list is
/// a screen waiting to throw on the way in.
void selectChallenge(WidgetRef ref, String challengeId) {
  ref.read(selectedChallengeIdProvider.notifier).select(challengeId);

  ref.read(currentChallengeProvider);
  ref.read(currentChallengeActivitiesProvider);
  ref.read(myActivitiesProvider);
  ref.read(myChallengePointsProvider);
  ref.read(myWeekPointsProvider);
  ref.read(leaderboardProvider);
}
