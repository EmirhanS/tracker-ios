import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/player.dart';
import '../../domain/models/challenge.dart';

/// Who is using the app.
///
/// v1 has no accounts: the welcome screen picks a player from the roster. This
/// notifier is the only place that knows it, so Google or Apple sign-in can
/// replace the inside of it without touching any screen.
class CurrentPlayerNotifier extends Notifier<Player?> {
  @override
  Player? build() => null;

  /// Signs [player] in.
  void signIn(Player player) => state = player;

  /// Signs the current player out.
  void signOut() => state = null;
}

final currentPlayerProvider =
    NotifierProvider<CurrentPlayerNotifier, Player?>(CurrentPlayerNotifier.new);

/// True when somebody is signed in.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(currentPlayerProvider) != null;
});

/// The challenge that decides who the owner is.
///
/// The running challenge if there is one, otherwise the newest challenge set up.
Challenge? _ownerChallenge(List<Challenge> challenges) {
  Challenge? newest;
  for (final challenge in challenges) {
    if (challenge.isActive) return challenge;
    if (newest == null || challenge.startDate.isAfter(newest.startDate)) {
      newest = challenge;
    }
  }
  return newest;
}

/// True when the current player may set up a challenge.
///
/// The owner of the current challenge may. When no challenge has ever been set up,
/// anybody may, so a fresh team is not locked out.
final isOwnerProvider = Provider<bool>((ref) {
  final player = ref.watch(currentPlayerProvider);
  if (player == null) return false;

  final challenges = ref.watch(challengesProvider).value;
  if (challenges == null || challenges.isEmpty) return true;

  final challenge = _ownerChallenge(challenges);
  return challenge == null || challenge.ownerId == player.id;
});
