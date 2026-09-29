import '../../domain/models/scoring_rule.dart';
import '../../domain/points/points_engine.dart';
import '../../domain/validation/rule_validator.dart';
import '../../domain/validation/challenge_validator.dart';

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
  static const String dashboardChallengePoints = 'Challenge points';
  static const String dashboardWeekPoints = 'This week';
  static const String dashboardRecentActivities = 'Recent activities';
  static const String dashboardNoActivitiesTitle = 'No activities yet';
  static const String dashboardNoActivitiesBody =
      'Log your first workout to get on the board.';
  static const String dashboardLogActivity = 'Log activity';
  static const String dashboardNoChallengeTitle = 'No active challenge';
  static const String dashboardNoChallengeBody =
      'A challenge must be running before anyone can score points.';
  static const String dashboardNoChallengeOwnerBody =
      'Set up a challenge to start scoring, then invite the others with its '
      'join code.';
  static const String dashboardSetUpChallenge = 'Set up a challenge';
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
      'The active challenge has no enabled activities.';
  static const String logDateInFuture = 'The date cannot be in the future.';
  static const String logDateOutsideChallenge =
      'The date is outside the active challenge.';
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
  static const String leaderboardOwner = 'Owner';

  // ---------------------------------------------------------- scoring rules
  static const String scoringRulesTitle = 'Scoring rules';
  static const String scoringRulesEmptyTitle = 'No scoring rules';
  static const String scoringRulesEmptyBody =
      'The owner sets the rules of a challenge.';
  static const String scoringRulesDisabled = 'Off';

  /// Owner only, on the read-only rules screen of a running challenge.
  static const String scoringRulesEdit = 'Edit rules';

  // ------------------------------------------------------------- challenges
  static const String challengesTitle = 'Challenges';
  static const String challengesCreate = 'Create a challenge';
  static const String challengesJoin = 'Join with a code';
  static const String challengesEmptyTitle = 'No challenges yet';
  static const String challengesEmptyBody =
      'Create one and invite your friends, or join one with a code somebody '
      'sent you.';
  static const String challengesOwnerMark = 'Owner';
  static const String challengesDraftMark = 'Draft';
  static const String challengesAll = 'All challenges';
  static const String challengesPick = 'Choose a challenge';
  static const String challengesNoneChosen = 'No challenge';

  // ---------------------------------------------------------------- invite
  static const String inviteTitle = 'Invite a friend';
  static const String inviteBody =
      'Send this code to a friend so they can join the challenge.';
  static const String inviteCopy = 'Copy code';
  static const String inviteCopied = 'Code copied.';
  static const String inviteNewCode = 'New code';
  static const String inviteNewCodeTitle = 'Make a new code?';
  static const String inviteNewCodeBody =
      'The old code stops working straight away, so anybody still holding it '
      'cannot join.';
  static const String inviteNewCodeAction = 'Yes, replace it';
  static const String inviteDone = 'Done';

  // ------------------------------------------------------------------ join
  static const String joinTitle = 'Join with a code';
  static const String joinCodeLabel = 'Join code';
  static const String joinCodeHint = 'Six letters and numbers';
  static const String joinLookUp = 'Find the challenge';
  static const String joinNotFound =
      'No challenge has that code. Check it and try again.';
  static const String joinAlreadyMember = 'You are already in this challenge.';
  static const String joinOpenInstead = 'Open it';
  static const String joinPreviewTitle = 'Join this challenge?';
  static const String joinConfirm = 'Join';
  static const String joinFailed = 'Could not join that challenge. Try again.';
  static const String joinSucceeded = 'You joined the challenge.';

  // --------------------------------------------------------------- members
  static const String membersTitle = 'Members';
  static const String membersUnknownPlayer = 'Unknown player';
  static const String membersRemove = 'Remove';
  static const String membersRemoveTitle = 'Remove from the challenge?';
  static const String membersRemoveBody =
      'They drop off the leaderboard. They can join again with the code.';
  static const String membersRemoveFailed =
      'Could not remove that member. Try again.';
  static const String membersLeave = 'Leave challenge';
  static const String membersLeaveTitle = 'Leave this challenge?';
  static const String membersLeaveBody =
      'You stop scoring in it. You can join again with the code.';
  static const String membersLeaveAction = 'Yes, leave';
  static const String membersLeaveFailed =
      'Could not leave that challenge. Try again.';

  // ----------------------------------------------------------- challenge setup
  static const String challengeNewTitle = 'New challenge';
  static const String challengeName = 'Challenge name';
  static const String challengeNameHint = 'For example: Autumn 2026';
  static const String challengeStartDate = 'Start date';
  static const String challengeEndDate = 'End date';
  static const String challengeCreate = 'Create challenge';

  static const String challengeTemplateTitle = 'Choose a template';
  static const String challengeTemplateBody =
      'A template fills the challenge with a set of scoring rules. You can change '
      'them in the next step.';
  static const String challengeTemplateUse = 'Use this template';

  static const String challengeRulesTitle = 'Scoring rules';
  static const String challengeRulesBody =
      'Turn rules off you do not want, or change how many points they give.';
  static const String challengeRulesAdd = 'Add rule';
  static const String challengeRulesReview = 'Review and start';
  static const String challengeRulesNoneEnabled =
      'Turn on at least one rule before you start the challenge.';

  static const String challengeRuleEditTitle = 'Edit rule';
  static const String challengeRuleNewTitle = 'New rule';
  static const String challengeRuleName = 'Rule name';
  static const String challengeRuleEmoji = 'Emoji (optional)';
  static const String challengeRuleEnabled = 'Rule is on';
  static const String challengeRuleScoringType = 'Scoring type';
  static const String challengeRuleTypeFixed = 'Fixed points';
  static const String challengeRuleTypeTime = 'Points per time block';
  static const String challengeRuleTypeDistance = 'Points by distance';
  static const String challengeRulePoints = 'Points';
  static const String challengeRuleMinDuration = 'Minimum duration (minutes)';
  static const String challengeRuleMinDurationOptional =
      'Minimum duration (minutes, optional)';
  static const String challengeRulePointsPerBlock = 'Points per block';
  static const String challengeRuleMinutesPerBlock = 'Minutes per block';
  static const String challengeRuleTiers = 'Distance tiers';
  static const String challengeRuleTierAdd = 'Add tier';
  static const String challengeRuleTierFrom = 'From (km)';
  static const String challengeRuleTierPoints = 'Points';
  static const String challengeRuleDelete = 'Delete rule';

  static const String challengeReviewTitle = 'Review challenge';
  static const String challengeReviewRules = 'Active rules';
  static const String challengeReviewStart = 'Start challenge';
  static const String challengeReviewConfirmTitle = 'Start the challenge?';
  static const String challengeReviewConfirmBody =
      'After the challenge starts, its dates are fixed and players can log '
      'activities right away. You can still change the rules.';
  static const String challengeReviewConfirmAction = 'Yes, start it';
  static const String challengeStarted = 'The challenge has started.';
  static const String challengeOwnerOnly =
      'Only the owner of a challenge can set its rules.';

  /// Shown in the rules editor while the challenge is already running.
  static const String challengeRulesLiveNote =
      'Changes count from now on. Points already earned do not change.';

  // ------------------------------------------------------------------ dates
  static const String today = 'Today';
  static const String yesterday = 'Yesterday';

  // ----------------------------------------------------------------- errors
  static const String errorGeneric = 'Something went wrong.';
  static const String errorNotFound = 'That item no longer exists.';

  // ------------------------------------------------------- error to text map

  /// Plain text for a points engine error.
  static String pointsError(PointsError error) => switch (error) {
        RuleDisabled() => 'This activity is switched off for this challenge.',
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

  /// Plain text for a challenge name or date problem.
  static String challengeDetailsError(ChallengeDetailsError error) => switch (error) {
        ChallengeDetailsError.nameRequired => 'Give the challenge a name.',
        ChallengeDetailsError.endNotAfterStart =>
          'The end date must be after the start date.',
      };

  /// Plain text for a reason the challenge cannot start.
  static String challengeStartError(ChallengeStartError error) => switch (error) {
        NoEnabledRules() => challengeRulesNoneEnabled,
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

  /// "1 member" or "7 members".
  static String formatMembers(int members) =>
      members == 1 ? '1 member' : '$members members';

  /// "ABCDEF" read out loud as "ABC DEF".
  ///
  /// A code is split in halves so somebody can say it across a room without
  /// losing their place. The gap is display only — [JoinCode.normalize] takes
  /// it back out when the other player types it in.
  static String groupJoinCode(String code) {
    if (code.length < 4) return code;
    final half = code.length ~/ 2;
    return '${code.substring(0, half)} ${code.substring(half)}';
  }

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
