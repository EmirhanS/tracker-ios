import '../models/scoring_rule.dart';

/// One rule in a template, without an id.
///
/// Ids are handed out when the template is copied into a challenge, so two challenges
/// built from the same template never share rule ids.
class RuleBlueprint {
  const RuleBlueprint({
    required this.name,
    required this.scoring,
    this.emoji,
  });

  final String name;
  final String? emoji;
  final Scoring scoring;
}

/// A ready-made set of scoring rules an owner can start a challenge from.
class ChallengeTemplate {
  const ChallengeTemplate({
    required this.key,
    required this.name,
    required this.description,
    required this.blueprints,
  });

  final String key;
  final String name;
  final String description;
  final List<RuleBlueprint> blueprints;

  /// Copies the template rules, giving each one a fresh id from [nextId].
  ///
  /// The template itself is never handed out, so editing a challenge's rules can
  /// not change the template. [nextId] must be unique across *every* challenge,
  /// not just this one, so pass `ChallengeRepository.nextRuleId` rather than a
  /// generator scoped to a single call - see the contract on [RuleBlueprint].
  List<ScoringRule> buildRules(String Function() nextId) {
    return blueprints
        .map(
          (blueprint) => ScoringRule(
            id: nextId(),
            name: blueprint.name,
            emoji: blueprint.emoji,
            scoring: _copyScoring(blueprint.scoring),
          ),
        )
        .toList(growable: false);
  }

  /// Detaches a built rule's scoring from the template's.
  ///
  /// Only [DistanceTierScoring] holds a collection; the other variants are
  /// value types with nothing to share. The template's `tiers` list is `const`,
  /// so without this a rule editor mutating it in place throws
  /// `UnsupportedError` instead of editing.
  static Scoring _copyScoring(Scoring scoring) => switch (scoring) {
        DistanceTierScoring(:final tiers) =>
          DistanceTierScoring(tiers: List<DistanceTier>.of(tiers)),
        FixedScoring() || TimeBasedScoring() => scoring,
      };
}

/// The templates built into the app.
///
/// General Fitness is the balanced default; the sport schemas after it are
/// tuned for one discipline. Every template in [all] is picked straight off the
/// template screen, so each one must be startable as it stands - see the
/// validation test that runs `RuleValidator` over every blueprint.
abstract final class ChallengeTemplates {
  /// General Fitness.
  ///
  /// One point is roughly 30 minutes of moderate effort. Harder or longer
  /// efforts scale up, and nothing gives more than 6 points, so one activity
  /// cannot dominate a challenge.
  static const ChallengeTemplate generalFitness = ChallengeTemplate(
    key: 'general_fitness',
    name: 'General Fitness',
    description:
        'A balanced set for mixed training. One point is about 30 minutes of '
        'moderate effort, and no single activity gives more than 6 points.',
    blueprints: [
      RuleBlueprint(
        name: 'Gym session',
        emoji: '🏋️',
        scoring: FixedScoring(points: 3, minDurationMinutes: 45),
      ),
      RuleBlueprint(
        name: 'Running',
        emoji: '🏃',
        scoring: DistanceTierScoring(
          tiers: [
            DistanceTier(minKm: 3, points: 1),
            DistanceTier(minKm: 5, points: 2),
            DistanceTier(minKm: 10, points: 4),
            DistanceTier(minKm: 15, points: 6),
          ],
        ),
      ),
      RuleBlueprint(
        name: 'Cycling',
        emoji: '🚴',
        scoring: TimeBasedScoring(
          pointsPerBlock: 1,
          minutesPerBlock: 30,
          minDurationMinutes: 30,
        ),
      ),
      RuleBlueprint(
        name: 'Team sport',
        emoji: '⚽',
        scoring: FixedScoring(points: 4, minDurationMinutes: 60),
      ),
      RuleBlueprint(
        name: 'Yoga / mobility',
        emoji: '🧘',
        scoring: FixedScoring(points: 1, minDurationMinutes: 30),
      ),
    ],
  );

  /// Cyclist.
  ///
  /// Riding carries the schema, but the strength work a rider tends to skip is
  /// paid for: leg day is worth 4, double an ordinary upper body session.
  static const ChallengeTemplate cyclist = ChallengeTemplate(
    key: 'cyclist',
    name: 'Cyclist',
    description:
        'For riders. Long rides score by distance and the trainer scores by '
        'time. Leg day in the gym is worth more than any other strength '
        'session here, because it is the work a cyclist skips.',
    blueprints: [
      RuleBlueprint(
        name: 'Long ride',
        emoji: '🚴',
        scoring: DistanceTierScoring(
          tiers: [
            DistanceTier(minKm: 20, points: 1),
            DistanceTier(minKm: 40, points: 2),
            DistanceTier(minKm: 80, points: 4),
            DistanceTier(minKm: 120, points: 6),
          ],
        ),
      ),
      RuleBlueprint(
        name: 'Indoor trainer',
        emoji: '🚲',
        scoring: TimeBasedScoring(
          pointsPerBlock: 1,
          minutesPerBlock: 30,
          minDurationMinutes: 30,
        ),
      ),
      RuleBlueprint(
        name: 'Leg day (gym)',
        emoji: '🦵',
        scoring: FixedScoring(points: 4, minDurationMinutes: 45),
      ),
      RuleBlueprint(
        name: 'Core and upper body',
        emoji: '💪',
        scoring: FixedScoring(points: 2, minDurationMinutes: 45),
      ),
      RuleBlueprint(
        name: 'Mobility',
        emoji: '🧘',
        scoring: FixedScoring(points: 1, minDurationMinutes: 30),
      ),
    ],
  );

