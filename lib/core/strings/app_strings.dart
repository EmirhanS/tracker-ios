import '../../domain/models/scoring_rule.dart';
import '../../domain/points/points_engine.dart';
import '../../domain/validation/rule_validator.dart';
import '../../domain/validation/season_validator.dart';

/// All user-facing text in the app, in English.
///
/// Keeping the text in one place means a translation layer can replace this
/// class later without touching the screens.
abstract final class AppStrings {
  // ---------------------------------------------------------------- general
  static const String appName = 'SportTracker';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String back = 'Back';
  static const String next = 'Next';
  static const String done = 'Done';
  static const String points = 'points';
  static const String pointsShort = 'pts';

  // ---------------------------------------------------------------- welcome
  static const String welcomeTitle = 'SportTracker';
  static const String welcomeTagline = 'Train. Log. Climb the table.';
  static const String welcomeChoosePlayer = 'Who are you?';
  static const String welcomeContinue = 'Continue';

  // -------------------------------------------------------------- navigation
  static const String navDashboard = 'Dashboard';
  static const String navLog = 'Log';
  static const String navActivities = 'My activities';
  static const String navLeaderboard = 'Leaderboard';

  // -------------------------------------------------------------- dashboard
  static const String dashboardTitle = 'Dashboard';
  static const String dashboardSeasonPoints = 'Season points';
  static const String dashboardWeekPoints = 'This week';
  static const String dashboardRecentActivities = 'Recent activities';
  static const String dashboardNoActivitiesTitle = 'No activities yet';
  static const String dashboardNoActivitiesBody =
      'Log your first workout to get on the board.';
  static const String dashboardLogActivity = 'Log activity';
  static const String dashboardNoSeasonTitle = 'No active season';
  static const String dashboardNoSeasonBody =
      'A season must be running before anyone can score points.';
  static const String dashboardNoSeasonCaptainBody =
      'You are the captain. Set up a season to start scoring.';
  static const String dashboardSetUpSeason = 'Set up a season';
  static const String dashboardSeeAll = 'See all';

  // ------------------------------------------------------------ log activity
  static const String logTitle = 'Log activity';
  static const String logRule = 'Activity';
  static const String logRuleHint = 'Choose an activity';
  static const String logDate = 'Date';
  static const String logDuration = 'Duration (minutes)';
  static const String logDistance = 'Distance (km)';
  static const String logNotes = 'Notes (optional)';
  static const String logPreview = 'You will earn';
  static const String logSubmit = 'Log activity';
  static const String logSaved = 'Activity logged.';
  static const String logNoRules =
      'The active season has no enabled activities.';
  static const String logDateInFuture = 'The date cannot be in the future.';
  static const String logDateOutsideSeason =
      'The date is outside the active season.';
  static const String logDurationNotANumber =
      'Enter the duration as a whole number of minutes.';
  static const String logDistanceNotANumber =
      'Enter the distance as a number, for example 5.5.';

  // ----------------------------------------------------------- my activities
  static const String activitiesTitle = 'My activities';
  static const String activitiesEmptyTitle = 'Nothing logged yet';
  static const String activitiesEmptyBody =
      'Your logged activities show up here.';
  static const String activitiesSwipeHint = 'Swipe an entry left to delete it.';
  static const String activitiesDeleted = 'Activity deleted.';
  static const String activitiesDeleteFailed =
      'Could not delete that activity. Try again.';
  static const String activitiesDeleteTitle = 'Delete activity?';
  static const String activitiesDeleteBody =
      'The points for this activity are removed from your total.';

  // ------------------------------------------------------------- leaderboard
  static const String leaderboardTitle = 'Leaderboard';
  static const String leaderboardEmptyTitle = 'No points yet';
  static const String leaderboardEmptyBody =
      'The table fills up as the team logs activities.';
  static const String leaderboardYou = 'You';
  static const String leaderboardCaptain = 'Captain';

  // ---------------------------------------------------------- scoring rules
  static const String scoringRulesTitle = 'Scoring rules';
  static const String scoringRulesEmptyTitle = 'No scoring rules';
  static const String scoringRulesEmptyBody =
      'The captain sets the rules when the season is created.';
  static const String scoringRulesDisabled = 'Off';

  // ----------------------------------------------------------- season setup
  static const String seasonNewTitle = 'New season';
  static const String seasonName = 'Season name';
  static const String seasonNameHint = 'For example: Autumn 2026';
  static const String seasonStartDate = 'Start date';
  static const String seasonEndDate = 'End date';
  static const String seasonCreate = 'Create season';

  static const String seasonTemplateTitle = 'Choose a template';
  static const String seasonTemplateBody =
      'A template fills the season with a set of scoring rules. You can change '
      'them in the next step.';
  static const String seasonTemplateUse = 'Use this template';

  static const String seasonRulesTitle = 'Scoring rules';
  static const String seasonRulesBody =
      'Turn rules off you do not want, or change how many points they give.';
  static const String seasonRulesAdd = 'Add rule';
  static const String seasonRulesReview = 'Review and start';
  static const String seasonRulesNoneEnabled =
      'Turn on at least one rule before you start the season.';

