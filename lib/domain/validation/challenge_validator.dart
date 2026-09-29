import '../models/challenge.dart';
import 'rule_validator.dart';

/// What can be wrong with the name and dates of a challenge.
enum ChallengeDetailsError {
  /// The name is empty or only spaces.
  nameRequired,

  /// The end date is on or before the start date.
  endNotAfterStart,
}

/// What can stop a challenge from starting.
sealed class ChallengeStartError {
  const ChallengeStartError();
}

/// Every rule in the challenge is switched off.
final class NoEnabledRules extends ChallengeStartError {
  const NoEnabledRules();

  @override
  bool operator ==(Object other) => other is NoEnabledRules;

  @override
  int get hashCode => (NoEnabledRules).hashCode;

  @override
  String toString() => 'NoEnabledRules()';
}

/// One enabled rule does not pass [RuleValidator].
final class InvalidRule extends ChallengeStartError {
  const InvalidRule({
    required this.ruleId,
    required this.ruleName,
    required this.errors,
  });

  final String ruleId;
  final String ruleName;
  final List<RuleValidationError> errors;

  @override
  String toString() => 'InvalidRule($ruleName: $errors)';
}

/// Checks a challenge before it is saved and before it starts.
abstract final class ChallengeValidator {
  /// Checks the name and the dates of a challenge.
  static List<ChallengeDetailsError> validateDetails({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final errors = <ChallengeDetailsError>[];

    if (name.trim().isEmpty) {
      errors.add(ChallengeDetailsError.nameRequired);
    }
    if (!endDate.isAfter(startDate)) {
      errors.add(ChallengeDetailsError.endNotAfterStart);
    }

    return errors;
  }

  /// Checks that [challenge] can start: at least one rule is on, and every rule
  /// that is on is valid.
  static List<ChallengeStartError> validateForStart(Challenge challenge) {
    final errors = <ChallengeStartError>[];

    final enabled = challenge.enabledRules;
    if (enabled.isEmpty) {
      errors.add(const NoEnabledRules());
      return errors;
    }

    for (final rule in enabled) {
      // Name uniqueness is checked against the other *enabled* rules only. The
      // rules screen encourages switching a rule off rather than deleting it,
      // so passing `challenge.rules` let a switched-off "Running" block an enabled
      // "Running" from starting the challenge, with a message naming a rule the
      // owner cannot see in the list.
      final ruleErrors = RuleValidator.validate(rule, otherRules: enabled);
      if (ruleErrors.isNotEmpty) {
        errors.add(
          InvalidRule(
            ruleId: rule.id,
            ruleName: rule.name,
            errors: ruleErrors,
          ),
        );
      }
    }

    return errors;
  }

  /// True when [challenge] can start.
  static bool canStart(Challenge challenge) => validateForStart(challenge).isEmpty;
}
