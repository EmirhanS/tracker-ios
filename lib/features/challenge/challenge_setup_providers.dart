import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_routes.dart';
import '../../data/providers.dart';
import '../../domain/models/challenge.dart';
import '../session/current_player_provider.dart';

/// The draft the signed-in player left behind, if there is one.
///
/// Setup can be left at any step, so the next visit picks the draft up instead
/// of making a second one. Scoped to the player who owns it: several players
/// set challenges up in v2, and somebody else's half-built draft is none of
/// this player's business.
final draftChallengeProvider = Provider<Challenge?>((ref) {
  final player = ref.watch(currentPlayerProvider);
  if (player == null) return null;

  final challenges = ref.watch(challengesProvider).value;
  if (challenges == null) return null;

  Challenge? newest;
  for (final challenge in challenges) {
    if (!challenge.isDraft || challenge.ownerId != player.id) continue;
    if (newest == null || challenge.startDate.isAfter(newest.startDate)) {
      newest = challenge;
    }
  }
  return newest;
});

/// Where the "Set up a challenge" button goes.
///
/// A fresh start goes to the name and dates. An unfinished draft goes back to
/// the step it stopped at.
final challengeSetupRouteProvider = Provider<String>((ref) {
  final draft = ref.watch(draftChallengeProvider);
  if (draft == null) return AppRoutes.challengeNew;

  return draft.rules.isEmpty
      ? AppRoutes.challengeTemplate(draft.id)
      : AppRoutes.challengeRules(draft.id);
});
