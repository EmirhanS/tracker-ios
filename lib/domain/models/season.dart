import 'scoring_rule.dart';

/// Where a season is in its life.
enum SeasonStatus {
  /// Being set up. Rules can still be changed.
  draft,

  /// Running. Players log activities and the rules are locked.
  active,
}

/// A scoring period with its own set of rules.
class Season {
  const Season({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.captainId,
    required this.status,
    required this.rules,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  /// The player who may set up and start the season.
  final String captainId;

  final SeasonStatus status;
  final List<ScoringRule> rules;

  bool get isActive => status == SeasonStatus.active;

  bool get isDraft => status == SeasonStatus.draft;

  /// Rules of an active season cannot be changed.
  bool get isLocked => isActive;

  /// The rules a player can log against.
  List<ScoringRule> get enabledRules =>
      rules.where((rule) => rule.isEnabled).toList(growable: false);

  /// True when [date] falls inside the season, both ends included.
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

  Season copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    String? captainId,
    SeasonStatus? status,
    List<ScoringRule>? rules,
  }) {
    return Season(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      captainId: captainId ?? this.captainId,
      status: status ?? this.status,
      rules: rules ?? this.rules,
    );
  }

  /// Value equality, matching every other model.
  ///
  /// `watchActiveSeason` re-maps the season list on every season write, so
  /// without this Riverpod compares by identity, cannot dedupe, and rebuilds
  /// every dependent screen on any season change.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Season) return false;
    if (other.id != id ||
        other.name != name ||
        other.startDate != startDate ||
        other.endDate != endDate ||
        other.captainId != captainId ||
        other.status != status ||
        other.rules.length != rules.length) {
      return false;
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
        captainId,
        status,
        Object.hashAll(rules),
      );

  @override
  String toString() => 'Season(id: $id, name: $name, status: $status, '
      'rules: ${rules.length})';
}
