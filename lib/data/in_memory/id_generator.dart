/// Hands out ids for objects the app creates.
///
/// Counting up keeps the ids readable and makes tests repeatable. When Supabase
/// arrives the database gives out ids instead.
class IdGenerator {
  IdGenerator({int start = 0}) : _next = start;

  int _next;

  /// Returns the next id with [prefix], for example `season_3`.
  String next(String prefix) => '${prefix}_${++_next}';

  /// A function that always uses [prefix], for `SeasonTemplate.buildRules`.
  String Function() forPrefix(String prefix) => () => next(prefix);
}
