import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_routes.dart';
import '../../data/providers.dart';
import '../../domain/models/season.dart';

/// The draft the captain left behind, if there is one.
///
/// Setup can be left at any step, so the next visit picks the draft up instead
/// of making a second one.
final draftSeasonProvider = Provider<Season?>((ref) {
  final seasons = ref.watch(seasonsProvider).value;
  if (seasons == null) return null;

  Season? newest;
  for (final season in seasons) {
    if (!season.isDraft) continue;
    if (newest == null || season.startDate.isAfter(newest.startDate)) {
      newest = season;
    }
  }
  return newest;
});

/// Where the "Set up a season" button goes.
///
/// A fresh start goes to the name and dates. An unfinished draft goes back to
/// the step it stopped at.
final seasonSetupRouteProvider = Provider<String>((ref) {
  final draft = ref.watch(draftSeasonProvider);
  if (draft == null) return AppRoutes.seasonNew;

  return draft.rules.isEmpty
      ? AppRoutes.seasonTemplate(draft.id)
      : AppRoutes.seasonRules(draft.id);
});
