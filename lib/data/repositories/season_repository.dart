import '../../domain/models/scoring_rule.dart';
import '../../domain/models/season.dart';

/// Reads and writes seasons.
///
/// The rules of an active season are locked: [updateSeason] throws a
/// `SeasonLockedException` for a season that is already running.
abstract interface class SeasonRepository {
  Future<List<Season>> getAll();

  Future<Season?> getById(String id);

  /// The season that is running now, or null.
  Future<Season?> getActiveSeason();

  /// A rule id that no season has used.
  ///
  /// The repository owns rule ids because `Activity.ruleId` is stored per
  /// activity and `Season.ruleById` looks a rule up by id alone: if two seasons
  /// shared `rule_1`, an activity logged in one would resolve to a different
  /// rule in the other. Callers building rules - `SeasonTemplate.buildRules`
  /// and the rule editor - must take ids from here rather than from a counter
  /// of their own. Behind Supabase the database hands these out instead.
  String nextRuleId();

  /// Creates a season in draft with the rules it is given.
  Future<Season> createDraft({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required String captainId,
    List<ScoringRule> rules,
  });

  /// Saves changes to a draft season.
  ///
  /// Throws `SeasonLockedException` when the stored season is active, and
  /// `NotFoundException` when it does not exist.
  Future<Season> updateSeason(Season season);

  /// Checks the season and, if it passes, sets it active.
  ///
  /// Only one season runs at a time, so this throws `StateError` when another
  /// season is already active or when the season does not pass
  /// `SeasonValidator.validateForStart`. Throws `NotFoundException` when the
  /// season does not exist.
  Future<Season> startSeason(String seasonId);

  /// Emits every season, then again after every change.
  Stream<List<Season>> watchAll();

  /// Emits the active season, then again after every change.
  Stream<Season?> watchActiveSeason();
}
