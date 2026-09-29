/// Every path in the app, in one place.
abstract final class AppRoutes {
  static const String welcome = '/welcome';

  static const String dashboard = '/dashboard';
  static const String log = '/log';
  static const String activities = '/activities';
  static const String leaderboard = '/leaderboard';

  /// The read-only rules screen, open to everybody.
  static const String scoringRules = '/scoring-rules';

  /// The challenges the signed-in player belongs to.
  static const String challenges = '/challenges';

  /// Step one of creating a challenge. Open to everybody: a player who is in
  /// no challenge, or in five, can still start another.
  static const String challengeNew = '/challenges/new';

  /// Typing a code somebody read out.
  static const String challengeJoin = '/challenges/join';

  static String challengeTemplate(String challengeId) =>
      '/challenges/$challengeId/template';

  static String challengeRules(String challengeId) =>
      '/challenges/$challengeId/rules';

  static String challengeRule(String challengeId, String ruleId) =>
      '/challenges/$challengeId/rules/$ruleId';

  /// The id used for a rule that is being created rather than edited.
  static const String newRuleId = 'new';

  static String challengeNewRule(String challengeId) =>
      '/challenges/$challengeId/rules/$newRuleId';

  static String challengeReview(String challengeId) =>
      '/challenges/$challengeId/review';

  /// The join code, big enough to read out.
  static String challengeInvite(String challengeId) =>
      '/challenges/$challengeId/invite';

  static String challengeMembers(String challengeId) =>
      '/challenges/$challengeId/members';

  /// The three screens only the owner of that challenge may open.
  ///
  /// The router matches on this rather than on the whole `/challenges` prefix:
  /// the list, the create step, the join screen, the invite and the member list
  /// are everybody's.
  static final RegExp ownerOnlyChallengePath =
      RegExp(r'^/challenges/([^/]+)/(template|rules|review)(/|$)');

  /// The tab paths, in the order they appear in the bottom bar.
  static const List<String> tabs = [dashboard, log, activities, leaderboard];
}
