import '../../domain/codes/join_code.dart';
import '../../domain/exceptions.dart';
import '../../domain/models/challenge.dart';
import '../../domain/models/scoring_rule.dart';
import '../../domain/validation/challenge_validator.dart';
import '../repositories/challenge_repository.dart';
import 'id_generator.dart';
import 'in_memory_store.dart';

/// Challenges held in memory.
///
/// This class owns the three invariants nothing above it may break: join codes
/// are unique, the owner is always a member, and the dates of a running
/// challenge never move.
class InMemoryChallengeRepository implements ChallengeRepository {
  InMemoryChallengeRepository({
    Iterable<Challenge> challenges = const [],
    IdGenerator? idGenerator,
    JoinCodeGenerator? joinCodeGenerator,
  })  : _store = InMemoryStore<Challenge>(challenges),
        _ids = idGenerator ?? IdGenerator(start: challenges.length),
        _ruleIds = IdGenerator(start: _highestRuleNumber(challenges)),
        _joinCodes = joinCodeGenerator ?? RandomJoinCodeGenerator();

  final InMemoryStore<Challenge> _store;
  final IdGenerator _ids;
  final JoinCodeGenerator _joinCodes;

  /// Rule ids are counted separately from challenge ids so both stay readable.
  ///
  /// Seeded challenges already hold `rule_1..rule_N`, so the counter starts past
  /// the highest one rather than handing the same ids out a second time.
  final IdGenerator _ruleIds;

  /// How many codes to try before giving up.
  ///
  /// There are 32^6 codes, so a collision is already rare and two in a row is
  /// rarer still. The cap is here to stop a generator that is broken or out of
  /// codes from spinning for ever.
  static const int _codeAttempts = 100;

  static final RegExp _ruleIdPattern = RegExp(r'^rule_(\d+)$');

  static int _highestRuleNumber(Iterable<Challenge> challenges) {
    var highest = 0;
    for (final challenge in challenges) {
      for (final rule in challenge.rules) {
        final match = _ruleIdPattern.firstMatch(rule.id);
        final number = match == null ? null : int.tryParse(match.group(1)!);
        if (number != null && number > highest) highest = number;
      }
    }
    return highest;
  }

  @override
  String nextRuleId() => _ruleIds.next('rule');

  @override
  Future<List<Challenge>> getAll() async => _store.items;

  @override
  Future<Challenge?> getById(String id) async =>
      _store.firstWhereOrNull((challenge) => challenge.id == id);

  @override
  Future<Challenge?> getByJoinCode(String code) async {
    final wanted = JoinCode.normalize(code);
    return _store.firstWhereOrNull((challenge) => challenge.joinCode == wanted);
  }

  @override
  Future<Challenge> createDraft({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required String ownerId,
    List<ScoringRule> rules = const [],
  }) async {
    final challenge = Challenge(
      id: _ids.next('challenge'),
      name: name.trim(),
      startDate: startDate,
      endDate: endDate,
      ownerId: ownerId,
      joinCode: _freshJoinCode(),
      memberIds: List<String>.unmodifiable([ownerId]),
      status: ChallengeStatus.draft,
      rules: List<ScoringRule>.of(rules),
    );
    _store.add(challenge);
    return challenge;
  }

  @override
  Future<Challenge> updateChallenge(Challenge challenge) async {
    final index = _store.indexWhere((stored) => stored.id == challenge.id);
    if (index < 0) {
      throw NotFoundException('Challenge', challenge.id);
    }

    final stored = _store.items[index];
    if (stored.isActive &&
        (challenge.startDate != stored.startDate ||
            challenge.endDate != stored.endDate)) {
      throw ChallengeLockedException(challenge.id);
    }

    // The status belongs to startChallenge, the owner, the code and the members
    // to the methods below. An edit carries a whole Challenge, so it would
    // otherwise be able to write all four by accident.
    final updated = challenge.copyWith(
      status: stored.status,
      ownerId: stored.ownerId,
      joinCode: stored.joinCode,
      memberIds: stored.memberIds,
    );
    _store.replaceAt(index, updated);
    return updated;
  }

