import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/leaderboard/leaderboard_screen.dart';
import '../../features/log_activity/log_activity_screen.dart';
import '../../features/my_activities/my_activities_screen.dart';
import '../../features/season/scoring_rules_screen.dart';
import '../../features/season/season_new_screen.dart';
import '../../features/season/season_review_screen.dart';
import '../../features/season/season_rule_edit_screen.dart';
import '../../features/season/season_rules_screen.dart';
import '../../features/season/season_template_screen.dart';
import '../../features/session/current_player_provider.dart';
import '../../features/shell/app_shell.dart';
import '../../features/welcome/welcome_screen.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// The app router.
///
/// Two guards live here: nobody reaches the app without a current player, and
/// only the captain reaches season setup.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);

  // Only the three things the redirect below actually reads. Refreshing on
  // every season write instead would make go_router re-parse the location and
  // put back a screen that was just popped, so editing a rule would never
  // leave the editor.
  ref.listen(isSignedInProvider, (_, _) => refresh.ping());
  ref.listen(isCaptainProvider, (_, _) => refresh.ping());
  ref.listen(
    activeSeasonProvider.select((season) => season.value != null),
    (_, _) => refresh.ping(),
  );

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.welcome,
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = ref.read(isSignedInProvider);
      final location = state.matchedLocation;

      if (!signedIn) {
        return location == AppRoutes.welcome ? null : AppRoutes.welcome;
      }

      if (location == AppRoutes.welcome) {
        return AppRoutes.dashboard;
      }

      if (location.startsWith('/season')) {
        // Season setup is the captain's job. Everyone else gets sent back.
        if (!ref.read(isCaptainProvider)) return AppRoutes.dashboard;

        // A running season locks its rules, so setup is closed while one runs.
        final active = ref.read(activeSeasonProvider).value;
        if (active != null) return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.log,
                builder: (context, state) => const LogActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.activities,
                builder: (context, state) => const MyActivitiesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.leaderboard,
                builder: (context, state) => const LeaderboardScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.scoringRules,
        builder: (context, state) => const ScoringRulesScreen(),
      ),
      GoRoute(
        path: AppRoutes.seasonNew,
        builder: (context, state) => const SeasonNewScreen(),
      ),
      GoRoute(
        path: '/season/:seasonId/template',
        builder: (context, state) => SeasonTemplateScreen(
          seasonId: state.pathParameters['seasonId']!,
        ),
      ),
      GoRoute(
        path: '/season/:seasonId/rules',
        builder: (context, state) => SeasonRulesScreen(
          seasonId: state.pathParameters['seasonId']!,
        ),
        routes: [
          GoRoute(
            path: ':ruleId',
            builder: (context, state) => SeasonRuleEditScreen(
              seasonId: state.pathParameters['seasonId']!,
              ruleId: state.pathParameters['ruleId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/season/:seasonId/review',
        builder: (context, state) => SeasonReviewScreen(
          seasonId: state.pathParameters['seasonId']!,
        ),
      ),
    ],
  );
});

/// Tells go_router to run its redirects again when the session or the seasons
/// change, so the guards above never work from stale state.
class _RouterRefresh extends ChangeNotifier {
  bool _disposed = false;

  void ping() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
