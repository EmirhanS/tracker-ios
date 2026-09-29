import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../features/challenge/challenge_invite_screen.dart';
import '../../features/challenge/challenge_join_screen.dart';
import '../../features/challenge/challenge_members_screen.dart';
import '../../features/challenge/challenge_new_screen.dart';
import '../../features/challenge/challenge_review_screen.dart';
import '../../features/challenge/challenge_rule_edit_screen.dart';
import '../../features/challenge/challenge_rules_screen.dart';
import '../../features/challenge/challenge_template_screen.dart';
import '../../features/challenge/challenges_list_screen.dart';
import '../../features/challenge/current_challenge_provider.dart';
import '../../features/challenge/scoring_rules_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/leaderboard/leaderboard_screen.dart';
import '../../features/log_activity/log_activity_screen.dart';
import '../../features/my_activities/my_activities_screen.dart';
import '../../features/session/current_player_provider.dart';
import '../../features/shell/app_shell.dart';
import '../../features/welcome/welcome_screen.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// The app router.
///
/// Two guards live here: nobody reaches the app without a current player, and
/// the three screens that set a challenge's rules are its owner's alone.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);

  // The session is the only thing the redirect reacts to. Refreshing on every
  // challenge write as well would make go_router re-parse the location and put
  // back a screen that was just popped, so editing a rule would never leave
  // the editor.
  ref.listen(isSignedInProvider, (_, _) => refresh.ping());

  // Subscribed on purpose, and deliberately pinging nothing.
  //
  // The owner check below *reads* the challenges, so they have to have been
  // loaded by the time a navigation happens rather than the first time a screen
  // asks for them. Both also have to stay subscribed for the life of the app:
  // the router outlives every screen, and a provider nothing is holding is only
  // brought up to date by the next widget that reads it — inside that widget's
  // `build`, where Riverpod's answer is to ask the whole scope to rebuild, and
  // Flutter's answer to that is an assertion. Holding them here means the work
  // happens between frames instead. Removing either line turns signing in and
  // starting a challenge into crashes.
  ref.listen(challengesProvider, (_, _) {});
  ref.listen(currentChallengeProvider, (_, _) {});

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

      // Setting the rules of a challenge belongs to the player who owns *that*
      // challenge. There is no single owner any more, so the check is per
      // challenge rather than a flag on the session.
      final ownerOnly =
          AppRoutes.ownerOnlyChallengePath.firstMatch(location);
      if (ownerOnly != null && !_owns(ref, ownerOnly.group(1)!)) {
        return AppRoutes.challenges;
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
        path: AppRoutes.challenges,
        builder: (context, state) => const ChallengesListScreen(),
      ),
      // `new` and `join` are declared before the `:challengeId` routes for
      // readability only: those take three segments, so neither can match here.
      GoRoute(
        path: AppRoutes.challengeNew,
        builder: (context, state) => const ChallengeNewScreen(),
      ),
      GoRoute(
        path: AppRoutes.challengeJoin,
        builder: (context, state) => const ChallengeJoinScreen(),
      ),
      GoRoute(
        path: '/challenges/:challengeId/template',
        builder: (context, state) => ChallengeTemplateScreen(
          challengeId: state.pathParameters['challengeId']!,
        ),
      ),
      GoRoute(
        path: '/challenges/:challengeId/rules',
        builder: (context, state) => ChallengeRulesScreen(
          challengeId: state.pathParameters['challengeId']!,
        ),
        routes: [
          GoRoute(
            path: ':ruleId',
            builder: (context, state) => ChallengeRuleEditScreen(
              challengeId: state.pathParameters['challengeId']!,
              ruleId: state.pathParameters['ruleId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/challenges/:challengeId/review',
        builder: (context, state) => ChallengeReviewScreen(
          challengeId: state.pathParameters['challengeId']!,
        ),
      ),
      GoRoute(
        path: '/challenges/:challengeId/invite',
        builder: (context, state) => ChallengeInviteScreen(
          challengeId: state.pathParameters['challengeId']!,
        ),
      ),
      GoRoute(
        path: '/challenges/:challengeId/members',
        builder: (context, state) => ChallengeMembersScreen(
          challengeId: state.pathParameters['challengeId']!,
        ),
      ),
    ],
  );
});

/// True when the signed-in player owns [challengeId].
///
/// A challenge the store has not handed over yet lets the navigation through:
/// the screen behind it reads the same challenge and draws its own not-found
/// state, which beats bouncing the player off a screen that was about to load.
bool _owns(Ref ref, String challengeId) {
  final player = ref.read(currentPlayerProvider);
  if (player == null) return false;

  final challenges = ref.read(challengesProvider).value;
  if (challenges == null) return true;

  for (final challenge in challenges) {
    if (challenge.id == challengeId) return challenge.ownerId == player.id;
  }
  // Not a challenge at all. The screen says so better than a redirect does.
  return true;
}

/// Tells go_router to run its redirects again when the session changes, so the
/// guards above never work from stale state.
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