  @override
  Future<Challenge> startChallenge(String challengeId) async {
    final index = _store.indexWhere((challenge) => challenge.id == challengeId);
    if (index < 0) {
      throw NotFoundException('Challenge', challengeId);
    }

    final challenge = _store.items[index];
    if (challenge.isActive) {
      return challenge;
    }

    final problems = ChallengeValidator.validateForStart(challenge);
    if (problems.isNotEmpty) {
      throw StateError('Challenge $challengeId cannot start: $problems');
    }

    final started = challenge.copyWith(status: ChallengeStatus.active);
    _store.replaceAt(index, started);
    return started;
  }

  @override
  Future<Challenge> joinByCode({
    required String code,
    required String playerId,
  }) async {
    final wanted = JoinCode.normalize(code);
    final index =
        _store.indexWhere((challenge) => challenge.joinCode == wanted);
    if (index < 0) {
      throw NotFoundException('Challenge with join code', wanted);
    }

    final challenge = _store.items[index];
    // Joining twice is what somebody does when they are not sure the first tap
    // worked, so it hands the challenge back rather than an error.
    if (challenge.isMember(playerId)) return challenge;

    return _replaceMembers(index, [...challenge.memberIds, playerId]);
  }

  @override
  Future<Challenge> leaveChallenge({
    required String challengeId,
    required String playerId,
  }) async {
    final index = _store.indexWhere((challenge) => challenge.id == challengeId);
    if (index < 0) {
      throw NotFoundException('Challenge', challengeId);
    }

    final challenge = _store.items[index];
    if (playerId == challenge.ownerId) {
      throw StateError(
        'Player $playerId owns challenge $challengeId and cannot leave it.',
      );
    }
    if (!challenge.isMember(playerId)) return challenge;

    return _replaceMembers(
      index,
      challenge.memberIds.where((id) => id != playerId),
    );
  }

  @override
  Future<Challenge> removeMember({
    required String challengeId,
    required String ownerId,
    required String playerId,
  }) async {
    final index = _store.indexWhere((challenge) => challenge.id == challengeId);
    if (index < 0) {
      throw NotFoundException('Challenge', challengeId);
    }

    final challenge = _store.items[index];
    if (ownerId != challenge.ownerId) {
      throw StateError(
        'Player $ownerId does not own challenge $challengeId and cannot '
        'remove members from it.',
      );
    }
    if (playerId == challenge.ownerId) {
      throw StateError(
        'The owner cannot be removed from challenge $challengeId.',
      );
    }
    if (!challenge.isMember(playerId)) return challenge;

    return _replaceMembers(
      index,
      challenge.memberIds.where((id) => id != playerId),
    );
  }

  @override
  Future<Challenge> regenerateJoinCode(String challengeId) async {
    final index = _store.indexWhere((challenge) => challenge.id == challengeId);
    if (index < 0) {
      throw NotFoundException('Challenge', challengeId);
    }

    // The challenge still holds its old code while this runs, so the collision
    // check in _freshJoinCode also guarantees the new code is a different one.
    final updated =
        _store.items[index].copyWith(joinCode: _freshJoinCode());
    _store.replaceAt(index, updated);
    return updated;
  }

  @override
  Stream<List<Challenge>> watchAll() => _store.watch();

  @override
  Stream<List<Challenge>> watchForPlayer(String playerId) =>
      _store.watch().map(
            (challenges) => challenges
                .where((challenge) => challenge.isMember(playerId))
                .toList(growable: false),
          );

  void dispose() => _store.dispose();

  /// A code no challenge holds yet.
  String _freshJoinCode() {
    for (var attempt = 0; attempt < _codeAttempts; attempt++) {
      final code = _joinCodes.next();
      if (!JoinCode.isValid(code)) {
        throw StateError(
          'The join code generator gave "$code", which is not a join code.',
        );
      }
      final taken =
          _store.firstWhereOrNull((challenge) => challenge.joinCode == code);
      if (taken == null) return code;
    }
    throw StateError(
      'No unused join code came up in $_codeAttempts tries.',
    );
  }

  /// Writes a new member list, keeping it unmodifiable so nothing outside the
  /// repository can add a member by holding on to the list.
  Challenge _replaceMembers(int index, Iterable<String> memberIds) {
    final updated = _store.items[index].copyWith(
      memberIds: List<String>.unmodifiable(memberIds),
    );
    _store.replaceAt(index, updated);
    return updated;
  }
}
