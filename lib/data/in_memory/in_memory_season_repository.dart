import '../../domain/exceptions.dart';
import '../../domain/models/scoring_rule.dart';
import '../../domain/models/season.dart';
import '../../domain/validation/season_validator.dart';
import '../repositories/season_repository.dart';
import 'id_generator.dart';
import 'in_memory_store.dart';

/// Seasons held in memory.
///
/// This class owns the two rules that protect points already earned:
/// an active season cannot be edited, and only one season runs at a time.
class InMemorySeasonRepository implements SeasonRepository {
  InMemorySeasonRepository({
    Iterable<Season> seasons = const [],
    IdGenerator? idGenerator,
  })  : _store = InMemoryStore<Season>(seasons),
        _ids = idGenerator ?? IdGenerator(start: seasons.length),
        _ruleIds = IdGenerator(start: _highestRuleNumber(seasons));

  final InMemoryStore<Season> _store;
  final IdGenerator _ids;

  /// Rule ids are counted separately from season ids so both stay readable.
  ///
  /// Seeded seasons already hold `rule_1..rule_N`, so the counter starts past
  /// the highest one rather than handing the same ids out a second time.
  final IdGenerator _ruleIds;

  static final RegExp _ruleIdPattern = RegExp(r'^rule_(\d+)$');

  static int _highestRuleNumber(Iterable<Season> seasons) {
    var highest = 0;
    for (final season in seasons) {
      for (final rule in season.rules) {
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
  Future<List<Season>> getAll() async => _store.items;

  @override
  Future<Season?> getById(String id) async =>
      _store.firstWhereOrNull((season) => season.id == id);

  @override
  Future<Season?> getActiveSeason() async =>
      _store.firstWhereOrNull((season) => season.isActive);

  @override
  Future<Season> createDraft({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required String captainId,
    List<ScoringRule> rules = const [],
  }) async {
    final season = Season(
      id: _ids.next('season'),
      name: name.trim(),
      startDate: startDate,
      endDate: endDate,
      captainId: captainId,
      status: SeasonStatus.draft,
      rules: List<ScoringRule>.of(rules),
    );
    _store.add(season);
    return season;
  }

  @override
  Future<Season> updateSeason(Season season) async {
    final index = _store.indexWhere((stored) => stored.id == season.id);
    if (index < 0) {
      throw NotFoundException('Season', season.id);
    }

    final stored = _store.items[index];
    if (stored.isLocked) {
      throw SeasonLockedException(season.id);
    }

    // The status is owned by startSeason, never by an edit.
    final updated = season.copyWith(status: stored.status);
    _store.replaceAt(index, updated);
    return updated;
  }

  @override
  Future<Season> startSeason(String seasonId) async {
    final index = _store.indexWhere((season) => season.id == seasonId);
    if (index < 0) {
      throw NotFoundException('Season', seasonId);
    }

    final season = _store.items[index];
    if (season.isActive) {
      return season;
    }

    final running = _store.firstWhereOrNull((other) => other.isActive);
    if (running != null) {
      throw StateError(
        'Season ${running.id} is already running. '
        'Only one season can be active at a time.',
      );
    }

    final problems = SeasonValidator.validateForStart(season);
    if (problems.isNotEmpty) {
      throw StateError('Season $seasonId cannot start: $problems');
    }

    final started = season.copyWith(status: SeasonStatus.active);
    _store.replaceAt(index, started);
    return started;
  }

  @override
  Stream<List<Season>> watchAll() => _store.watch();

  @override
  Stream<Season?> watchActiveSeason() => _store.watch().map((seasons) {
        for (final season in seasons) {
          if (season.isActive) return season;
        }
        return null;
      });

  void dispose() => _store.dispose();
}
