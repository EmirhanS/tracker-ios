import '../models/scoring_rule.dart';

/// One rule in a template, without an id.
///
/// Ids are handed out when the template is copied into a season, so two seasons
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

/// A ready-made set of scoring rules a captain can start a season from.
class SeasonTemplate {
  const SeasonTemplate({
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
  /// The template itself is never handed out, so editing a season's rules can
  /// not change the template. [nextId] must be unique across *every* season,
  /// not just this one, so pass `SeasonRepository.nextRuleId` rather than a
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
/// v1 ships General Fitness only. More templates drop into [all] later.
abstract final class SeasonTemplates {
  /// General Fitness.
  ///
  /// One point is roughly 30 minutes of moderate effort. Harder or longer
  /// efforts scale up, and nothing gives more than 6 points, so one activity
  /// cannot dominate a season.
  static const SeasonTemplate generalFitness = SeasonTemplate(
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

  /// Every template the captain can pick from.
  static const List<SeasonTemplate> all = [generalFitness];

  /// Looks a template up by its [key], or returns null.
  static SeasonTemplate? byKey(String key) {
    for (final template in all) {
      if (template.key == key) return template;
    }
    return null;
  }
}
