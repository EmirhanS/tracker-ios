/// Thrown when something tries to change a season that is already running.
///
/// The rules of an active season are locked so that points already earned keep
/// their meaning.
class SeasonLockedException implements Exception {
  const SeasonLockedException(this.seasonId);

  final String seasonId;

  @override
  String toString() => 'SeasonLockedException(seasonId: $seasonId)';
}

/// Thrown when a repository is asked for something that is not there.
class NotFoundException implements Exception {
  const NotFoundException(this.what, this.id);

  final String what;
  final String id;

  @override
  String toString() => 'NotFoundException($what: $id)';
}
