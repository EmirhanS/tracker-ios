import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/domain/models/scoring_rule.dart';
import 'package:sporttracker/domain/models/challenge.dart';
import 'package:sporttracker/domain/validation/rule_validator.dart';
import 'package:sporttracker/domain/validation/challenge_validator.dart';

Challenge challengeWith(List<ScoringRule> rules) {
  return Challenge(
    id: 'challenge_1',
    name: 'Autumn 2026',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 11, 30),
    ownerId: 'player_1',
    joinCode: 'ABCDEF',
    memberIds: const ['player_1'],
    status: ChallengeStatus.draft,
    rules: rules,
  );
}

void main() {
  group('ChallengeValidator.validateDetails', () {
    test('a good challenge passes', () {
      final errors = ChallengeValidator.validateDetails(
        name: 'Autumn 2026',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(errors, isEmpty);
    });

    test('an empty name is rejected', () {
      final errors = ChallengeValidator.validateDetails(
        name: '  ',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(errors, contains(ChallengeDetailsError.nameRequired));
    });

    test('an end date before the start is rejected', () {
      final errors = ChallengeValidator.validateDetails(
        name: 'Autumn 2026',
        startDate: DateTime(2026, 11, 30),
        endDate: DateTime(2026, 9, 1),
      );

      expect(errors, contains(ChallengeDetailsError.endNotAfterStart));
    });

    test('an end date equal to the start is rejected', () {
      final errors = ChallengeValidator.validateDetails(
        name: 'Autumn 2026',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 1),
      );

      expect(errors, contains(ChallengeDetailsError.endNotAfterStart));
    });
  });

  group('ChallengeValidator.validateForStart', () {
    test('a challenge with one good enabled rule can start', () {
      final challenge = challengeWith([
        const ScoringRule(
          id: 'rule_1',
          name: 'Gym session',
          scoring: FixedScoring(points: 3, minDurationMinutes: 45),
        ),
      ]);

      expect(ChallengeValidator.validateForStart(challenge), isEmpty);
      expect(ChallengeValidator.canStart(challenge), isTrue);
    });

    test('a challenge with no rules cannot start', () {
      final challenge = challengeWith([]);

      expect(
        ChallengeValidator.validateForStart(challenge),
        [const NoEnabledRules()],
      );
      expect(ChallengeValidator.canStart(challenge), isFalse);
    });

    test('a challenge where every rule is off cannot start', () {
      final challenge = challengeWith([
        const ScoringRule(
          id: 'rule_1',
          name: 'Gym session',
          isEnabled: false,
          scoring: FixedScoring(points: 3),
        ),
      ]);

      expect(
        ChallengeValidator.validateForStart(challenge),
        [const NoEnabledRules()],
      );
    });

    test('a broken enabled rule stops the challenge', () {
      final challenge = challengeWith([
        const ScoringRule(
          id: 'rule_1',
          name: '',
          scoring: FixedScoring(points: 3),
        ),
      ]);

      final errors = ChallengeValidator.validateForStart(challenge);

      expect(errors, hasLength(1));
      final first = errors.first as InvalidRule;
      expect(first.ruleId, 'rule_1');
      expect(first.errors, contains(RuleValidationError.nameRequired));
    });

    test('a broken rule that is off does not stop the challenge', () {
      final challenge = challengeWith([
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

      expect(ChallengeValidator.validateForStart(challenge), isEmpty);
    });

    test('two enabled rules with the same name stop the challenge', () {
      final challenge = challengeWith([
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

      final errors = ChallengeValidator.validateForStart(challenge);

      expect(errors, hasLength(2));
      for (final error in errors) {
        expect(
          (error as InvalidRule).errors,
          contains(RuleValidationError.nameNotUnique),
        );
      }
    });

    test('every broken rule is reported, not only the first', () {
      final challenge = challengeWith([
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

      expect(ChallengeValidator.validateForStart(challenge), hasLength(2));
    });
  });

  group('Challenge helpers', () {
    test('a draft challenge is a draft and not active', () {
      final challenge = challengeWith([]);

      expect(challenge.isDraft, isTrue);
      expect(challenge.isActive, isFalse);
    });

    test('a started challenge is active and not a draft', () {
      final challenge =
          challengeWith([]).copyWith(status: ChallengeStatus.active);

      expect(challenge.isActive, isTrue);
      expect(challenge.isDraft, isFalse);
    });

    test('isMember answers for the owner and a stranger', () {
      final challenge = challengeWith([]);

      expect(challenge.isMember('player_1'), isTrue);
      expect(challenge.isMember('player_2'), isFalse);
    });

    test('containsDate includes both ends', () {
      final challenge = challengeWith([]);

      expect(challenge.containsDate(DateTime(2026, 9, 1)), isTrue);
      expect(challenge.containsDate(DateTime(2026, 11, 30, 23, 59)), isTrue);
      expect(challenge.containsDate(DateTime(2026, 8, 31)), isFalse);
      expect(challenge.containsDate(DateTime(2026, 12, 1)), isFalse);
    });

    test('enabledRules leaves out rules that are off', () {
      final challenge = challengeWith([
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

      expect(challenge.enabledRules.map((rule) => rule.id), ['rule_1']);
    });

    test('ruleById finds a rule or returns null', () {
      final challenge = challengeWith([
        const ScoringRule(
          id: 'rule_1',
          name: 'On',
          scoring: FixedScoring(points: 1),
        ),
      ]);

      expect(challenge.ruleById('rule_1')?.name, 'On');
      expect(challenge.ruleById('missing'), isNull);
    });
  });

  group('ChallengeValidator.validateForStart, name clashes with rules that are off',
      () {
    // The rules screen encourages switching a rule off rather than deleting it,
    // so uniqueness is checked against the enabled rules only. Otherwise a
    // switched-off rule blocks the challenge with a message naming a rule the
    // owner cannot see in the list.

    test('a rule that is off does not block an enabled rule with its name', () {
      final challenge = challengeWith([
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

      expect(ChallengeValidator.validateForStart(challenge), isEmpty);
      expect(ChallengeValidator.canStart(challenge), isTrue);
    });

    test('the clash is case insensitive between rules that are off', () {
      final challenge = challengeWith([
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

      expect(ChallengeValidator.validateForStart(challenge), isEmpty);
    });

    test('two enabled rules sharing a name still block the challenge', () {
      final challenge = challengeWith([
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

      expect(ChallengeValidator.validateForStart(challenge), isNotEmpty);
      expect(ChallengeValidator.canStart(challenge), isFalse);
    });
  });

  group('Challenge value equality', () {
    // watchForPlayer re-maps the challenge list on every challenge write, so
    // without == Riverpod cannot dedupe and rebuilds every dependent screen.
    // memberIds and joinCode are in it for the other direction: a join has to
    // come out as a change, or the screens never hear about the new member.

    const rule = ScoringRule(
      id: 'rule_1',
      name: 'Running',
      scoring: FixedScoring(points: 1),
    );

    test('two challenges with the same fields are equal', () {
      expect(challengeWith([rule]), challengeWith([rule]));
      expect(challengeWith([rule]).hashCode, challengeWith([rule]).hashCode);
    });

    test('equal rule lists that are not the same object still match', () {
      final first = challengeWith([rule]);
      final second = challengeWith([
        const ScoringRule(
          id: 'rule_1',
          name: 'Running',
          scoring: FixedScoring(points: 1),
        ),
      ]);

      expect(identical(first.rules, second.rules), isFalse);
      expect(first, second);
    });

    test('a changed rule makes the challenges unequal', () {
      final changed = challengeWith([rule.copyWith(isEnabled: false)]);

      expect(challengeWith([rule]), isNot(changed));
    });

    test('a changed status makes the challenges unequal', () {
      final active = challengeWith([rule]).copyWith(status: ChallengeStatus.active);

      expect(challengeWith([rule]), isNot(active));
    });

    test('a different rule count makes the challenges unequal', () {
      expect(challengeWith([rule]), isNot(challengeWith([])));
    });

    test('a new member makes the challenges unequal', () {
      final joined = challengeWith([rule]).copyWith(
        memberIds: const ['player_1', 'player_2'],
      );

      expect(challengeWith([rule]), isNot(joined));
    });

    test('a new join code makes the challenges unequal', () {
      final recoded = challengeWith([rule]).copyWith(joinCode: 'ZZZZZZ');

      expect(challengeWith([rule]), isNot(recoded));
    });
  });
}
