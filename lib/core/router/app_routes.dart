/// Every path in the app, in one place.
abstract final class AppRoutes {
  static const String welcome = '/welcome';

  static const String dashboard = '/dashboard';
  static const String log = '/log';
  static const String activities = '/activities';
  static const String leaderboard = '/leaderboard';

  /// The read-only rules screen, open to everybody.
  static const String scoringRules = '/scoring-rules';

  /// Season setup, captain only.
  static const String seasonNew = '/season/new';

  static String seasonTemplate(String seasonId) => '/season/$seasonId/template';

  static String seasonRules(String seasonId) => '/season/$seasonId/rules';

  static String seasonRule(String seasonId, String ruleId) =>
      '/season/$seasonId/rules/$ruleId';

  /// The id used for a rule that is being created rather than edited.
  static const String newRuleId = 'new';

  static String seasonNewRule(String seasonId) =>
      '/season/$seasonId/rules/$newRuleId';

  static String seasonReview(String seasonId) => '/season/$seasonId/review';

  /// The tab paths, in the order they appear in the bottom bar.
  static const List<String> tabs = [dashboard, log, activities, leaderboard];
}
