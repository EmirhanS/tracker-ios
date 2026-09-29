import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/player.dart';
import '../../domain/models/season.dart';

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

/// The season that decides who the captain is.
///
/// The running season if there is one, otherwise the newest season set up.
Season? _captainSeason(List<Season> seasons) {
  Season? newest;
  for (final season in seasons) {
    if (season.isActive) return season;
    if (newest == null || season.startDate.isAfter(newest.startDate)) {
      newest = season;
    }
  }
  return newest;
}

/// True when the current player may set up a season.
///
/// The captain of the current season may. When no season has ever been set up,
/// anybody may, so a fresh team is not locked out.
final isCaptainProvider = Provider<bool>((ref) {
  final player = ref.watch(currentPlayerProvider);
  if (player == null) return false;

  final seasons = ref.watch(seasonsProvider).value;
  if (seasons == null || seasons.isEmpty) return true;

  final season = _captainSeason(seasons);
  return season == null || season.captainId == player.id;
});
