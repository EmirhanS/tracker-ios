import '../../domain/models/challenge.dart';
import '../../domain/models/scoring_rule.dart';

/// Reads and writes challenges, and owns who is in them.
///
/// Several challenges run at once and a player can be in more than one, so
/// there is no "the current challenge" here. Ask [watchForPlayer] instead.
abstract interface class ChallengeRepository {
  Future<List<Challenge>> getAll();

  Future<Challenge?> getById(String id);

  /// The challenge holding [code], or null.
  ///
  /// [code] is normalised first, so what a player typed is fine.
  Future<Challenge?> getByJoinCode(String code);

  /// A rule id that no challenge has used.
  ///
  /// The repository owns rule ids because `Activity.ruleId` is stored per
  /// activity and `Challenge.ruleById` looks a rule up by id alone: if two
  /// challenges shared `rule_1`, an activity logged in one would resolve to a
  /// different rule in the other. Callers building rules -
  /// `ChallengeTemplate.buildRules` and the rule editor - must take ids from
  /// here rather than from a counter of their own. Behind Supabase the database
  /// hands these out instead.
  String nextRuleId();

  /// Creates a challenge in draft with the rules it is given.
  ///
  /// It gets a join code no other challenge holds, and [ownerId] as its only
  /// member.
  Future<Challenge> createDraft({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required String ownerId,
    List<ScoringRule> rules,
  });

  /// Saves changes to the name, the dates or the rules of a challenge.
  ///
  /// The status, the owner, the join code and the member list are owned by the
  /// methods below, so whatever [challenge] carries for those is ignored.
  ///
  /// Throws `ChallengeLockedException` when the stored challenge is running and
  /// the dates differ, and `NotFoundException` when it does not exist.
  Future<Challenge> updateChallenge(Challenge challenge);

  /// Checks the challenge and, if it passes, sets it active.
  ///
  /// Several challenges may run at the same time, so this only throws
  /// `StateError` when the challenge does not pass
  /// `ChallengeValidator.validateForStart`. Throws `NotFoundException` when the
  /// challenge does not exist.
  Future<Challenge> startChallenge(String challengeId);

  /// Adds [playerId] to the challenge holding [code].
  ///
  /// [code] is normalised first. Joining a challenge the player is already in
  /// changes nothing and is not an error. Throws `NotFoundException` when no
  /// challenge holds the code.
  Future<Challenge> joinByCode({
    required String code,
    required String playerId,
  });

  /// Takes [playerId] out of the challenge.
  ///
  /// Leaving twice changes nothing. Throws `StateError` when [playerId] owns
  /// the challenge - an owner has to hand it over or end it, not walk away from
  /// it - and `NotFoundException` when the challenge does not exist.
  Future<Challenge> leaveChallenge({
    required String challengeId,
    required String playerId,
  });

  /// Takes [playerId] out of the challenge on the owner's say-so.
  ///
  /// Throws `StateError` when [ownerId] does not own the challenge or when
  /// [playerId] is the owner, and `NotFoundException` when the challenge does
  /// not exist.
  Future<Challenge> removeMember({
    required String challengeId,
    required String ownerId,
    required String playerId,
  });

  /// Gives the challenge a new join code, so an old one stops working.
  ///
  /// Throws `NotFoundException` when the challenge does not exist.
  Future<Challenge> regenerateJoinCode(String challengeId);

  /// Emits every challenge, then again after every change.
  Stream<List<Challenge>> watchAll();

  /// Emits the challenges [playerId] is a member of, then again after every
  /// change - so a join or a leave reaches the screens.
  Stream<List<Challenge>> watchForPlayer(String playerId);
}
