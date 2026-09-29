import 'scoring_rule.dart';

/// Where a challenge is in its life.
enum ChallengeStatus {
  /// Being set up. It has no members but its owner and nobody can log yet.
  draft,

  /// Running. Members log activities against its rules.
  active,
}

/// A scoring period with its own rules, its own members and an invite code.
///
/// Several challenges run at the same time, and a player can be in more than
/// one. [memberIds] always holds [ownerId]: the repository is what keeps that
/// true, because the owner can neither leave nor be removed.
class Challenge {
  const Challenge({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.ownerId,
    required this.joinCode,
    required this.memberIds,
    required this.status,
    required this.rules,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  /// The player who created the challenge and may change its rules.
  final String ownerId;

  /// The code a player types to join. Unique across challenges.
  final String joinCode;

  /// The players in the challenge, the owner first.
  final List<String> memberIds;

  final ChallengeStatus status;
  final List<ScoringRule> rules;

  bool get isActive => status == ChallengeStatus.active;

  bool get isDraft => status == ChallengeStatus.draft;

  /// True when [playerId] is in the challenge.
  bool isMember(String playerId) => memberIds.contains(playerId);

  /// The rules a player can log against.
  List<ScoringRule> get enabledRules =>
      rules.where((rule) => rule.isEnabled).toList(growable: false);

  /// True when [date] falls inside the challenge, both ends included.
  bool containsDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  ScoringRule? ruleById(String ruleId) {
    for (final rule in rules) {
      if (rule.id == ruleId) return rule;
    }
    return null;
  }

  Challenge copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    String? ownerId,
    String? joinCode,
    List<String>? memberIds,
    ChallengeStatus? status,
    List<ScoringRule>? rules,
  }) {
    return Challenge(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      ownerId: ownerId ?? this.ownerId,
      joinCode: joinCode ?? this.joinCode,
      memberIds: memberIds ?? this.memberIds,
      status: status ?? this.status,
      rules: rules ?? this.rules,
    );
  }

  /// Value equality, matching every other model.
  ///
  /// `watchForPlayer` re-maps the challenge list on every challenge write, so
  /// without this Riverpod compares by identity, cannot dedupe, and rebuilds
  /// every dependent screen on any challenge change. [memberIds] is part of it
  /// for the other direction: a join has to reach the screens.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Challenge) return false;
    if (other.id != id ||
        other.name != name ||
        other.startDate != startDate ||
        other.endDate != endDate ||
        other.ownerId != ownerId ||
        other.joinCode != joinCode ||
        other.status != status ||
        other.memberIds.length != memberIds.length ||
        other.rules.length != rules.length) {
      return false;
    }
    for (var i = 0; i < memberIds.length; i++) {
      if (other.memberIds[i] != memberIds[i]) return false;
    }
    for (var i = 0; i < rules.length; i++) {
      if (other.rules[i] != rules[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        startDate,
        endDate,
        ownerId,
        joinCode,
        status,
        Object.hashAll(memberIds),
        Object.hashAll(rules),
      );

  @override
  String toString() => 'Challenge(id: $id, name: $name, status: $status, '
      'members: ${memberIds.length}, rules: ${rules.length})';
}
