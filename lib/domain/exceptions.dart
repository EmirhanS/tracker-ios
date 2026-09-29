/// Thrown when something tries to move the dates of a running challenge.
///
/// The rules and the name of a running challenge are the owner's to change:
/// `Activity` freezes its own points at log time, so a later rule edit never
/// moves a score anybody has already earned. The dates are different. Moving
/// them would push activities that are already logged outside the challenge
/// they belong to, so they are fixed from the moment it starts.
class ChallengeLockedException implements Exception {
  const ChallengeLockedException(this.challengeId);

  final String challengeId;

  @override
  String toString() => 'ChallengeLockedException(challengeId: $challengeId)';
}

/// Thrown when a repository is asked for something that is not there.
class NotFoundException implements Exception {
  const NotFoundException(this.what, this.id);

  final String what;
  final String id;

  @override
  String toString() => 'NotFoundException($what: $id)';
}