  /// Runner.
  ///
  /// The run ladder goes all the way to a marathon, so the half and full
  /// distances need fractional tiers - `DistanceTier.minKm` is a double.
  static const ChallengeTemplate runner = ChallengeTemplate(
    key: 'runner',
    name: 'Runner',
    description:
        'For runners. Runs score by distance, up the ladder from 5 km to a '
        'marathon, and the strength and mobility work that keeps you running '
        'scores alongside them.',
    blueprints: [
      RuleBlueprint(
        name: 'Run',
        emoji: '🏃',
        scoring: DistanceTierScoring(
          tiers: [
            DistanceTier(minKm: 5, points: 1),
            DistanceTier(minKm: 10, points: 2),
            DistanceTier(minKm: 15, points: 3),
            DistanceTier(minKm: 21.1, points: 5),
            DistanceTier(minKm: 42.2, points: 8),
          ],
        ),
      ),
      RuleBlueprint(
        name: 'Intervals or track',
        emoji: '⏱️',
        scoring: FixedScoring(points: 3, minDurationMinutes: 40),
      ),
      RuleBlueprint(
        name: 'Leg and core strength',
        emoji: '🦵',
        scoring: FixedScoring(points: 3, minDurationMinutes: 40),
      ),
      RuleBlueprint(
        name: 'Mobility',
        emoji: '🧘',
        scoring: FixedScoring(points: 1, minDurationMinutes: 30),
      ),
    ],
  );

  /// Strength.
  ///
  /// Leg day is worth 4 against 3 for push, pull and full body, for the same
  /// reason it is in [cyclist]: it is the session people talk themselves out of.
  static const ChallengeTemplate strength = ChallengeTemplate(
    key: 'strength',
    name: 'Strength',
    description:
        'For lifters. A split across leg, push, pull and full body days, with '
        'leg day worth more than the rest, plus a cardio finisher that scores '
        'by time.',
    blueprints: [
      RuleBlueprint(
        name: 'Leg day',
        emoji: '🦵',
        scoring: FixedScoring(points: 4, minDurationMinutes: 45),
      ),
      RuleBlueprint(
        name: 'Push day',
        emoji: '💪',
        scoring: FixedScoring(points: 3, minDurationMinutes: 45),
      ),
      RuleBlueprint(
        name: 'Pull day',
        emoji: '🏋️',
        scoring: FixedScoring(points: 3, minDurationMinutes: 45),
      ),
      RuleBlueprint(
        name: 'Full body',
        emoji: '🤸',
        scoring: FixedScoring(points: 3, minDurationMinutes: 45),
      ),
      RuleBlueprint(
        name: 'Cardio finisher',
        emoji: '🏃',
        scoring: TimeBasedScoring(
          pointsPerBlock: 1,
          minutesPerBlock: 20,
          minDurationMinutes: 20,
        ),
      ),
      RuleBlueprint(
        name: 'Mobility',
        emoji: '🧘',
        scoring: FixedScoring(points: 1, minDurationMinutes: 30),
      ),
    ],
  );

  /// Team sport.
  ///
  /// The match is the top scorer, because it is the thing the season is
  /// actually about; everything else supports it.
  static const ChallengeTemplate teamSport = ChallengeTemplate(
    key: 'team_sport',
    name: 'Team sport',
    description:
        'For clubs and squads. The match scores highest, team training is '
        'close behind, and the conditioning, gym and mobility work around them '
        'still counts.',
    blueprints: [
      RuleBlueprint(
        name: 'Match',
        emoji: '⚽',
        scoring: FixedScoring(points: 5, minDurationMinutes: 60),
      ),
      RuleBlueprint(
        name: 'Team training',
        emoji: '🥅',
        scoring: FixedScoring(points: 4, minDurationMinutes: 60),
      ),
      RuleBlueprint(
        name: 'Conditioning',
        emoji: '🏃',
        scoring: TimeBasedScoring(
          pointsPerBlock: 1,
          minutesPerBlock: 20,
          minDurationMinutes: 20,
        ),
      ),
      RuleBlueprint(
        name: 'Gym',
        emoji: '🏋️',
        scoring: FixedScoring(points: 3, minDurationMinutes: 45),
      ),
      RuleBlueprint(
        name: 'Mobility',
        emoji: '🧘',
        scoring: FixedScoring(points: 1, minDurationMinutes: 30),
      ),
    ],
  );

  /// Start from scratch.
  ///
  /// Deliberately empty. A challenge built from this one starts with no rules,
  /// so the owner adds every rule on the rules screen before it can be started.
  static const ChallengeTemplate blank = ChallengeTemplate(
    key: 'blank',
    name: 'Start from scratch',
    description:
        'No rules to begin with. Add your own on the next screen and score '
        'exactly what your group cares about.',
    blueprints: [],
  );

  /// Every template the owner can pick from.
  static const List<ChallengeTemplate> all = [
    generalFitness,
    cyclist,
    runner,
    strength,
    teamSport,
    blank,
  ];

  /// Looks a template up by its [key], or returns null.
  static ChallengeTemplate? byKey(String key) {
    for (final template in all) {
      if (template.key == key) return template;
    }
    return null;
  }
}
