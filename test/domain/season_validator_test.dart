import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/domain/models/scoring_rule.dart';
import 'package:sporttracker/domain/models/season.dart';
import 'package:sporttracker/domain/validation/rule_validator.dart';
import 'package:sporttracker/domain/validation/season_validator.dart';

Season seasonWith(List<ScoringRule> rules) {
  return Season(
    id: 'season_1',
    name: 'Autumn 2026',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 11, 30),
    captainId: 'player_1',
    status: SeasonStatus.draft,
    rules: rules,
  );
}

void main() {
  group('SeasonValidator.validateDetails', () {
    test('a good season passes', () {
      final errors = SeasonValidator.validateDetails(
        name: 'Autumn 2026',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(errors, isEmpty);
    });

    test('an empty name is rejected', () {
      final errors = SeasonValidator.validateDetails(
        name: '  ',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(errors, contains(SeasonDetailsError.nameRequired));
    });

    test('an end date before the start is rejected', () {
      final errors = SeasonValidator.validateDetails(
        name: 'Autumn 2026',
        startDate: DateTime(2026, 11, 30),
        endDate: DateTime(2026, 9, 1),
      );

      expect(errors, contains(SeasonDetailsError.endNotAfterStart));
    });

    test('an end date equal to the start is rejected', () {
      final errors = SeasonValidator.validateDetails(
        name: 'Autumn 2026',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 1),
      );

      expect(errors, contains(SeasonDetailsError.endNotAfterStart));
    });
  });

  group('SeasonValidator.validateForStart', () {
    test('a season with one good enabled rule can start', () {
      final season = seasonWith([
        const ScoringRule(
          id: 'rule_1',
          name: 'Gym session',
          scoring: FixedScoring(points: 3, minDurationMinutes: 45),
        ),
      ]);

      expect(SeasonValidator.validateForStart(season), isEmpty);
      expect(SeasonValidator.canStart(season), isTrue);
    });

    test('a season with no rules cannot start', () {
      final season = seasonWith([]);

      expect(
        SeasonValidator.validateForStart(season),
        [const NoEnabledRules()],
      );
      expect(SeasonValidator.canStart(season), isFalse);
    });

    test('a season where every rule is off cannot start', () {
      final season = seasonWith([
        const ScoringRule(
          id: 'rule_1',
          name: 'Gym session',
          isEnabled: false,
          scoring: FixedScoring(points: 3),
        ),
      ]);

      expect(
        SeasonValidator.validateForStart(season),
        [const NoEnabledRules()],
      );
    });

    test('a broken enabled rule stops the season', () {
      final season = seasonWith([
        const ScoringRule(
          id: 'rule_1',
          name: '',
          scoring: FixedScoring(points: 3),
        ),
      ]);

      final errors = SeasonValidator.validateForStart(season);

      expect(errors, hasLength(1));
      final first = errors.first as InvalidRule;
      expect(first.ruleId, 'rule_1');
      expect(first.errors, contains(RuleValidationError.nameRequired));
    });

    test('a broken rule that is off does not stop the season', () {
      final season = seasonWith([
        const ScoringRule(
          id: 'rule_1',
          name: 'Gym session',
          scoring: FixedScoring(points: 3),
        ),
        const ScoringRule(
          id: 'rule_2',
          name: '',
          isEnabled: false,
          scoring: FixedScoring(points: 500),
        ),
      ]);

      expect(SeasonValidator.validateForStart(season), isEmpty);
    });

    test('two enabled rules with the same name stop the season', () {
      final season = seasonWith([
        const ScoringRule(
          id: 'rule_1',
          name: 'Running',
          scoring: FixedScoring(points: 3),
        ),
        const ScoringRule(
          id: 'rule_2',
          name: 'running',
          scoring: FixedScoring(points: 2),
        ),
      ]);

      final errors = SeasonValidator.validateForStart(season);

      expect(errors, hasLength(2));
      for (final error in errors) {
        expect(
          (error as InvalidRule).errors,
          contains(RuleValidationError.nameNotUnique),
        );
      }
    });

    test('every broken rule is reported, not only the first', () {
      final season = seasonWith([
        const ScoringRule(
          id: 'rule_1',
          name: '',
          scoring: FixedScoring(points: 3),
        ),
        const ScoringRule(
          id: 'rule_2',
          name: 'Cycling',
          scoring: TimeBasedScoring(
            pointsPerBlock: 1,
            minutesPerBlock: 30,
            minDurationMinutes: 10,
          ),
        ),
      ]);

      expect(SeasonValidator.validateForStart(season), hasLength(2));
    });
  });

  group('Season helpers', () {
    test('a draft season is not active and not locked', () {
      final season = seasonWith([]);

      expect(season.isDraft, isTrue);
      expect(season.isActive, isFalse);
      expect(season.isLocked, isFalse);
    });

    test('an active season is locked', () {
      final season = seasonWith([]).copyWith(status: SeasonStatus.active);

      expect(season.isActive, isTrue);
      expect(season.isLocked, isTrue);
    });

    test('containsDate includes both ends', () {
      final season = seasonWith([]);

      expect(season.containsDate(DateTime(2026, 9, 1)), isTrue);
      expect(season.containsDate(DateTime(2026, 11, 30, 23, 59)), isTrue);
      expect(season.containsDate(DateTime(2026, 8, 31)), isFalse);
      expect(season.containsDate(DateTime(2026, 12, 1)), isFalse);
    });

    test('enabledRules leaves out rules that are off', () {
      final season = seasonWith([
        const ScoringRule(
          id: 'rule_1',
          name: 'On',
          scoring: FixedScoring(points: 1),
        ),
        const ScoringRule(
          id: 'rule_2',
          name: 'Off',
          isEnabled: false,
          scoring: FixedScoring(points: 1),
        ),
      ]);

      expect(season.enabledRules.map((rule) => rule.id), ['rule_1']);
    });

    test('ruleById finds a rule or returns null', () {
      final season = seasonWith([
        const ScoringRule(
          id: 'rule_1',
          name: 'On',
          scoring: FixedScoring(points: 1),
        ),
      ]);

      expect(season.ruleById('rule_1')?.name, 'On');
      expect(season.ruleById('missing'), isNull);
    });
  });

  group('SeasonValidator.validateForStart, name clashes with rules that are off',
      () {
    // The rules screen encourages switching a rule off rather than deleting it,
    // so uniqueness is checked against the enabled rules only. Otherwise a
    // switched-off rule blocks the season with a message naming a rule the
    // captain cannot see in the list.

    test('a rule that is off does not block an enabled rule with its name', () {
      final season = seasonWith([
        const ScoringRule(
          id: 'rule_1',
          name: 'Running',
          isEnabled: false,
          scoring: FixedScoring(points: 1),
        ),
        const ScoringRule(
          id: 'rule_2',
          name: 'Running',
          scoring: FixedScoring(points: 2),
        ),
      ]);

      expect(SeasonValidator.validateForStart(season), isEmpty);
      expect(SeasonValidator.canStart(season), isTrue);
    });

    test('the clash is case insensitive between rules that are off', () {
      final season = seasonWith([
        const ScoringRule(
          id: 'rule_1',
          name: '  RUNNING ',
          isEnabled: false,
          scoring: FixedScoring(points: 1),
        ),
        const ScoringRule(
          id: 'rule_2',
          name: 'Running',
          scoring: FixedScoring(points: 2),
        ),
      ]);

      expect(SeasonValidator.validateForStart(season), isEmpty);
    });

    test('two enabled rules sharing a name still block the season', () {
      final season = seasonWith([
        const ScoringRule(
          id: 'rule_1',
          name: 'Running',
          scoring: FixedScoring(points: 1),
        ),
        const ScoringRule(
          id: 'rule_2',
          name: 'Running',
          scoring: FixedScoring(points: 2),
        ),
      ]);

      expect(SeasonValidator.validateForStart(season), isNotEmpty);
      expect(SeasonValidator.canStart(season), isFalse);
    });
  });

  group('Season value equality', () {
    // activeSeasonProvider re-maps the season list on every season write, so
    // without == Riverpod cannot dedupe and rebuilds every dependent screen.

    const rule = ScoringRule(
      id: 'rule_1',
      name: 'Running',
      scoring: FixedScoring(points: 1),
    );

    test('two seasons with the same fields are equal', () {
      expect(seasonWith([rule]), seasonWith([rule]));
      expect(seasonWith([rule]).hashCode, seasonWith([rule]).hashCode);
    });

    test('equal rule lists that are not the same object still match', () {
      final first = seasonWith([rule]);
      final second = seasonWith([
        const ScoringRule(
          id: 'rule_1',
          name: 'Running',
          scoring: FixedScoring(points: 1),
        ),
      ]);

      expect(identical(first.rules, second.rules), isFalse);
      expect(first, second);
    });

    test('a changed rule makes the seasons unequal', () {
      final changed = seasonWith([rule.copyWith(isEnabled: false)]);

      expect(seasonWith([rule]), isNot(changed));
    });

    test('a changed status makes the seasons unequal', () {
      final active = seasonWith([rule]).copyWith(status: SeasonStatus.active);

      expect(seasonWith([rule]), isNot(active));
    });

    test('a different rule count makes the seasons unequal', () {
      expect(seasonWith([rule]), isNot(seasonWith([])));
    });
  });
}
