import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/data/in_memory/id_generator.dart';
import 'package:sporttracker/data/in_memory/in_memory_season_repository.dart';
import 'package:sporttracker/domain/exceptions.dart';
import 'package:sporttracker/domain/models/scoring_rule.dart';
import 'package:sporttracker/domain/models/season.dart';
import 'package:sporttracker/domain/templates/season_templates.dart';

List<ScoringRule> generalFitnessRules() {
  final ids = IdGenerator();
  return SeasonTemplates.generalFitness.buildRules(ids.forPrefix('rule'));
}

void main() {
  late InMemorySeasonRepository repository;

  setUp(() {
    repository = InMemorySeasonRepository();
  });

  tearDown(() {
    repository.dispose();
  });

  Future<Season> createDraft({List<ScoringRule>? rules}) {
    return repository.createDraft(
      name: 'Autumn 2026',
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 11, 30),
      captainId: 'player_1',
      rules: rules ?? generalFitnessRules(),
    );
  }

  group('createDraft', () {
    test('creates a draft season with an id', () async {
      final season = await createDraft();

      expect(season.id, isNotEmpty);
      expect(season.status, SeasonStatus.draft);
      expect(season.rules, hasLength(5));
      expect(await repository.getAll(), hasLength(1));
    });

    test('trims the name', () async {
      final season = await repository.createDraft(
        name: '  Autumn 2026  ',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 11, 30),
        captainId: 'player_1',
      );

      expect(season.name, 'Autumn 2026');
    });

    test('two drafts get different ids', () async {
      final first = await createDraft();
      final second = await createDraft();

      expect(first.id, isNot(second.id));
    });

    test('there is no active season yet', () async {
      await createDraft();

      expect(await repository.getActiveSeason(), isNull);
    });
  });

  group('updateSeason', () {
    test('saves changes to a draft', () async {
      final season = await createDraft();

      final updated = await repository.updateSeason(
        season.copyWith(name: 'Winter 2026'),
      );

      expect(updated.name, 'Winter 2026');
      expect((await repository.getById(season.id))?.name, 'Winter 2026');
    });

    test('can switch a rule off', () async {
      final season = await createDraft();
      final rules = List<ScoringRule>.of(season.rules);
      rules[0] = rules[0].copyWith(isEnabled: false);

      final updated = await repository.updateSeason(
        season.copyWith(rules: rules),
      );

      expect(updated.enabledRules, hasLength(4));
    });

    test('throws SeasonLockedException for an active season', () async {
      final season = await createDraft();
      await repository.startSeason(season.id);

      expect(
        () => repository.updateSeason(season.copyWith(name: 'Changed')),
        throwsA(isA<SeasonLockedException>()),
      );
    });

    test('an active season keeps its rules after a rejected edit', () async {
      final season = await createDraft();
      await repository.startSeason(season.id);

      try {
        await repository.updateSeason(season.copyWith(rules: const []));
      } on SeasonLockedException {
        // expected
      }

      expect((await repository.getById(season.id))?.rules, hasLength(5));
    });

    test('throws NotFoundException for an unknown season', () async {
      final season = await createDraft();

      expect(
        () => repository.updateSeason(season.copyWith(id: 'missing')),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('an edit cannot set the status', () async {
      final season = await createDraft();

      final updated = await repository.updateSeason(
        season.copyWith(status: SeasonStatus.active),
      );

      expect(updated.status, SeasonStatus.draft);
    });
  });

  group('startSeason', () {
    test('sets a valid draft active', () async {
      final season = await createDraft();

      final started = await repository.startSeason(season.id);

      expect(started.status, SeasonStatus.active);
      expect(started.isLocked, isTrue);
      expect((await repository.getActiveSeason())?.id, season.id);
    });

    test('refuses a season with no enabled rules', () async {
      final season = await createDraft(rules: const []);

      expect(
        () => repository.startSeason(season.id),
        throwsA(isA<StateError>()),
      );
      expect(await repository.getActiveSeason(), isNull);
    });

    test('refuses a season with a broken enabled rule', () async {
      final season = await createDraft(
        rules: const [
          ScoringRule(
            id: 'rule_1',
            name: '',
            scoring: FixedScoring(points: 3),
          ),
        ],
      );

      expect(
        () => repository.startSeason(season.id),
        throwsA(isA<StateError>()),
      );
    });

    test('refuses a second season while one is running', () async {
      final first = await createDraft();
      await repository.startSeason(first.id);
      final second = await createDraft();

      expect(
        () => repository.startSeason(second.id),
        throwsA(isA<StateError>()),
      );
    });

    test('starting an already active season does nothing', () async {
      final season = await createDraft();
      await repository.startSeason(season.id);

      final again = await repository.startSeason(season.id);

      expect(again.status, SeasonStatus.active);
    });

    test('throws NotFoundException for an unknown season', () async {
      expect(
        () => repository.startSeason('missing'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('watch', () {
    test('watchAll gives the current list first, then every change', () async {
      final seen = <int>[];
      final subscription =
          repository.watchAll().listen((seasons) => seen.add(seasons.length));

      await Future<void>.delayed(Duration.zero);
      await createDraft();
      await Future<void>.delayed(Duration.zero);
      await createDraft();
      await Future<void>.delayed(Duration.zero);

      expect(seen, [0, 1, 2]);
      await subscription.cancel();
    });

    test('watchActiveSeason follows the start of a season', () async {
      final seen = <String?>[];
      final subscription = repository
          .watchActiveSeason()
          .listen((season) => seen.add(season?.name));

      await Future<void>.delayed(Duration.zero);
      final season = await createDraft();
      await Future<void>.delayed(Duration.zero);
      await repository.startSeason(season.id);
      await Future<void>.delayed(Duration.zero);

      expect(seen, [null, null, 'Autumn 2026']);
      await subscription.cancel();
    });

    test('the list handed out cannot change the store', () async {
      await createDraft();
      final seasons = await repository.getAll();

      expect(() => seasons.clear(), throwsUnsupportedError);
    });
  });

  group('nextRuleId', () {
    // Activity.ruleId is stored per activity and Season.ruleById looks a rule
    // up by id alone, so two seasons sharing rule_1 would resolve an activity
    // logged in one against a different rule in the other.

    test('every id is new', () {
      final ids = [for (var i = 0; i < 20; i++) repository.nextRuleId()];

      expect(ids.toSet(), hasLength(20));
    });

    test('two seasons built through the repository share no rule id', () async {
      final first = await repository.createDraft(
        name: 'Autumn 2026',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 11, 30),
        captainId: 'player_1',
        rules: SeasonTemplates.generalFitness.buildRules(repository.nextRuleId),
      );
      final second = await repository.createDraft(
        name: 'Winter 2027',
        startDate: DateTime(2027, 1, 1),
        endDate: DateTime(2027, 3, 31),
        captainId: 'player_1',
        rules: SeasonTemplates.generalFitness.buildRules(repository.nextRuleId),
      );

      final firstIds = first.rules.map((rule) => rule.id).toSet();
      final secondIds = second.rules.map((rule) => rule.id).toSet();

      expect(firstIds, hasLength(5));
      expect(firstIds.intersection(secondIds), isEmpty);
    });

    test('an activity id resolves to the rule of its own season', () async {
      final first = await repository.createDraft(
        name: 'Autumn 2026',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 11, 30),
        captainId: 'player_1',
        rules: SeasonTemplates.generalFitness.buildRules(repository.nextRuleId),
      );
      final second = await repository.createDraft(
        name: 'Winter 2027',
        startDate: DateTime(2027, 1, 1),
        endDate: DateTime(2027, 3, 31),
        captainId: 'player_1',
        rules: SeasonTemplates.generalFitness.buildRules(repository.nextRuleId),
      );

      final loggedAgainst = first.rules.first.id;

      expect(first.ruleById(loggedAgainst), isNotNull);
      expect(second.ruleById(loggedAgainst), isNull);
    });

    test('ids start past the rule ids the seeded seasons already hold', () {
      final seeded = Season(
        id: 'season_1',
        name: 'Autumn 2026',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 11, 30),
        captainId: 'player_1',
        status: SeasonStatus.active,
        rules: generalFitnessRules(),
      );
      final withSeed = InMemorySeasonRepository(seasons: [seeded]);
      addTearDown(withSeed.dispose);

      final seededIds = seeded.rules.map((rule) => rule.id).toSet();
      final fresh = [for (var i = 0; i < 5; i++) withSeed.nextRuleId()];

      expect(seededIds, contains('rule_5'));
      expect(seededIds.intersection(fresh.toSet()), isEmpty);
      expect(fresh.first, 'rule_6');
    });

    test('rule ids are counted apart from season ids', () async {
      final season = await createDraft(rules: const []);

      expect(season.id, startsWith('season_'));
      expect(repository.nextRuleId(), startsWith('rule_'));
    });
  });
}