  static const String seasonRuleEditTitle = 'Edit rule';
  static const String seasonRuleNewTitle = 'New rule';
  static const String seasonRuleName = 'Rule name';
  static const String seasonRuleEmoji = 'Emoji (optional)';
  static const String seasonRuleEnabled = 'Rule is on';
  static const String seasonRuleScoringType = 'Scoring type';
  static const String seasonRuleTypeFixed = 'Fixed points';
  static const String seasonRuleTypeTime = 'Points per time block';
  static const String seasonRuleTypeDistance = 'Points by distance';
  static const String seasonRulePoints = 'Points';
  static const String seasonRuleMinDuration = 'Minimum duration (minutes)';
  static const String seasonRuleMinDurationOptional =
      'Minimum duration (minutes, optional)';
  static const String seasonRulePointsPerBlock = 'Points per block';
  static const String seasonRuleMinutesPerBlock = 'Minutes per block';
  static const String seasonRuleTiers = 'Distance tiers';
  static const String seasonRuleTierAdd = 'Add tier';
  static const String seasonRuleTierFrom = 'From (km)';
  static const String seasonRuleTierPoints = 'Points';
  static const String seasonRuleDelete = 'Delete rule';

  static const String seasonReviewTitle = 'Review season';
  static const String seasonReviewRules = 'Active rules';
  static const String seasonReviewStart = 'Start season';
  static const String seasonReviewConfirmTitle = 'Start the season?';
  static const String seasonReviewConfirmBody =
      'After the season starts, the scoring rules are locked. Players can log '
      'activities right away.';
  static const String seasonReviewConfirmAction = 'Yes, start it';
  static const String seasonStarted = 'The season has started.';
  static const String seasonLocked =
      'The season is running, so its rules can no longer be changed.';
  static const String seasonCaptainOnly =
      'Only the team captain can set up a season.';

  // ------------------------------------------------------------------ dates
  static const String today = 'Today';
  static const String yesterday = 'Yesterday';

  // ----------------------------------------------------------------- errors
  static const String errorGeneric = 'Something went wrong.';
  static const String errorNotFound = 'That item no longer exists.';

  // ------------------------------------------------------- error to text map

  /// Plain text for a points engine error.
  static String pointsError(PointsError error) => switch (error) {
        RuleDisabled() => 'This activity is switched off for this season.',
        DurationRequired() => 'Enter how long the activity was.',
        BelowMinimumDuration(:final minimumMinutes) =>
          'This activity must last at least '
              '${formatMinutes(minimumMinutes)} to score.',
        DistanceRequired() => 'Enter how far you went.',
        BelowMinimumDistance(:final minimumKm) =>
          'You need at least ${formatKm(minimumKm)} to score.',
      };

  /// Plain text for a scoring rule problem.
  static String ruleError(RuleValidationError error) => switch (error) {
        RuleValidationError.nameRequired => 'Give the rule a name.',
        RuleValidationError.nameNotUnique =>
          'Another rule already uses this name.',
        RuleValidationError.pointsOutOfRange =>
          'Points must be between $minRulePoints and $maxRulePoints.',
        RuleValidationError.minDurationNotPositive =>
          'The minimum duration must be at least 1 minute.',
        RuleValidationError.minutesPerBlockTooSmall =>
          'A block must be at least 1 minute long.',
        RuleValidationError.minDurationBelowBlock =>
          'The minimum duration must be at least one whole block.',
        RuleValidationError.tiersRequired => 'Add at least one distance tier.',
        RuleValidationError.tierDistanceNotPositive =>
          'Every tier must start above 0 km.',
        RuleValidationError.tierDistanceNotUnique =>
          'Two tiers start at the same distance.',
        RuleValidationError.tierPointsDecreasing =>
          'A longer distance cannot give fewer points.',
      };

  /// Plain text for a season name or date problem.
  static String seasonDetailsError(SeasonDetailsError error) => switch (error) {
        SeasonDetailsError.nameRequired => 'Give the season a name.',
        SeasonDetailsError.endNotAfterStart =>
          'The end date must be after the start date.',
      };

  /// Plain text for a reason the season cannot start.
  static String seasonStartError(SeasonStartError error) => switch (error) {
        NoEnabledRules() => seasonRulesNoneEnabled,
        InvalidRule(:final ruleName, :final errors) =>
          '$ruleName: ${errors.map(ruleError).join(' ')}',
      };

  // -------------------------------------------------------------- formatting

  /// "45 min" or "1 h 30 min".
  static String formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h $rest min';
  }

  /// "5 km" or "7.5 km". Infinity is never shown to a player, but a rule with
  /// no tiers would reach here, so it gets readable text.
  static String formatKm(double km) {
    if (km.isInfinite) return 'any distance';
    final rounded = (km * 10).round() / 10;
    final text =
        rounded == rounded.roundToDouble() ? '${rounded.round()}' : '$rounded';
    return '$text km';
  }

  /// "1 point" or "4 points".
  static String formatPoints(int points) =>
      points == 1 ? '1 point' : '$points points';

  /// A one-line summary of how a rule scores, for the rules list.
  static String describeScoring(Scoring scoring) => switch (scoring) {
        FixedScoring(:final points, :final minDurationMinutes) =>
          minDurationMinutes == null
              ? formatPoints(points)
              : '${formatPoints(points)} · from '
                  '${formatMinutes(minDurationMinutes)}',
        TimeBasedScoring(
          :final pointsPerBlock,
          :final minutesPerBlock,
          :final minDurationMinutes,
        ) =>
          '${formatPoints(pointsPerBlock)} per '
              '${formatMinutes(minutesPerBlock)} · from '
              '${formatMinutes(minDurationMinutes)}',
        DistanceTierScoring(:final tiers) => tiers.isEmpty
            ? 'No tiers set'
            : DistanceTierScoring(tiers: tiers)
                .tiersLowestFirst
                .map((tier) => '${formatKm(tier.minKm)} → ${tier.points}')
                .join(' · '),
      };
}
