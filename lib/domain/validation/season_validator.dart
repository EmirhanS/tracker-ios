import '../models/season.dart';
import 'rule_validator.dart';

/// What can be wrong with the name and dates of a season.
enum SeasonDetailsError {
  /// The name is empty or only spaces.
  nameRequired,

  /// The end date is on or before the start date.
  endNotAfterStart,
}

/// What can stop a season from starting.
sealed class SeasonStartError {
  const SeasonStartError();
}

/// Every rule in the season is switched off.
final class NoEnabledRules extends SeasonStartError {
  const NoEnabledRules();

  @override
  bool operator ==(Object other) => other is NoEnabledRules;

  @override
  int get hashCode => (NoEnabledRules).hashCode;

  @override
  String toString() => 'NoEnabledRules()';
}

/// One enabled rule does not pass [RuleValidator].
final class InvalidRule extends SeasonStartError {
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

/// Checks a season before it is saved and before it starts.
abstract final class SeasonValidator {
  /// Checks the name and the dates of a season.
  static List<SeasonDetailsError> validateDetails({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final errors = <SeasonDetailsError>[];

    if (name.trim().isEmpty) {
      errors.add(SeasonDetailsError.nameRequired);
    }
    if (!endDate.isAfter(startDate)) {
      errors.add(SeasonDetailsError.endNotAfterStart);
    }

    return errors;
  }

  /// Checks that [season] can start: at least one rule is on, and every rule
  /// that is on is valid.
  static List<SeasonStartError> validateForStart(Season season) {
    final errors = <SeasonStartError>[];

    final enabled = season.enabledRules;
    if (enabled.isEmpty) {
      errors.add(const NoEnabledRules());
      return errors;
    }

    for (final rule in enabled) {
      // Name uniqueness is checked against the other *enabled* rules only. The
      // rules screen encourages switching a rule off rather than deleting it,
      // so passing `season.rules` let a switched-off "Running" block an enabled
      // "Running" from starting the season, with a message naming a rule the
      // captain cannot see in the list.
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

  /// True when [season] can start.
  static bool canStart(Season season) => validateForStart(season).isEmpty;
}
